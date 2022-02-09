--!strict
-- ===========================================================================
-- Modules
-- ===========================================================================
local Packages = script:FindFirstAncestor('Packages')
local llama = require(Packages:FindFirstChild('llama'))
local t = require(Packages:FindFirstChild('t'))
local Signal = require(Packages:FindFirstChild('Signal'))

local Types = require(script.Parent.Parent.Shared.Types)
local Utils = require(script.Parent.Parent.Shared.Utils)

local copy = llama.Dictionary.copy

local pathCheck = t.strict(t.union(t.string, t.array(t.string)))

--[=[
	The player Data table.
	@prop Data { [any]: any }
	@within ClientReplion
	@readonly
]=]

--[=[
	The replion Tags.
	@prop Tags { string }
	@within ClientReplion
	@readonly
]=]

--[=[
	@class ClientReplion
	@client
]=]
local ClientReplion = {}
ClientReplion.__index = ClientReplion

function ClientReplion.new(data: Types.Table, tags: Types.StringArray)
	local self = setmetatable({
		Data = data,
		Tags = tags,
		_signals = {},
		_beforeDestroy = Signal.new(),
	}, ClientReplion)

	return self
end

local onUpdateCheck = t.strict(t.tuple(pathCheck, t.callback))
--[=[
	If the path is a root, then the callback will be: `(action: Enums, path: { string }, value: any, oldValue: any) -> ()`

	Example:
	```lua
	-- "Pets" is a root.	
	replion:OnUpdate('Pets', function(action: Enum, path: { string }, newValue: any, oldValue: any)
	end)

	-- "Stats.Coins" is not a root.
	replion:OnUpdate('Stats.Coins', function(action: Enum, newValue: any, oldValue: any)
	end)
	```

	The params for the callback change if the path is an Array.
	If is an Array, there are three options:
		- If a value is added: (action: Enum, index: number, value: any) -> ()
		- If a value is removed: (action: Enum, index: number, oldValue: any) -> ()
		- If the array is cleared: (action: Enum, oldValue: { any }}) -> ()

	@param callback (action: Enum, newValue: any, oldValue: any) -> ()
	@param path Path
]=]
function ClientReplion:OnUpdate(path: Types.Path, callback: Types.Callback): Types.Connection
	onUpdateCheck(path, callback)

	local signal: Types.Signal = Utils.getSignalFromPath(path, self._signals, true)
	return signal:Connect(callback)
end

local beforeDestroyCheck = t.strict(t.callback)
--[=[
	@param callback () -> ()
]=]
function ClientReplion:BeforeDestroy(callback: Types.Callback): Types.Connection
	beforeDestroyCheck(callback)

	local beforeDestroy: Types.Signal = self._beforeDestroy
	return beforeDestroy:Connect(callback)
end

--[=[
	Returns the value at the path.

	@param path Path
	@return any
]=]
function ClientReplion:Get(path: Types.Path)
	pathCheck(path)

	local dataPath: any, last: string = Utils.getFromPath(path, self.Data)
	return dataPath[last]
end

--[=[
	Returns a copy of the data in the given path.

	@param path Path
	@return any
]=]
function ClientReplion:GetCopy(path: Types.Path)
	return copy(self:Get(path))
end

function ClientReplion:Destroy()
	self._beforeDestroy:Fire()
	self._beforeDestroy:DisconnectAll()

	for _, signal in pairs(self._signals) do
		signal:DisconnectAll()
	end

	self._signals = nil :: any
	self._beforeDestroy = nil :: any

	setmetatable(self, nil)
end

export type ClientReplion = typeof(ClientReplion.new({}, { 'Foo' }))

return ClientReplion
