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
	@prop Data { [string]: any }
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
	@param path Path
]=]
function ClientReplion:OnUpdate(path: Types.Path, callback: Types.Callback)
	onUpdateCheck(path, callback)

	local signal: any = Utils.getSignalFromPath(path, self._signals, true)
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
