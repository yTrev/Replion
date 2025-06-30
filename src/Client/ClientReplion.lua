local Freeze = require(script.Parent.Parent.Parent.Freeze)

local Utils = require(script.Parent.Parent.Internal.Utils)
local Signal = require(script.Parent.Parent.Parent.Signal)
local _T = require(script.Parent.Parent.Internal.Types)

local Graph = require(script.Parent.Parent.Internal.Graph)

type Dictionary = _T.Dictionary

export type ClientReplion<D = any> = {
	Data: D,
	Tags: _T.Tags,
	Destroyed: boolean?,
	ReplicateTo: _T.ReplicateTo,

	_channel: string,
	_rootNode: Graph.Node?,
	_beforeDestroy: Signal.Signal<nil>,

	new: (serializedReplion: _T.SerializedReplion) -> ClientReplion<D>,
	BeforeDestroy: (self: ClientReplion<D>, callback: () -> ()) -> Signal.Connection,

	OnDataChange: (self: ClientReplion<D>, callback: (newData: D, path: _T.Path) -> ()) -> Signal.Connection,
	OnChange: <T>(
		self: ClientReplion<D>,
		path: _T.Path,
		callback: (newValue: T, oldValue: T) -> ()
	) -> Signal.Connection,

	OnArrayInsert: (self: ClientReplion<D>, path: _T.Path, callback: _T.ArrayCallback) -> Signal.Connection,
	OnArrayRemove: (self: ClientReplion<D>, path: _T.Path, callback: _T.ArrayCallback) -> Signal.Connection,

	_set: <T>(self: ClientReplion<D>, path: _T.Path, newValue: T) -> T,
	_update: (self: ClientReplion<D>, path: _T.Path | Dictionary, toUpdate: Dictionary?, isUnordered: boolean?) -> (),

	_increase: (self: ClientReplion<D>, path: _T.Path, amount: number) -> number,
	_decrease: (self: ClientReplion<D>, path: _T.Path, amount: number) -> number,

	_insert: <T>(self: ClientReplion<D>, path: _T.Path, value: T, index: number?) -> (),
	_remove: <T>(self: ClientReplion<D>, path: _T.Path, index: number?) -> T,
	_clear: (self: ClientReplion<D>, path: _T.Path) -> (),

	Find: <T>(self: ClientReplion<D>, path: _T.Path, value: T) -> (number?, T?),

	Get: <T>(self: ClientReplion<D>, path: _T.Path) -> T?,
	GetExpect: <T>(self: ClientReplion<D>, path: _T.Path, message: string?) -> T,

	Destroy: (self: ClientReplion<D>) -> (),

	__tostring: (self: ClientReplion<D>) -> string,
}

--[=[
	@type Path string | { string }
	@within ClientReplion
]=]

--[=[
	@prop Destroyed boolean?
	@readonly
	@within ClientReplion
]=]

--[=[
	@prop Data { [any]: any }
	@readonly
	@within ClientReplion
]=]

--[=[
	@prop Tags { string }?
	@readonly
	@within ClientReplion
]=]

--[=[
	@prop ReplicateTo ReplicateTo
	@within ClientReplion
]=]

--[=[
	@class ClientReplion
	
	@client
]=]
local ClientReplionMeta = {}
ClientReplionMeta.__index = ClientReplionMeta

local ClientReplion: ClientReplion = ClientReplionMeta :: any

function ClientReplion.new(serializedReplion)
	local self: ClientReplion = setmetatable({
		Data = serializedReplion[3],
		Tags = serializedReplion[5],
		ReplicateTo = serializedReplion[4],

		_channel = serializedReplion[2],

		_beforeDestroy = Signal.new(),
		_rootNode = Graph.createRootNode(),
	}, ClientReplion) :: any

	return self
end

function ClientReplion:__tostring()
	return `Replion<{self._channel}>`
end

--[=[
	@param callback (replion: ClientReplion) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when the :Destroy() method is called.
]=]
function ClientReplion:BeforeDestroy(callback)
	return self._beforeDestroy:Connect(callback)
end

--[=[
	@param callback (newData: any, path: { string }) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a value is changed in the data. 
]=]
function ClientReplion:OnDataChange(callback)
	return Graph.connect(self._rootNode, 'onDataChange', '__root', callback)
end

--[=[
	```lua
	replion:OnChange('Coins', function(newValue: any, oldValue: any)
		print(newValue, oldValue)
	end)
	```

	@param path Path
	@param callback (newValue: any, oldValue: any) -> ()

	@return RBXScriptConnection

	This function is called when the value of the path changes.
]=]
function ClientReplion:OnChange<T>(path, callback)
	return Graph.connect(self._rootNode, 'onChange', path, callback)
end

--[=[
	@param path Path
	@param callback (index: number, value: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a value is inserted in the array at the given path.
]=]
function ClientReplion:OnArrayInsert(path, callback)
	return Graph.connect(self._rootNode, 'onArrayInsert', path, callback)
end

--[=[
	@param path Path
	@param callback (index: number, value: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a value is removed in the array at the given path.
]=]
function ClientReplion:OnArrayRemove(path, callback)
	return Graph.connect(self._rootNode, 'onArrayRemove', path, callback)
end

function ClientReplion:_set<T>(path, newValue: T): T
	local pathTable = Utils.getPathTable(path)

	local currentValue: T? = Freeze.Dictionary.getIn(self.Data, pathTable)
	if currentValue == newValue then
		return newValue
	end

	local newData = Freeze.Dictionary.setIn(self.Data, pathTable, newValue)
	local oldData = self.Data

	self.Data = newData

	Graph.fireEvent(self._rootNode, 'onDataChange', '__root', newData, pathTable)
	Graph.fireChange(self._rootNode, pathTable, newData, oldData)

	return newValue
end

function ClientReplion:_update(path, toUpdate, isUnordered)
	local values = Freeze.Dictionary.map(toUpdate or path :: Dictionary, function(value, key)
		return if value == Utils.SerializedNone then Freeze.None else value, if isUnordered then tonumber(key) else key
	end)

	local pathTable = Utils.getPathTable(path)

	local oldData = self.Data
	local newData = if toUpdate == nil
		then Freeze.Dictionary.merge(self.Data, values)
		else Freeze.Dictionary.mergeIn(self.Data, pathTable, values)

	self.Data = newData

	Graph.fireEvent(self._rootNode, 'onDataChange', '__root', newData, pathTable)
	Graph.fireChange(self._rootNode, pathTable, newData, oldData)
end

function ClientReplion:_increase(path, amount)
	local currentValue: number = self:GetExpect(path)

	return self:_set(path, currentValue + amount)
end

function ClientReplion:_decrease(path, amount)
	return self:_increase(path, -amount)
end

function ClientReplion:_insert<T>(path, value: T, index)
	local pathTable = Utils.getPathTable(path)

	local array =
		assert(Freeze.Dictionary.getIn(self.Data, pathTable), `"{Utils.getPathString(path)}" is not a valid path!`)
	local targetIndex: number = if index then index else #array + 1

	local newArray = Freeze.List.insert(array, targetIndex, value)

	local oldData = self.Data
	local newData = Freeze.Dictionary.setIn(self.Data, pathTable, newArray)

	self.Data = newData

	Graph.fireEvent(self._rootNode, 'onDataChange', '__root', newData, pathTable)
	Graph.fireEvent(self._rootNode, 'onArrayInsert', pathTable, targetIndex, value)
	Graph.fireChange(self._rootNode, pathTable, newData, oldData)
end

function ClientReplion:_remove<T>(path, index)
	local pathTable = Utils.getPathTable(path)

	local array = self:GetExpect(path, `"{Utils.getPathString(path)}" is not a valid path!`)
	local targetIndex: number = if index then index else #array
	local value = array[targetIndex]

	local newArray = Freeze.List.remove(array, targetIndex)

	local oldData = self.Data
	local newData = Freeze.Dictionary.setIn(self.Data, pathTable, newArray)

	self.Data = newData

	Graph.fireEvent(self._rootNode, 'onDataChange', '__root', newData, pathTable)
	Graph.fireEvent(self._rootNode, 'onArrayRemove', path, targetIndex, value)
	Graph.fireChange(self._rootNode, pathTable, newData, oldData)

	return value
end

function ClientReplion:_clear(path)
	local pathTable = Utils.getPathTable(path)

	local oldData = self.Data
	local newData = Freeze.Dictionary.setIn(self.Data, pathTable, {})

	self.Data = newData

	Graph.fireEvent(self._rootNode, 'onDataChange', '__root', newData, pathTable)
	Graph.fireChange(self._rootNode, pathTable, newData, oldData)
end

--[=[
	```lua
	local index: number?, item: string? = replion:Find('Items', 'Bow')
	```

	@param path Path
	@param value T

	:::note Arrays only
	This only works on Arrays.

	Try to find the value in the array at the given path, and returns the index and value.
]=]
function ClientReplion:Find<T>(path, value: T): (number?, T?)
	local array: { T }? = self:Get(path)
	if not array then
		return
	end

	local index: number? = table.find(array, value)
	if not index then
		return
	end

	return index, value
end

--[=[
	```lua
	local coins: number? = newReplion:Get('Coins')
	```

	@param path path

	Returns the value at the given path. If no path is given, returns the entire data table.
	If you are expecting a value to exist, use `Replion:GetExpect` instead.
]=]
function ClientReplion:Get<T>(path): T?
	return Freeze.Dictionary.getIn(self.Data, Utils.getPathTable(path))
end

--[=[
	```lua
	local coins: number = Replion:GetExpect('Coins')
	local gems: number = Replion:GetExpect('Gems', 'Gems does not exist!')
	```

	@param path Path
	@param message string?

	@error "Invalid path" -- This error is thrown when the path does not have a value.

	Same as `Replion:Get`, but throws an error if the path does not have a value.
	You can set a custom error message by passing it as the second argument.
]=]
function ClientReplion:GetExpect<T>(path, message): T
	assert(path, 'Path is required!')

	message = if message then message else `"{Utils.getPathString(path)}" is not a valid path!`

	local value: T? = self:Get(path)
	if value == nil then
		error(message)
	end

	return value
end

function ClientReplion:Destroy()
	if self.Destroyed then
		return
	end

	self._beforeDestroy:Fire()
	self._beforeDestroy:DisconnectAll()

	Graph.destroyRootNode(self._rootNode)
	self._rootNode = nil

	self.Destroyed = true
end

return ClientReplion
