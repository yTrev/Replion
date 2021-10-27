--!strict
-- ===========================================================================
-- Roblox services
-- ===========================================================================
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- ===========================================================================
-- Modules
-- ===========================================================================
local Utils = require(script.Parent.Shared.Utils)
local Signal = require(script.Parent.Shared.Signal)
local Enums = require(script.Parent.Shared.Enums)

-- ===========================================================================
-- Constants
-- ===========================================================================
local INVALID_CALLBACK: string = "%q isn't a valid callback!"
local WRITE_LIB_NOT_FOUND: string = 'No write library in %s'
local INVALID_WRITE_CALLBACK: string = '%q is not a valid write callback!'
local NO_CHANGE_DETECTED: string = 'No change on %q update!'
local INVALID_NUMBER: string = "%q isn't a number!"

-- ===========================================================================
-- Types
-- ===========================================================================
type Callback = (...any) -> (...any)
type Signal = Signal.Signal
type StringArray = Utils.StringArray
type StringPath = StringArray | string
type WriteLib = { [string]: Callback }

--[=[
	@interface Configuration
	@within ReplionServer
	.Player Player
	.Data any
	.WriteLib {[string]: (Replion, ...any) -> (...any)} 
]=]
type Configuration = {
	Player: Player,
	Data: any,
	WriteLib: WriteLib?,
}

-- ===========================================================================
-- Variables
-- ===========================================================================
local replions: { [Player]: Replion } = {}

local ReplionFolder: Folder = Instance.new('Folder')
ReplionFolder.Name = 'ReplionEvents'

local OnUpdateEvent: RemoteEvent = Instance.new('RemoteEvent')
OnUpdateEvent.Name = 'OnUpdate'
OnUpdateEvent.Parent = ReplionFolder

local RequestData: RemoteEvent = Instance.new('RemoteEvent')
RequestData.Name = 'RequestData'
RequestData.Parent = ReplionFolder

ReplionFolder.Parent = ReplicatedStorage

--[=[
	@interface Action
	@tag Enum
	@within ReplionServer
	.Added "Added" -- A new value was added;
	.Changed "Changed" -- A value was changed;
	.Removed "Removed" -- A value was removed.
]=]

--[=[
	@prop Action Enums
	@tag Enums
	@within ReplionServer
	@readonly
]=]

--[=[
	The player Data table.
	@prop Data any
	@within ReplionServer
	@readonly
]=]

--[=[
	@prop Player Player
	@within ReplionServer
	@readonly
]=]

--[=[
	@prop WriteLib { [string]: (Replion, ...any) -> (...any) }?
	@within ReplionServer
	@readonly
]=]

--[=[
	@class ReplionServer
	@server

	```lua
	local Replion = require(path.to.Replion)

	local newReplion = Replion.new({
		Player = player,
		Data = {
			Coins = 10,
		},
	})

	newReplion:Add('Coins', 20)
	print(newReplion:Get('Coins')) --> 30
	```
]=]

local ReplionServer = {}
ReplionServer.__index = ReplionServer

ReplionServer.Action = Enums.Action
ReplionServer.TESTING = nil

--[=[
	Creates a new `Replion` to the desired player.
	@error Invalid player -- Occur when the player argument isn't a Player instance.
	@error Invalid data -- Occur when the data argument isn't a table.
	@param configuration Configuration
	@return ReplionServer
]=]
function ReplionServer.new(configuration: Configuration): Replion
	local player: Player = configuration.Player
	local initialData = configuration.Data

	if replions[player] then
		return replions[player]
	end

	assert(
		typeof(player) == 'Instance' and player:IsA('Player') or ReplionServer.TESTING and typeof(player) == 'table',
		'Invalid player!'
	)

	assert(typeof(initialData) == 'table', string.format("%q isn't a valid data!", tostring(initialData)))

	local self = setmetatable({
		Data = initialData,
		Player = player,
		WriteLib = configuration.WriteLib,
		_signals = {},
	}, ReplionServer)

	replions[player] = self

	return self
end

function ReplionServer:__tostring(): string
	return string.format('Replion<%s>', self.Player.Name)
end

function ReplionServer:_fireUpdate(action: string?, path: { string }, newValue: any)
	assert(action, string.format(NO_CHANGE_DETECTED, Utils.convertTablePathToString(path)))

	if not ReplionServer.TESTING then
		OnUpdateEvent:FireClient(self.Player, action, path, newValue)
	end

	local signal: Signal? = Utils.getSignal(self._signals, path)
	if signal then
		signal:Fire(action, newValue)
	end

	local rootSignal: Signal? = Utils.getSignal(self._signals, path[1])
	if rootSignal and rootSignal ~= signal then
		rootSignal:Fire(action, newValue)
	end
end

function ReplionServer:_getFromPath(path: StringArray): (any, string)
	local dataPath: any = self.Data

	for i: number = 1, #path - 1 do
		dataPath = dataPath[path[i]]
	end

	return dataPath, path[#path]
end

--[=[
	Listen to the changes of a value on the Data table.
	@error Invalid path -- Occur when the path isn't a string or an array of strings.
	@error Invalid callback -- Occur when the callback isn't a function.
	@param path string | { string }
	@param callback (...any) -> ()
	@return Connection
]=]
function ReplionServer:OnUpdate(path: StringPath, callback: Callback): Signal.Connection
	local pathInString: string

	if typeof(path) == 'table' then
		pathInString = Utils.convertTablePathToString(path :: StringArray)
	else
		pathInString = path :: string
	end

	assert(typeof(pathInString) == 'string', string.format("%q isn't a valid path!", tostring(pathInString)))
	assert(typeof(callback) == 'function', string.format(INVALID_CALLBACK, tostring(callback)))

	local signal: Signal = Utils.getSignal(self._signals, pathInString, true)
	return signal:Connect(callback)
end

--[=[
	@error WriteLib not found -- Occur when a WriteLib doesn't exist.
	@param path string | { string }
	@param ... any
	@return ...any
]=]
function ReplionServer:Write(name: string, ...: any): (...any)
	local writeLib = assert(self.WriteLib, string.format(WRITE_LIB_NOT_FOUND, tostring(self)))

	-- Maybe add pcall to prevent errors? But I don't think it's necessary.
	local callbackFunction: Callback = assert(writeLib[name], string.format(INVALID_WRITE_CALLBACK, name))
	return callbackFunction(self, ...)
end

--[=[
	@param path string | { string }
	@param newValue any
	@return any
]=]
function ReplionServer:Set(path: StringPath, newValue: any): any
	local pathInTable: StringArray

	if typeof(path) == 'string' then
		pathInTable = Utils.convertPathToTable(path :: string)
	else
		pathInTable = path :: StringArray
	end

	local dataPath: any, last: string = self:_getFromPath(pathInTable)

	local lastValue: any = dataPath[last]
	local action: string?

	if lastValue == nil then
		action = Enums.Action.Added
	elseif newValue ~= lastValue then
		action = newValue == nil and Enums.Action.Removed or Enums.Action.Changed
	end

	dataPath[last] = newValue

	self:_fireUpdate(action, pathInTable, newValue)

	return dataPath[last]
end

--[=[
	@param path string | { string }
	@param valuesToUpdate any
	@return any
]=]
function ReplionServer:Update(path: StringPath, valuesToUpdate: any): any
	local pathInTable: StringArray

	if typeof(path) == 'string' then
		pathInTable = Utils.convertPathToTable(path :: string)
	else
		pathInTable = path :: StringArray
	end

	local dataPath: any, last: string = self:_getFromPath(pathInTable)
	local lastValue: any = dataPath[last]
	local action: string?

	if lastValue == nil then
		dataPath[last] = valuesToUpdate
		action = Enums.Action.Added
	else
		dataPath[last] = Utils.assign(lastValue, valuesToUpdate)
		action = Enums.Action.Changed
	end

	self:_fireUpdate(action, pathInTable, valuesToUpdate)

	return dataPath[last]
end

--[=[
	Returns the value at the given path.
	@param path: { string } | string
	@return any
]=]
function ReplionServer:Get(path: StringPath): any
	local pathInTable: StringArray

	if typeof(path) == 'string' then
		pathInTable = Utils.convertPathToTable(path :: string)
	else
		pathInTable = path :: StringArray
	end

	local value: any = self.Data
	for _: number, name: string in ipairs(pathInTable) do
		value = value[name]
	end

	return value
end

--[=[
	@error Invalid number -- Occur when the number parameter isn't a number.
	@param path string | { string }
	@param number number
	@return number
]=]
function ReplionServer:Increase(path: StringPath, number: number): number
	number = assert(tonumber(number), string.format(INVALID_NUMBER, tostring(number)))

	local pathInTable: StringArray

	if typeof(path) == 'string' then
		pathInTable = Utils.convertPathToTable(path :: string)
	else
		pathInTable = path :: StringArray
	end

	local dataPath: any, last: string = self:_getFromPath(pathInTable)
	local lastValue: any = assert(tonumber(dataPath[last]), string.format(INVALID_NUMBER, tostring(dataPath[last])))

	local action: string? = Enums.Action.Changed
	local newValue: number = lastValue + number

	if newValue ~= lastValue then
		dataPath[last] = newValue
		action = Enums.Action.Changed
	end

	self:_fireUpdate(action, pathInTable, newValue)

	return newValue
end

--[=[
	@error Invalid number -- Occur when the number parameter isn't a number.
	@param path string | { string }
	@param number number
	@return number
]=]
function ReplionServer:Decrease(path: StringPath, number: number): number
	return self:Increase(path, -number)
end

--[=[
	@param player Player
	@return ReplionServer?
]=]
function ReplionServer:GetReplion(player: Player): Replion?
	return replions[player]
end

--[=[
	Destroys the Replion object.
]=]
function ReplionServer:Destroy()
	for _: string, signal: Signal in pairs(self._signals) do
		signal:Destroy()
	end

	replions[self.Player] = nil

	table.clear(self)
	setmetatable(self, nil)
end

RequestData.OnServerEvent:Connect(function(player: Player)
	local playerReplion: Replion? = replions[player]

	if playerReplion then
		RequestData:FireClient(player, playerReplion.Data)
	else
		RequestData:FireClient(player, nil)
	end
end)

export type Replion = typeof(ReplionServer.new({
	Player = Instance.new('Player'),
	Data = {},
}))

return ReplionServer
