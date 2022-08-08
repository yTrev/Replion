--!strict
local Utils = require(script.Parent.Parent.Internal.Utils)
local Signal = require(script.Parent.Parent.Parent.Signal)
local _T = require(script.Parent.Parent.Internal.Types)

local Signals = require(script.Parent.Parent.Internal.Signals)

type ChangeCallback = (newValue: any, oldValue: any) -> ()
type ArrayCallback = (index: number, value: any) -> ()
type ExtensionCallback = _T.ExtensionCallback<ClientReplion>
type Dictionary = _T.Dictionary
type Path = _T.Path

type ClientReplionProps = {
	Data: Dictionary,
	Tags: _T.Tags,
	Extensions: { [string]: ExtensionCallback }?,

	_channel: string,
	_signals: typeof(Signals.new()),
	_beforeDestroy: _T.Signal,
}

local merge = Utils.merge

--[=[
	@type Path string | { string }
	@within ClientReplion
]=]

--[=[
	@type ChangeCallback (newValue: any, oldValue: any) -> ()
	@within ClientReplion
]=]

--[=[
	@type ExtensionCallback (replion: ClientReplion, ...any) -> ()
	@within ClientReplion
]=]

--[=[
	@class ClientReplion
	
	@client
]=]
local ClientReplion = {}
ClientReplion.__index = ClientReplion

function ClientReplion.new(serializedReplion: _T.SerializedReplion): ClientReplion
	local extensions
	if serializedReplion.Extensions then
		extensions = require(serializedReplion.Extensions) :: any
	end

	local self: ClientReplion = setmetatable({
		Data = serializedReplion.Data,
		Tags = serializedReplion.Tags,
		Extensions = extensions,

		_channel = serializedReplion.Channel,

		_beforeDestroy = Signal.new(),
		_signals = Signals.new(),
	}, ClientReplion)

	return self
end

function ClientReplion.__tostring(self: ClientReplion)
	return 'Replion<' .. self._channel .. '>'
end

--[=[
	@return RBXScriptConnection

	Connects to a signal that is fired when the :Destroy() method is called.
]=]
function ClientReplion.BeforeDestroy(self: ClientReplion, callback: (replion: ClientReplion) -> ()): _T.Connection
	return self._beforeDestroy:Connect(callback)
end

--[=[
	@return RBXScriptConnection

	This event is fired when a Extension is executed. The callback will be called with the return values of the Extension.
]=]
function ClientReplion.OnExecute(self: ClientReplion, name: string, callback: ExtensionCallback): _T.Connection
	assert(self.Extensions, '[Replion] - No Extensions found!')

	return self._signals:Get('onExecute', name):Connect(callback)
end
--[=[
	```lua
	replion:OnChange('Coins', function(newValue: any, oldValue: any)
		print(newValue, oldValue)
	end)
	```

	@param path Path
	@param callback ChangeCallback

	@return RBXScriptConnection

	This function is called when the value of the path changes.
]=]
function ClientReplion.OnChange(self: ClientReplion, path: Path, callback: ChangeCallback): _T.Connection
	return self._signals:Get('onChange', path):Connect(callback)
end

type DescendantCallback = (path: { string }, newDescendantValue: any, oldDescendantValue: any) -> ()
--[=[
	```lua
	-- On the server
	replion:Set({'Areas', 'Ice'}, true)
	```

	```lua
	replion:OnDescendantChange('Areas', function(path: { string }, newValue: any, oldValue: any)
		print(path, newValue, oldValue)
	end)
	```

	@param path Path
	@param callback (path: { string }, newDescendantValue: any, oldDescendantValue: any) -> ()

	@return RBXScriptConnection

	This event will be fired when any descendant of the path is changed.
]=]
function ClientReplion.OnDescendantChange(self: ClientReplion, path: Path, callback: DescendantCallback): _T.Connection
	return self._signals:Get('onDescendantChange', path):Connect(callback)
end

--[=[
	@param callback (index: number, value: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a value is inserted in the array at the given path.
]=]
function ClientReplion.OnArrayInsert(self: ClientReplion, path: Path, callback: _T.ArrayCallback): _T.Connection
	return self._signals:Get('onArrayInsert', path):Connect(callback)
end

--[=[
	@param callback (index: number, value: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a value is removed in the array at the given path.
]=]
function ClientReplion.OnArrayRemove(self: ClientReplion, path: Path, callback: _T.ArrayCallback): _T.Connection
	return self._signals:Get('onArrayRemove', path):Connect(callback)
end

--[=[
	```lua
	local coins: number = newReplion:Get('Coins')
	local data = newReplion:Get() --> Returns the entire data
	```

	Returns the value at the given path. If no path is given, returns the entire data table.
]=]
function ClientReplion.Get(self: ClientReplion, path: Path?): any
	if path then
		local data: any, last = Utils.getFromPath(path :: Path, self.Data)

		return data[last]
	else
		return self.Data
	end
end

--[=[
	@private
]=]
function ClientReplion.Set<T>(self: ClientReplion, path: Path, newValue: T): T
	local pathTable = Utils.getPathTable(path)
	local currentValue, key = Utils.getFromPath(pathTable, self.Data)

	local oldParentValue = if #pathTable > 1 then table.clone(currentValue) else nil

	local oldValue = currentValue[key]
	currentValue[key] = newValue

	if oldParentValue then
		self._signals:FireParent('onChange', pathTable, currentValue, oldParentValue)
	end

	self._signals:Fire('onChange', path, newValue, oldValue)

	return newValue
end

--[=[
	@private
]=]
function ClientReplion.Update(self: ClientReplion, path: Path | Dictionary, toUpdate: Dictionary?): Dictionary?
	local newValue, oldValue

	if toUpdate == nil then
		oldValue = self.Data

		local newData: Dictionary = merge(self.Data, path :: Dictionary)
		self.Data = newData

		newValue = newData

		for index, value in path :: Dictionary do
			self._signals:Fire('onChange', index, value, oldValue[index])
		end
	else
		local pathTable = Utils.getPathTable(path)
		local currentValue, key = Utils.getFromPath(pathTable, self.Data)

		local oldParentValue = if #pathTable > 1 then table.clone(currentValue) else nil
		oldValue = currentValue[key]

		if currentValue[key] ~= nil then
			currentValue[key] = merge(currentValue[key], toUpdate :: Dictionary)
		else
			currentValue[key] = toUpdate :: Dictionary
		end

		if oldParentValue then
			self._signals:FireParent('onChange', pathTable, currentValue, oldParentValue)
		end

		for index, value in toUpdate :: Dictionary do
			self._signals:Fire('onChange', index, value, oldValue[index])
		end

		newValue = currentValue[key]
	end

	self._signals:Fire('onChange', path, newValue, oldValue)

	return newValue
end

--[=[
	@private
]=]
function ClientReplion.Increase(self: ClientReplion, path: Path, amount: number): number
	local currentValue: number = self:Get(path)

	return self:Set(path, currentValue + amount)
end

--[=[
	@private
]=]
function ClientReplion.Decrease(self: ClientReplion, path: Path, amount: number): number
	return self:Increase(path, -amount)
end

--[=[
	@private
]=]
function ClientReplion.Insert<T>(self: ClientReplion, path: Path, value: T, index: number?): (number, T)
	local data, last = Utils.getFromPath(path, self.Data)

	local oldArray = data[last]
	local newArray = table.clone(oldArray)

	local targetIndex: number = if index then index else #newArray + 1

	table.insert(newArray, targetIndex, value)

	data[last] = newArray

	self._signals:Fire('onArrayInsert', path, targetIndex, value)
	self._signals:Fire('onChange', path, newArray, oldArray)

	return targetIndex, value
end

--[=[
	@private
]=]
function ClientReplion.Remove(self: ClientReplion, path: Path, index: number?): (any)
	local data, last = Utils.getFromPath(path, self.Data)

	local oldArray = data[last]
	local newArray = table.clone(oldArray)

	index = if index then index else #newArray

	local value = table.remove(newArray, index)

	data[last] = newArray

	self._signals:Fire('onArrayRemove', path, index, value)
	self._signals:Fire('onChange', path, newArray, oldArray)

	return value
end

--[=[
	@private
]=]
function ClientReplion.Clear(self: ClientReplion, path: Path)
	local data, last = Utils.getFromPath(path, self.Data)

	local oldArray = data[last]

	-- We could use the `table.clear`, but I don't see any reason to do that.
	local newArray = {}
	data[last] = newArray

	self._signals:Fire('onChange', path, newArray, oldArray)
end

--[=[
	@private
]=]
function ClientReplion.Execute(self: ClientReplion, name: string, ...: any)
	local extensions = assert(self.Extensions, '[Replion] - Is your Extension module in a shared instance?')
	local extension = extensions[name]

	self._signals:Pause()

	local values = table.pack(extension(self, ...))

	self._signals:Resume()

	local onExecuteSignals = self._signals:GetSignals('onExecute')
	if onExecuteSignals then
		local signal = onExecuteSignals[name]

		if signal then
			signal:Fire(table.unpack(values))
		end
	end
end

function ClientReplion.Destroy(self: ClientReplion)
	self._beforeDestroy:Fire()

	self._signals:Destroy()
end

export type ClientReplion = typeof(setmetatable({} :: ClientReplionProps, ClientReplion))

return ClientReplion
