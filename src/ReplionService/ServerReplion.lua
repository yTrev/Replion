--!strict
-- ===========================================================================
-- Modules
-- ===========================================================================
local Packages = script:FindFirstAncestor('Packages')
local t = require(Packages:FindFirstChild('t'))
local llama = require(Packages:FindFirstChild('llama'))
local Signal = require(Packages:FindFirstChild('Signal'))

local Types = require(script.Parent.Parent.Shared.Types)
local Utils = require(script.Parent.Parent.Shared.Utils)
local Enums = require(script.Parent.Parent.Shared.Enums)
local Network = require(script.Parent.Network)
local Containers = require(script.Parent.Containers)

-- ===========================================================================
-- Constants
-- ===========================================================================
local INVALID_NUMBER: string = "%q isn't a number!"
local INVALID_PATH: string = "%q isn't a valid path!"
local DESTROYED_ERROR: string = 'Attempted to use Replion:%s(...) in a destroyed replion!'

-- Used just to enable tests.
local fakePlayer = t.strictInterface({
	Name = t.string,
	UserId = t.number,
})

local pathCheck = t.strict(t.union(t.string, t.array(t.string)))
local configurationCheck = t.strict(t.strictInterface({
	Player = t.union(t.instanceIsA('Player', nil), fakePlayer),
	Name = t.string,
	Data = t.table,
	Extensions = t.optional(t.table),
	Tags = t.optional(t.array(t.string)),
}))

local merge = llama.Dictionary.merge

local function assertDestroyed(destroyed: boolean?)
	assert(destroyed ~= true, string.format(DESTROYED_ERROR, debug.info(2, 'n')))
end

--[=[
	@type Extensions { [string]: (Replion, ...any) -> (...any) }?
	@within ServerReplion
]=]

--[=[
	@type Path string | { string }
	@within ServerReplion
	A string or an array of strings.
]=]

--[=[
	@interface Configuration
	@within ServerReplion
	.Player Player
	.Name string
	.Data { [any]: any }
	.Extensions Extensions
	.Tags { string }?
]=]

--[=[
	The player Data table.
	@prop Data any
	@within ServerReplion
	@readonly
]=]

--[=[
	@prop Player Player
	@within ServerReplion
	@readonly
]=]

--[=[
	@prop Extensions Extensions
	@within ServerReplion
	@readonly
]=]

--[=[
	@class ServerReplion
	@server
]=]
local ServerReplion = {}
ServerReplion.__index = ServerReplion

ServerReplion.Enums = Enums

--[=[
	@param config Configuration
	@return ServerReplion

	Creates a new `ServerReplion` to the desired player.
]=]
function ServerReplion.new(config: Configuration)
	configurationCheck(config)

	local createdReplion = Containers.getFromContainer(config.Player, config.Name)
	assert(createdReplion == nil, string.format('%q already exists!', tostring(createdReplion)))

	local self = setmetatable({
		Name = config.Name,
		Player = config.Player,
		Data = config.Data,
		Extensions = config.Extensions,
		Tags = config.Tags,

		_signals = {},
		_beforeDestroy = Signal.new(),
	}, ServerReplion)

	-- Add the replion to the container
	return self
end

function ServerReplion:__tostring(): string
	return string.format('Replion<%s/%s>', self.Player.Name, self.Name)
end

-- TODO
-- In the future add a better support for extensions, to enable other functions
-- to be used inside the extensions without sending them to the client.
function ServerReplion:Execute(extension: string, ...: any): ...any
	assertDestroyed(self.Destroyed)

	local extensions = assert(self.Extensions, string.format('%s has no extensions', tostring(self)))
	local callback = assert(
		extensions[extension],
		string.format('%s has no extension named %q', tostring(self), extension)
	)

	return callback(self, ...)
end

ServerReplion.Write = ServerReplion.Execute

local onUpdateCheck = t.strict(t.tuple(pathCheck, t.callback))
--[=[
	@param path Path
	@return Connection
	
	Listen to the changes of a value on the Data table.

	```lua
	Replion:OnUpdate('Coins', function(action, newValue: number)
		print(newValue)
	end)
	```
]=]
function ServerReplion:OnUpdate(path: Types.Path, callback: Types.Callback): Types.Connection
	assertDestroyed(self.Destroyed)
	onUpdateCheck(path, callback)

	local signal: Types.Signal = Utils.getSignalFromPath(path, self._signals, true) :: Types.Signal
	return signal:Connect(callback)
end

local beforeDestroyCheck = t.strict(t.callback)
--[=[
	@since v0.3.0

	A callback that will be called before the Replion is destroyed.

	```lua
	Replion:BeforeDestroy(function()
		local coins = Replion:Get('Coins')
		print(coins)
	end)
	```
]=]
function ServerReplion:BeforeDestroy(callback: Types.Callback): Types.Connection
	assertDestroyed(self.Destroyed)
	beforeDestroyCheck(callback)

	local beforeDestroy: Types.Signal = self._beforeDestroy
	return beforeDestroy:Connect(callback)
end

--[=[
	@param path Path

	```lua
	Replion:Set('Coins', 20)
	Replion:Set({'Pets', petId}, true)
	```
]=]
function ServerReplion:Set(path: Types.Path, newValue: any): any
	assertDestroyed(self.Destroyed)
	pathCheck(path)

	local stringArray: Types.StringArray = Utils.getStringArrayFromPath(path)
	local dataPath: any, last: string = Utils.getFromPath(stringArray, self.Data)

	local currentValue: any = dataPath[last]

	local action: Types.Enum = Enums.Action.None

	if currentValue == nil then
		action = Enums.Action.Added
	elseif newValue ~= currentValue then
		action = if newValue == nil then Enums.Action.Removed else Enums.Action.Changed
	end

	dataPath[last] = newValue

	Utils.fireSignals(self._signals, stringArray, action, newValue)
	Network.FireUpdate(self, action, stringArray, newValue)

	return newValue
end

local updateCheck = t.strict(t.tuple(pathCheck, t.table))
--[=[
	@param path Path
	
	Update some values on the Data table.
	Can be used in Arrays and in Dictionaries.

	```lua
	local newReplion = Replion.new({
		Name = 'Data',
		Player = player,
		Data = {
			Stats = {
				Coins = 0,
				Level = 0,
			}
		},
	})

	print(Replion:Update('Stats', {
		Coins = 20,
		Level = 1,
	}))

	--[[ 
		Prints:
		{
			Coins = 20,
			Level = 1,
		}
	]]--
	```	
]=]
function ServerReplion:Update(path: Types.Path, values: Types.Table): any
	assertDestroyed(self.Destroyed)
	updateCheck(path, values)

	local stringArray: Types.StringArray = Utils.getStringArrayFromPath(path)
	local dataPath: any, last: string = Utils.getFromPath(stringArray, self.Data)

	local currentValue: any = dataPath[last]
	local action: Types.Enum = Enums.Action.None

	if currentValue == nil then
		dataPath[last] = values
		action = Enums.Action.Added
	else
		dataPath[last] = merge(currentValue, values)
		action = Enums.Action.Changed
	end

	Utils.fireSignals(self._signals, stringArray, action, values)
	Network.FireUpdate(self, action, stringArray, values)

	return dataPath[last]
end

local increaseCheck = t.strict(t.tuple(pathCheck, t.number))
--[=[
	@param path Path

	```lua
	local newCoins: number = Replion:Increase('Coins', 20)
	```
]=]
function ServerReplion:Increase(path: Types.Path, value: number): number
	assertDestroyed(self.Destroyed)

	local valueInNumber: number? = tonumber(value)

	increaseCheck(path, valueInNumber)

	local stringArray: Types.StringArray = Utils.getStringArrayFromPath(path)
	local dataPath: any, last: string = Utils.getFromPath(stringArray, self.Data)

	local currentValue: number = assert(
		tonumber(dataPath[last]),
		string.format(INVALID_NUMBER, tostring(dataPath[last]))
	) :: number

	local action: Types.Enum = Enums.Action.None
	local newValue: number = currentValue + valueInNumber :: number

	if newValue ~= currentValue then
		dataPath[last] = newValue
		action = Enums.Action.Changed
	end

	Utils.fireSignals(self._signals, stringArray, action, newValue)
	Network.FireUpdate(self, action, stringArray, newValue)

	return newValue
end

--[=[
	@param path Path

	```lua
	local newCoins: number = Replion:Decrease('Coins', 20)
	```
]=]
function ServerReplion:Decrease(path: Types.Path, value: number): number
	assertDestroyed(self.Destroyed)

	return self:Increase(path, -value)
end

--[=[
	@param path Path

	```lua
	local coins: number = Replion:Get('Coins')
	local level: number = Replion:Get('Stats.Level')
	```
]=]
function ServerReplion:Get(path: Types.Path): any
	assertDestroyed(self.Destroyed)
	pathCheck(path)

	local dataPath: any, last: string = Utils.getFromPath(path, self.Data)
	return dataPath[last]
end

--[=[
	@param path Path
	@since v0.3.0
	
	@error "Invalid path" -- This error is thrown when the path does not have a value.
	
	If the value is not found, an error will be thrown.

	```lua
	local coins: number = Replion:GetExpect('Coins')
	```
]=]
function ServerReplion:GetExpect(path: Types.Path, message: string?): any
	assertDestroyed(self.Destroyed)

	local value = assert(
		self:Get(path),
		if message then message else string.format(INVALID_PATH, Utils.getStringFromPath(path))
	)

	return value
end

--[=[	
	@param path Path
	@since v0.3.0
	
	Inserts a new value into the array.
	
	:::note Arrays only
	This only works on Arrays.
]=]
function ServerReplion:Insert(path: Types.Path, value: any, index: number?)
	assertDestroyed(self.Destroyed)
	pathCheck(path)

	local stringArray: Types.StringArray = Utils.getStringArrayFromPath(path)
	local dataPath: any, last: string = Utils.getFromPath(stringArray, self.Data)

	local array: any = assert(dataPath[last], 'Invalid array!')

	index = if index then index else #array + 1

	table.insert(array, index :: number, value)

	Utils.fireSignals(self._signals, stringArray, Enums.Action.Added, index, value)
	Network.FireUpdate(self, Enums.Action.Added, stringArray, index, value)
end

--[=[
	@param path Path
	@since v0.3.0
	
	Removes a value from the array.

	:::note Arrays only
	This only works on Arrays.
]=]
function ServerReplion:Remove(path: Types.Path, index: number?): any
	assertDestroyed(self.Destroyed)
	pathCheck(path)

	local stringArray: Types.StringArray = Utils.getStringArrayFromPath(path)
	local dataPath: any, last: string = Utils.getFromPath(stringArray, self.Data)

	local array: any = assert(dataPath[last], 'Invalid array!')

	index = if index then index else #array + 1

	local value = table.remove(array, index)

	Utils.fireSignals(self._signals, stringArray, Enums.Action.Removed, index, value)
	Network.FireUpdate(self, Enums.Action.Removed, Utils.getStringArrayFromPath(path), index)

	return value
end

--[=[
	@param path Path
	@since v0.3.0
	
	Finds a value in the array.

	:::note Arrays only
	This only works on Arrays.
]=]
function ServerReplion:Find(path: Types.Path, value: any): (any, number?)
	assertDestroyed(self.Destroyed)

	local array: Types.GenericArray = self:GetExpect(path)

	local index: number? = table.find(array, value)

	if index then
		return array[index], index
	else
		return nil
	end
end

--[=[
	@param path Path
	@since v0.3.0

	Finds a value in the array and removes it.

	:::note Arrays only
	This only works on Arrays.
]=]
function ServerReplion:FindRemove(path: Types.Path, value: any)
	assertDestroyed(self.Destroyed)

	local array: Types.GenericArray = self:GetExpect(path)
	local index: number? = table.find(array, value)
	if index then
		return self:Remove(path, index)
	end
end

--[=[
	@param path Path
	@since v0.3.0

	Clears the array.

	:::note Arrays only
	This only works on Arrays.
]=]
function ServerReplion:Clear(path: Types.Path)
	assertDestroyed(self.Destroyed)
	pathCheck(path)

	local stringArray: Types.StringArray = Utils.getStringArrayFromPath(path)
	local dataPath: any, last: string = Utils.getFromPath(stringArray, self.Data)

	local array: any = assert(dataPath[last], 'Invalid array!')
	table.clear(array)

	Utils.fireSignals(self._signals, stringArray, Enums.Action.Cleared)
	Network.FireUpdate(self, Enums.Action.Cleared, Utils.getStringArrayFromPath(path))
end

--[=[
	@since v0.3.0

	Returns if the ServerReplion is destroyed.
]=]
function ServerReplion:IsDestroyed(): boolean
	return self.Destroyed == true
end

--[=[
	Destroys the Replion object.
]=]
function ServerReplion:Destroy()
	assertDestroyed(self.Destroyed)

	self._beforeDestroy:Fire()
	self._beforeDestroy:DisconnectAll()

	for _, signal: Types.Signal in pairs(self._signals) do
		signal:DisconnectAll()
	end

	self._beforeDestroy = nil :: any
	self._signals = nil :: any

	Network.FireEvent(Enums.Event.Deleted, self.Player, self.Name)

	-- Please don't keep another reference to this object.
	Containers.removeFromContainer(self)

	self.Destroyed = true
end

export type ServerReplion = typeof(ServerReplion.new({
	Player = Instance.new('Player'),
	Name = '',
	Data = {},
}))

export type Configuration = {
	Name: string, --> Name of the data, used to identify it.
	Player: Player, --> Maybe add multiple Players?,
	Data: { [any]: any }, --> Data to be replicated, need to be a table.
	Extensions: { [string]: (ServerReplion, ...any) -> () }?,
	Tags: { string }?,
}

return ServerReplion
