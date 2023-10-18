--!strict
local Network = require(script.Parent.Parent.Internal.Network)
local Signal = require(script.Parent.Parent.Parent.Signal)

local Utils = require(script.Parent.Parent.Internal.Utils)
local Signals = require(script.Parent.Parent.Internal.Signals)

local _T = require(script.Parent.Parent.Internal.Types)

local Freeze = require(script.Parent.Parent.Parent.Freeze)

type Path = _T.Path
type BeforeDestroyCallback = _T.BeforeDestroy<ServerReplion>
type ArrayCallback = _T.ArrayCallback
type Dictionary = _T.Dictionary
type ReplicateTo = Player | { Player } | 'All'

export type ServerReplion<D = any> = {
	Channel: string,
	Data: D,
	Destroyed: boolean?,
	Tags: { string },
	ReplicateTo: ReplicateTo,

	_beforeDestroy: Signal.Signal<ServerReplion<D>>,
	_signals: Signals.Signals,

	_id: number,
	_packedId: string,

	new: <T>(config: ReplionConfig<T>) -> ServerReplion<D>,
	BeforeDestroy: (self: ServerReplion<D>, callback: (replion: ServerReplion<D>) -> ()) -> Signal.Connection,

	OnDataChange: (self: ServerReplion<D>, callback: (newData: D, path: _T.Path) -> ()) -> Signal.Connection,
	OnChange: <V>(
		self: ServerReplion<D>,
		path: _T.Path,
		callback: (newValue: V, oldValue: V) -> ()
	) -> Signal.Connection,

	OnArrayInsert: (self: ServerReplion<D>, path: _T.Path, callback: ArrayCallback) -> Signal.Connection,
	OnArrayRemove: (self: ServerReplion<D>, path: _T.Path, callback: ArrayCallback) -> Signal.Connection,
	OnDescendantChange: (
		self: ServerReplion<D>,
		path: _T.Path,
		callback: (path: _T.Path, newDescendantValue: any, oldDescendantValue: any) -> ()
	) -> Signal.Connection,

	SetReplicateTo: (self: ServerReplion<D>, replicateTo: ReplicateTo) -> (),

	Set: <T>(self: ServerReplion<D>, path: _T.Path, newValue: T) -> T,
	Update: (self: ServerReplion<D>, path: _T.Path, toUpdate: Dictionary?) -> (),

	Increase: (self: ServerReplion<D>, path: _T.Path, amount: number) -> number,
	Decrease: (self: ServerReplion<D>, path: _T.Path, amount: number) -> number,

	Insert: <T>(self: ServerReplion<D>, path: _T.Path, value: T, index: number?) -> (),
	Remove: <T>(self: ServerReplion<D>, path: _T.Path, index: number?) -> T,
	Clear: (self: ServerReplion<D>, path: _T.Path) -> (),
	Find: <T>(self: ServerReplion<D>, path: _T.Path, value: T) -> (number?, T?),

	Get: <T>(self: ServerReplion<D>, path: _T.Path) -> T?,
	GetExpect: <T>(self: ServerReplion<D>, path: _T.Path, message: string?) -> T,

	Destroy: (self: ServerReplion<D>) -> (),

	_serialize: (self: ServerReplion<D>) -> _T.SerializedReplion,
	__tostring: (self: ServerReplion<D>) -> string,
}

export type ReplionConfig<D = any> = {
	Channel: string,

	Data: D,
	ReplicateTo: ReplicateTo,

	Tags: { string }?,
}

-- Unsigned short
local ID_LIMIT: number = 1114111

local id: number = 0
local availableIds: { number } = {}

--[=[
	@type Path string | { any }

	@within ServerReplion
]=]

--[=[
	@type ReplicateTo Player | { Player } | 'All'

	@within ServerReplion
]=]

--[=[
	@type SerializedReplion { any }

	@within ServerReplion
]=]

--[=[
	@prop Channel string
	@readonly

	@within ServerReplion
]=]

--[=[
	@prop Data { [any]: any }
	@within ServerReplion
]=]

--[=[
	@prop Destroyed boolean?
	@readonly

	@within ServerReplion
]=]

--[=[
	@prop Tags { string }
	@readonly

	@within ServerReplion
]=]

--[=[
	@prop ReplicateTo ReplicateTo
	@readonly

	@within ServerReplion
]=]

--[=[
	@class ServerReplion	

	@server
]=]
local ServerReplionMeta = {}
ServerReplionMeta.__index = ServerReplionMeta

local ServerReplion: ServerReplion = ServerReplionMeta :: any

function ServerReplion.new<D>(config: ReplionConfig<D>): ServerReplion<D>
	assert(type(config.Channel) == 'string', `"Channel" expected string, got {type(config.Channel)}`)
	assert(config.ReplicateTo, 'ReplicateTo is required!')

	local replicateTo = config.ReplicateTo
	local selectedId

	local availableId = table.remove(availableIds)
	if availableId then
		selectedId = availableId
	else
		id += 1
		selectedId = id
	end

	assert(selectedId <= ID_LIMIT, `ID limit reached! You already have {ID_LIMIT} ServerReplions!`)

	local self: ServerReplion<D> = setmetatable({
		Data = config.Data,
		Channel = config.Channel,
		Tags = if config.Tags then config.Tags else {},
		ReplicateTo = replicateTo,

		_id = selectedId,
		_packedId = utf8.char(selectedId),
		_beforeDestroy = Signal.new(),
		_signals = Signals.new(),
	}, ServerReplion) :: any

	Network.sendTo(replicateTo, 'Added', self:_serialize())

	return self
end

function ServerReplion:__tostring()
	local channel = self.Channel
	local replicateTo = self.ReplicateTo

	local replicatingTo
	if type(replicateTo) == 'table' then
		local names = {}

		for i, player in replicateTo do
			names[i] = player.Name
		end

		replicatingTo = table.concat(names, ', ')
	elseif typeof(replicateTo) == 'Instance' then
		replicatingTo = replicateTo.Name
	else
		replicatingTo = replicateTo
	end

	return `Replion<{channel}:{replicatingTo}>`
end

--[=[
	@return SerializedReplion
	@private

	Serializes the data to be sent to the client.
]=]
function ServerReplion:_serialize(): _T.SerializedReplion
	-- The initial data that is sent to the client, probably will be the most expensive part of the replication.
	-- But it's only done once, so it's not that bad. We can optimize this later if needed, but for now it's fine.

	return { self._packedId, self.Channel, self.Data, self.ReplicateTo, self.Tags }
end

--[=[
	@param callback (replion: ServerReplion) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when the :Destroy() method is called.
]=]
function ServerReplion:BeforeDestroy(callback)
	return self._beforeDestroy:Connect(callback)
end

--[=[
	@param callback (newData: any, path: Path) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a value is changed in the data. 
]=]
function ServerReplion:OnDataChange(callback)
	return self._signals:Connect('onDataChange', '__root', callback)
end

--[=[
	@param path Path
	@param callback (newValue: any, oldValue: any) -> ()
	
	@return RBXScriptConnection

	Connects to a signal that is fired when the value at the given path is changed.
]=]
function ServerReplion:OnChange<V>(path, callback)
	return self._signals:Connect('onChange', path, callback)
end

--[=[
	@param path Path
	@param callback (index: number, value: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a value is inserted in the array at the given path.
]=]
function ServerReplion:OnArrayInsert(path, callback)
	return self._signals:Connect('onArrayInsert', path, callback)
end

--[=[
	@param path Path
	@param callback (index: number, value: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a value is removed in the array at the given path.
]=]
function ServerReplion:OnArrayRemove(path, callback)
	return self._signals:Connect('onArrayRemove', path, callback)
end

type DescendantCallback = (path: { string }, newDescendantValue: any, oldDescendantValue: any) -> ()

--[=[
	@param path Path
	@param callback (path: { string }, newDescendantValue: any, oldDescendantValue: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a descendant value is changed.
]=]
function ServerReplion:OnDescendantChange(path, callback)
	return self._signals:Connect('onDescendantChange', path, callback)
end

--[=[
	Sets the players to which the data should be replicated.
]=]
function ServerReplion:SetReplicateTo(replicateTo: ReplicateTo)
	local isAll: boolean = replicateTo == 'All'
	local isATable: boolean = type(replicateTo) == 'table'
	local isAPlayer: boolean = typeof(replicateTo) == 'Instance' and replicateTo:IsA('Player')

	assert(isAll or isATable or isAPlayer, 'ReplicateTo must be a Player, a table of Players, or "All"')

	local oldReplicateTo = self.ReplicateTo

	-- We need to send to the Removed event to the old players.
	if typeof(oldReplicateTo) == 'Instance' then
		Network.sendTo(oldReplicateTo, 'Removed', self._packedId)
	elseif type(oldReplicateTo) == 'table' then
		for _, player in oldReplicateTo do
			Network.sendTo(player, 'Removed', self._packedId)
		end
	elseif type(oldReplicateTo) == 'string' then
		Network.sendTo('All', 'Removed', self._packedId)
	end

	self.ReplicateTo = replicateTo

	Network.sendTo(replicateTo, 'UpdateReplicateTo', self._packedId, replicateTo)
end

--[=[
	```lua
	local newCoins: number = Replion:Set('Coins', 79)
	print(newCoins) --> 79
	```

	@param path Path
	@param newValue T

	Sets the value at the given path to the given value.
]=]
function ServerReplion:Set<T>(path, newValue: T): T
	local pathTable = Utils.getPathTable(path)

	local currentValue: T? = Freeze.Dictionary.getIn(self.Data, pathTable)
	if currentValue and Freeze.Dictionary.equals(currentValue :: any, newValue) then
		return currentValue :: T
	end

	local newData = Freeze.Dictionary.setIn(self.Data, pathTable, newValue)
	local oldData = self.Data

	self.Data = newData

	self._signals:FireEvent('onDataChange', '__root', newData, pathTable)
	self._signals:FireChange(path, newData, oldData)

	Network.sendTo(self.ReplicateTo, 'Set', self._packedId, path, newValue)

	return newValue
end

--[=[
	```lua
	local newReplion = ReplionServer.new({
		Channel = 'Data',
		ReplicateTo = 'All',
		Data = {
			Items = {
				Bow = true,
			}
		},
	})

	newReplion:Update('Items', {
		Sword = true,
		Bow = Replion.None
	})

	newReplion:Update({
		Level = 20,
	})
	```

	@param path Path
	@param toUpdate { [any]: any }?

	Updates the data with the given table. Only the keys that are different will be sent to the client.

	You can update the root data by passing a table as the first argument.

	If you want to remove a key, set it to `Replion.None`.
]=]
function ServerReplion:Update(path, toUpdate)
	local values = Freeze.Dictionary.filter(toUpdate or path :: Dictionary, function(value, key)
		return self.Data[key] ~= value
	end)

	if Freeze.isEmpty(values) then
		return
	end

	local oldData = self.Data
	local isRootUpdate = toUpdate == nil

	if isRootUpdate then
		local newData = Freeze.Dictionary.merge(self.Data, values)

		self.Data = newData

		self._signals:FireEvent('onDataChange', '__root', newData, {})

		for index, value in values do
			self._signals:FireEvent('onChange', index, Utils.getValue(value), oldData[index])
		end
	else
		local pathTable = Utils.getPathTable(path)
		local newData = Freeze.Dictionary.mergeIn(self.Data, pathTable, values)

		self.Data = newData

		self._signals:FireEvent('onDataChange', '__root', newData, pathTable)

		for index, value in values do
			local indexPath = Freeze.List.push(pathTable, index)
			local oldValue = Freeze.Dictionary.getIn(oldData, indexPath)

			self._signals:FireEvent('onChange', indexPath, Utils.getValue(value), oldValue)
		end

		self._signals:FireChange(path, newData, oldData)
	end

	local serializedUpdate = Freeze.Dictionary.map(values, function(value, key)
		return if value == Freeze.None then Utils.SerializedNone else value, key
	end)

	if isRootUpdate then
		Network.sendTo(self.ReplicateTo, 'Update', self._packedId, serializedUpdate)
	else
		Network.sendTo(self.ReplicateTo, 'Update', self._packedId, path, serializedUpdate)
	end
end

--[=[
	```lua
	local newCoins: number = Replion:Increase('Coins', 20)
	```

	@param path Path
	@param amount number

	Increases the value at the given path by the given amount.
]=]
function ServerReplion:Increase(path, amount)
	assert(type(amount) == 'number', `"amount" expected number, got {type(amount)}`)

	local currentValue: number = self:GetExpect(path, `"{Utils.getPathString(path)}" is not a valid path!`)

	return self:Set(path, currentValue + amount)
end

--[=[
	```lua
	local newCoins: number = Replion:Decrease('Coins', 20)
	```

	@param path Path
	@param amount number

	Decreases the value at the given path by the given amount.
]=]
function ServerReplion:Decrease(path, amount)
	return self:Increase(path, -amount)
end

--[=[
	```lua
	local newReplion = ReplionServer.new({
		Channel = 'Data',
		ReplicateTo = player,
		Data = {
			Items = {
				'Bow'
			}
		}
	})

	newReplion:Insert('Items', 'Sword')
	newReplion:Insert('Items', 'Diamond Sword', 1)
	```

	@param path Path
	@param value T
	@param index number?

	:::note Arrays only
	This only works on Arrays.

	Inserts a value into the array at the given path, and returns the index and value. 
	If no index is given, it will insert the value at the end of the array.
]=]
function ServerReplion:Insert<T>(path, value: T, index)
	local pathTable = Utils.getPathTable(path)

	local array =
		assert(Freeze.Dictionary.getIn(self.Data, pathTable), `"{Utils.getPathString(path)}" is not a valid path!`)
	local targetIndex: number = if index then index else #array + 1

	local newArray = Freeze.List.insert(array, targetIndex, value)

	local oldData = self.Data
	local newData = Freeze.Dictionary.setIn(self.Data, pathTable, newArray)

	self.Data = newData

	self._signals:FireEvent('onDataChange', '__root', newData, pathTable)
	self._signals:FireEvent('onArrayInsert', pathTable, targetIndex, value)
	self._signals:FireChange(pathTable, newData, oldData)

	Network.sendTo(self.ReplicateTo, 'ArrayUpdate', self._packedId, 'i', path, value, index)
end

--[=[
	```lua
	local newReplion = ReplionServer.new({
		Channel = 'Data',
		ReplicateTo = player,
		Data = {
			Items = {
				'Bow'
			}
		}
	})

	local item: string = newReplion:Remove('Items')
	print(item) --> 'Bow'
	```

	@param path Path
	@param index number?

	:::note Arrays only
	This only works on Arrays.

	Removes a value from the array at the given path, and returns the value.
	If no index is given, it will remove the value at the end of the array.
]=]
function ServerReplion:Remove<T>(path, index): T
	local pathTable = Utils.getPathTable(path)

	local array =
		assert(Freeze.Dictionary.getIn(self.Data, pathTable), `"{Utils.getPathString(path)}" is not a valid path!`)
	local targetIndex: number = if index then index else #array
	local value = array[targetIndex]

	local newArray = Freeze.List.remove(array, targetIndex)

	local oldData = self.Data
	local newData = Freeze.Dictionary.setIn(self.Data, pathTable, newArray)

	self.Data = newData

	self._signals:FireEvent('onDataChange', '__root', newData, pathTable)
	self._signals:FireEvent('onArrayRemove', path, targetIndex, value)
	self._signals:FireChange(path, newData, oldData)

	Network.sendTo(self.ReplicateTo, 'ArrayUpdate', self._packedId, 'r', path, index)

	return value
end

--[=[
	```lua
	local newReplion = ReplionServer.new({
		Channel = 'Data',
		ReplicateTo = player,
		Data = {
			Items = {
				'Bow'
			}
		}
	})

	newReplion:Clear('Items')

	print(newReplion:Get('Items')) --> {}
	```

	@param path Path

	:::note Arrays only
	This only works on Arrays.

	Clears the array at the given path.
]=]
function ServerReplion:Clear(path)
	local array = self:GetExpect(path, `"{Utils.getPathString(path)}" is not a valid path!`)

	-- If the array is already empty, don't do anything
	if Freeze.isEmpty(array) then
		return
	end

	local pathTable = Utils.getPathTable(path)
	local oldData = self.Data
	local newData = Freeze.Dictionary.setIn(self.Data, pathTable, {})

	self.Data = newData

	self._signals:FireEvent('onDataChange', '__root', newData, pathTable)
	self._signals:FireChange(path, newData, oldData)

	Network.sendTo(self.ReplicateTo, 'ArrayUpdate', self._packedId, 'c', path)
end

--[=[
	```lua
	local newReplion = ReplionServer.new({
		Channel = 'Data',
		ReplicateTo = player,
		Data = {
			Items = {
				'Bow'
			}
		}
	})

	local index: number?, item: string? = newReplion:Find('Items', 'Bow')
	print(index, item) --> 1, 'Bow'
	```

	@param path Path
	@param value T

	:::note Arrays only
	This only works on Arrays.

	Try to find the value in the array at the given path, and returns the index and value.
]=]
function ServerReplion:Find<T>(path, value: T): (number?, T?)
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
	local coins: number = Replion:Get('Coins')
	```

	@param path Path

	Returns the value at the given path.
]=]
function ServerReplion:Get<T>(path): T?
	assert(path, 'Path is required!')

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
function ServerReplion:GetExpect<T>(path, message): T
	assert(path, 'Path is required!')

	message = if message then message else `"{Utils.getPathString(path)}" is not a valid path!`

	local value: T? = self:Get(path)
	if value == nil then
		error(message)
	end

	return value
end

--[=[
	Disconnects all signals and send a Destroy event to the ReplicateTo.
	You cannot use a Replion after destroying it, this will throw an error.
]=]
function ServerReplion:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	self._beforeDestroy:Fire(self)
	self._beforeDestroy:DisconnectAll()

	self._signals:Destroy()

	Network.sendTo(self.ReplicateTo, 'Removed', self._packedId)

	table.insert(availableIds, self._id)
end

return ServerReplion
