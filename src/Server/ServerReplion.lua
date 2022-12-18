--!strict
local Network = require(script.Parent.Parent.Internal.Network)
local Signal = require(script.Parent.Parent.Parent.Signal)

local Utils = require(script.Parent.Parent.Internal.Utils)
local Signals = require(script.Parent.Parent.Internal.Signals)

local _T = require(script.Parent.Parent.Internal.Types)

type Path = _T.Path
type ExtensionCallback = _T.ExtensionCallback<ServerReplion>
type BeforeDestroyCallback = _T.BeforeDestroy<ServerReplion>
type ArrayCallback = _T.ArrayCallback
type Dictionary = _T.Dictionary
type ReplicateTo = Player | { Player } | 'All'

export type ReplionConfig = {
	Channel: string,

	Data: { [any]: any },
	ReplicateTo: ReplicateTo,

	Tags: { string }?,
	Extensions: ModuleScript?,
}

type ServerReplionProps = {
	Data: { [any]: any },
	Channel: string,
	Tags: { string },

	Destroyed: boolean?,

	_extensions: { [string]: any },
	_replicateTo: ReplicateTo,
	_extensionModule: ModuleScript?,
	_beforeDestroy: _T.Signal,
	_signals: Signals.Signals,
	_runningExtension: boolean?,

	_id: number,
	_packedId: string,
}

-- Unsigned short
local ID_PACK: string = 'H'
local ID_LIMIT: number = 65535

local merge = Utils.merge
local isEmpty = Utils.isEmpty
local equals = Utils.equals

local id: number = 0
local availableIds: { number } = {}

--[=[
	@type ReplicateTo Player | { Player } | 'All'

	@within ServerReplion
]=]

--[=[
	@type SerializedReplion { any }

	@within ServerReplion
]=]

--[=[
	@type Dictionary { [any]: any }

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
	@class ServerReplion	

	@server
]=]
local ServerReplion = {}
ServerReplion.__index = ServerReplion

function ServerReplion.new(config: ReplionConfig): ServerReplion
	assert(config.Channel, '[Replion] - Channel is required!')
	assert(config.ReplicateTo, '[Replion] - ReplicateTo is required!')

	local replicateTo: ReplicateTo = config.ReplicateTo

	local selectedId: number
	if availableIds[1] ~= nil then
		selectedId = table.remove(availableIds, 1) :: number
	else
		id += 1

		selectedId = id
	end

	assert(selectedId <= ID_LIMIT, '[Replion] - ID limit reached! You already have ' .. ID_LIMIT .. ' ServerReplions!')

	local extensions = {}

	if config.Extensions then
		local loadedExtensions = require(config.Extensions) :: any

		local orderedExtensions = {}
		for name, extension in loadedExtensions :: any do
			table.insert(orderedExtensions, { name, extension })
		end

		table.sort(orderedExtensions, function(a, b)
			return a[1] < b[1]
		end)

		for extensionId, extension in orderedExtensions do
			extensions[extension[1]] = { string.pack(ID_PACK, extensionId), extension[2] }
		end
	end

	local self: ServerReplion = setmetatable({
		Channel = config.Channel,

		Data = config.Data,
		Tags = if config.Tags then config.Tags else {},

		_extensions = extensions,

		_id = selectedId,
		_packedId = string.pack(ID_PACK, selectedId),

		_extensionModule = config.Extensions,
		_replicateTo = replicateTo,
		_beforeDestroy = Signal.new(),
		_signals = Signals.new(),
	}, ServerReplion)

	Network.sendTo(replicateTo, 'Added', self:_serialize())

	return self
end

function ServerReplion.__tostring(self: ServerReplion)
	local channel: string = self.Channel
	local replicateTo = self._replicateTo

	local replicatingTo: string
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

	return 'Replion<' .. channel .. ':' .. replicatingTo .. '>'
end

--[=[
	@return SerializedReplion
	@private

	Serializes the data to be sent to the client.
]=]
function ServerReplion._serialize(self: ServerReplion): _T.SerializedReplion
	-- The initial data that is sent to the client, probably will be the most expensive part of the replication.
	-- But it's only done once, so it's not that bad. We can optimize this later if needed, but for now it's fine.

	return { self._packedId, self.Channel, self.Data, self.Tags, self._extensionModule }
end

--[=[
	@return RBXScriptConnection

	Connects to a signal that is fired when the :Destroy() method is called.
]=]
function ServerReplion.BeforeDestroy(self: ServerReplion, callback: (ServerReplion) -> ()): _T.Connection
	return self._beforeDestroy:Connect(callback)
end

--[=[
	@param callback (newValue: any, oldValue: any) -> ()
	@return RBXScriptConnection

	Connects to a signal that is fired when the value at the given path is changed.
]=]
function ServerReplion.OnChange(self: ServerReplion, path: Path, callback: _T.ChangeCallback): _T.Connection?
	local onChange = self._signals:Get('onChange', path)
	if onChange then
		return onChange:Connect(callback)
	end

	return
end

--[=[
	@param callback (index: number, value: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a value is inserted in the array at the given path.
]=]
function ServerReplion.OnArrayInsert(self: ServerReplion, path: Path, callback: ArrayCallback): _T.Connection?
	local onArrayInsert = self._signals:Get('onArrayInsert', path)
	if onArrayInsert then
		return onArrayInsert:Connect(callback)
	end

	return
end

--[=[
	@param callback (index: number, value: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a value is removed in the array at the given path.
]=]
function ServerReplion.OnArrayRemove(self: ServerReplion, path: Path, callback: ArrayCallback): _T.Connection?
	local onArrayRemove = self._signals:Get('onArrayRemove', path)
	if onArrayRemove then
		return onArrayRemove:Connect(callback)
	end

	return
end

type DescendantCallback = (path: { string }, newDescendantValue: any, oldDescendantValue: any) -> ()

--[=[
	@param callback (path: { string }, newDescendantValue: any, oldDescendantValue: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a descendant value is changed.
]=]
function ServerReplion.OnDescendantChange(self: ServerReplion, path: Path, callback: DescendantCallback): _T.Connection?
	local onDescendantChange = self._signals:Get('onDescendantChange', path)
	if onDescendantChange then
		return onDescendantChange:Connect(callback)
	end

	return
end

--[=[
	Sets the players to which the data should be replicated.
]=]
function ServerReplion.SetReplicateTo(self: ServerReplion, replicateTo: ReplicateTo)
	local isAll: boolean = replicateTo == 'All'
	local isATable: boolean = type(replicateTo) == 'table'
	local isAPlayer: boolean = typeof(replicateTo) == 'Instance' and replicateTo:IsA('Player')

	assert(isAll or isATable or isAPlayer, '[Replion] - ReplicateTo must be a Player, a table of Players, or "All"')

	local oldReplicateTo = self._replicateTo
	local oldType: string = typeof(oldReplicateTo)

	-- We need to send to the Removed event to the old players.
	if oldType == 'Instance' then
		Network.sendTo(oldReplicateTo, 'Removed', self._packedId)
	elseif oldType == 'table' then
		for _, player in oldReplicateTo :: { Player } do
			Network.sendTo(player, 'Removed', self._packedId)
		end
	elseif oldType == 'string' then
		Network.sendTo('All', 'Removed', self._packedId)
	end

	self._replicateTo = replicateTo
end

--[=[
	@return ReplicateTo
]=]
function ServerReplion.GetReplicateTo(self: ServerReplion): ReplicateTo
	return self._replicateTo
end

--[=[
	Executes an extension function, if it doesn't exist, it will throw an error.
]=]
function ServerReplion.Execute(self: ServerReplion, name: string, ...: any): ...any
	local extensions = self._extensions
	local extension = assert(extensions[name], tostring(self) .. ' has no extension named ' .. name)

	local extensionId: string = extension[1]
	local extensionFunction: ExtensionCallback = extension[2]

	self._runningExtension = true

	local result = table.pack(extensionFunction(self, ...))

	self._runningExtension = false

	-- We could optimize this by creating and ID for each function, but I don't think it's worth it.
	Network.sendTo(self._replicateTo, 'RunExtension', self._packedId, extensionId, ...)

	return table.unpack(result)
end

--[=[
	```lua
	local newCoins: number = Replion:Set('Coins', 79)
	print(newCoins) --> 79
	```

	Sets the value at the given path to the given value.
]=]
function ServerReplion.Set<T>(self: ServerReplion, path: Path, newValue: T): T
	local pathTable = Utils.getPathTable(path)
	local currentValue, key = Utils.getFromPath(path, self.Data)
	local oldValue = currentValue[key]

	if equals(oldValue, newValue :: any) then
		return oldValue
	end

	local oldParentValue = if #pathTable > 1 then table.clone(currentValue) else nil
	currentValue[key] = newValue

	if oldParentValue then
		self._signals:FireParent('onChange', pathTable, currentValue, oldParentValue)
	end

	self._signals:Fire('onChange', path, newValue, oldValue)

	if not self._runningExtension then
		Network.sendTo(self._replicateTo, 'Set', self._packedId, Utils.serializePath(path), newValue)
	end

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

	local newItems = newReplion:Update('Items', {
		Sword = true,
		Bow = Replion.None
	})

	print(newItems) --> { Sword = true }

	local newData = newReplion:Update({
		Level = 20,
	})

	print(newData) --> { Items = { Sword = true }, Level = 20 }
	```

	Updates the data with the given table. Only the keys that are different will be sent to the client.

	You can update the root data by passing a table as the first argument.

	If you want to remove a key, set it to `Replion.None`.
]=]
function ServerReplion.Update(self: ServerReplion, path: Path | Dictionary, toUpdate: Dictionary?): Dictionary?
	local newValue, oldValue

	if toUpdate == nil then
		path = Utils.removeDuplicated(self.Data, path :: Dictionary)

		if isEmpty(path :: Dictionary) then
			return nil
		end

		oldValue = table.clone(self.Data)

		-- We can't use merge because we need to change the original data instead of a copy.
		for key, value in path :: Dictionary do
			self.Data[key] = Utils.getValue(value)
		end

		newValue = self.Data

		for index, value in path :: Dictionary do
			self._signals:Fire('onChange', index, Utils.getValue(value), oldValue[index])
		end
	else
		local pathTable = Utils.getPathTable(path)
		local currentValue, key = Utils.getFromPath(path, self.Data)
		local oldParentValue = if #pathTable > 1 then table.clone(currentValue) else nil

		if currentValue[key] ~= nil then
			toUpdate = Utils.removeDuplicated(currentValue, toUpdate)

			if isEmpty(toUpdate) then
				return nil
			end

			oldValue = currentValue[key]
			currentValue[key] = merge(currentValue[key], toUpdate)
		else
			currentValue[key] = toUpdate
		end

		if oldParentValue then
			self._signals:FireParent('onChange', pathTable, currentValue, oldParentValue)
		end

		local newLast = #pathTable + 1
		for index, value in toUpdate do
			pathTable[newLast] = index

			self._signals:Fire('onChange', pathTable, Utils.getValue(value), if oldValue then oldValue[index] else nil)
		end

		pathTable[newLast] = nil

		newValue = currentValue[key]
	end

	self._signals:Fire('onChange', path, newValue, oldValue)

	if not self._runningExtension then
		-- Serialize the None symbol.
		if toUpdate then
			for index, value in toUpdate do
				if value == Utils.None then
					toUpdate[index] = Utils.SerializedNone
				end
			end
		else
			for index, value in path :: Dictionary do
				if value == Utils.None then
					(path :: Dictionary)[index] = Utils.SerializedNone
				end
			end
		end

		Network.sendTo(self._replicateTo, 'Update', self._packedId, Utils.serializePath(path), toUpdate)
	end

	return newValue
end

--[=[
	```lua
	local newCoins: number = Replion:Increase('Coins', 20)
	```

	Increases the value at the given path by the given amount.
]=]
function ServerReplion.Increase(self: ServerReplion, path: Path, amount: number): number
	assert(type(amount) == 'number', '[Replion] - Amount must be a number.')

	local currentValue: number = self:Get(path)
	return self:Set(path, currentValue + amount)
end

--[=[
	```lua
	local newCoins: number = Replion:Decrease('Coins', 20)
	```

	Decreases the value at the given path by the given amount.
]=]
function ServerReplion.Decrease(self: ServerReplion, path: Path, amount: number): number
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

	local index: number, item: string = newReplion:Insert('Items', 'Sword')
	print(index, item) --> 2, 'Sword'
	```

	:::note Arrays only
	This only works on Arrays.

	Inserts a value into the array at the given path, and returns the index and value. 
	If no index is given, it will insert the value at the end of the array.
]=]
function ServerReplion.Insert<T>(self: ServerReplion, path: Path, value: T, index: number?): (number, T)
	local data, last = Utils.getFromPath(path, self.Data)

	local array = assert(data[last], '[Replion] - Cannot insert into a non-array.')
	local newArray = table.clone(array)
	local targetIndex: number = if index then index else #newArray + 1

	table.insert(newArray, targetIndex, value)

	data[last] = newArray

	self._signals:Fire('onArrayInsert', path, targetIndex, value)
	self._signals:Fire('onChange', path, newArray, array)

	if not self._runningExtension then
		Network.sendTo(self._replicateTo, 'ArrayUpdate', self._packedId, 'i', Utils.serializePath(path), value, index)
	end

	return targetIndex, value
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

	:::note Arrays only
	This only works on Arrays.

	Removes a value from the array at the given path, and returns the value.
	If no index is given, it will remove the value at the end of the array.
]=]
function ServerReplion.Remove(self: ServerReplion, path: Path, index: number?): any
	local data, last = Utils.getFromPath(path, self.Data)

	local array = assert(data[last], '[Replion] - Cannot remove from a non-array.')
	local newArray = table.clone(array)

	local targetIndex: number = if index then index else #newArray
	local value = table.remove(newArray, targetIndex)

	data[last] = newArray

	self._signals:Fire('onArrayRemove', path, targetIndex, value)
	self._signals:Fire('onChange', path, newArray, array)

	if not self._runningExtension then
		Network.sendTo(self._replicateTo, 'ArrayUpdate', self._packedId, 'r', Utils.serializePath(path), index)
	end

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

	local index: number?, item: string? = newReplion:Find('Items', 'Bow')
	print(index, item) --> 1, 'Bow'
	```

	:::note Arrays only
	This only works on Arrays.

	Try to find the value in the array at the given path, and returns the index and value.
]=]
function ServerReplion.Find<T>(self: ServerReplion, path: Path, value: T): (number?, T?)
	local array: { any } = self:Get(path)
	if array then
		local index: number? = table.find(array, value)

		if index then
			return index, value
		end
	end

	return
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

	:::note Arrays only
	This only works on Arrays.

	Clears the array at the given path, using the `table.clear`.
]=]
function ServerReplion.Clear(self: ServerReplion, path: Path)
	local data, last = Utils.getFromPath(path, self.Data)

	local array = assert(data[last], '[Replion] - Cannot clear from a non-array.')

	-- If the array is already empty, don't do anything.
	if Utils.isEmpty(array) then
		return
	end

	local oldArray = table.clone(array)

	table.clear(array)

	self._signals:Fire('onChange', path, array, oldArray)

	if not self._runningExtension then
		Network.sendTo(self._replicateTo, 'ArrayUpdate', self._packedId, 'c', Utils.serializePath(path))
	end
end

--[=[
	```lua
	local coins: number = Replion:Get('Coins')
	local data = Replion:Get()
	```

	Returns the value at the given path, or the entire data if no path is given.
]=]
function ServerReplion.Get(self: ServerReplion, path: Path?): any
	if path then
		local data: any, last = Utils.getFromPath(path, self.Data)

		return data[last]
	else
		return self.Data
	end
end

--[=[
	```lua
	local coins: number = Replion:GetExpect('Coins')
	local gems: number = Replion:GetExpect('Gems', 'Gems does not exist!')
	```

	@error "Invalid path" -- This error is thrown when the path does not have a value.

	Same as `Replion:Get`, but throws an error if the path does not have a value.
	You can set a custom error message by passing it as the second argument.
]=]
function ServerReplion.GetExpect(self: ServerReplion, path: Path, message: string?): any
	local data: any, last = Utils.getFromPath(path, self.Data)

	return assert(data[last], if message then message else 'Invalid path.')
end

--[=[
	Disconnects all signals and send a Destroy event to the ReplicateTo.
	You cannot use a Replion after destroying it, this will throw an error.
]=]
function ServerReplion.Destroy(self: ServerReplion)
	self.Destroyed = true

	self._beforeDestroy:Fire()
	self._beforeDestroy:DisconnectAll()

	self._signals:Destroy()

	table.insert(availableIds, self._id)

	Network.sendTo(self._replicateTo, 'Removed', self._packedId)
end

export type ServerReplion = typeof(setmetatable({} :: ServerReplionProps, ServerReplion))

return ServerReplion
