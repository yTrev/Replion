--!strict
local Network = require(script.Parent.Parent.Internal.Network)
local Signal = require(script.Parent.Parent.Parent.Signal)

local Utils = require(script.Parent.Parent.Internal.Utils)
local Signals = require(script.Parent.Parent.Internal.Signals)

local _T = require(script.Parent.Parent.Internal.Types)

type Path = _T.Path
type ExtensionCallback = _T.ExtensionCallback<ServerReplion>
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
	Tags: { string }?,
	Extensions: { [string]: ExtensionCallback }?,

	_replicateTo: ReplicateTo,
	_extensionModule: ModuleScript?,
	_beforeDestroy: _T.Signal,
	_signals: typeof(Signals.new()),
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
	@type SerializedReplion { Data: Dictionary, Channel: string, Tags: {string}?, Extensions: ModuleScript? }

	@within ServerReplion
]=]

--[=[
	@type Dictionary { [any]: any }

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

	local self: ServerReplion = setmetatable({
		Channel = config.Channel,

		Data = config.Data,
		Tags = config.Tags,

		Extensions = if config.Extensions then require(config.Extensions) :: any else nil,

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
	@private

	Serializes the data to be sent to the client.
]=]
function ServerReplion._serialize(self: ServerReplion): _T.SerializedReplion
	-- The initial data that is sent to the client, probably will be the most expensive part of the replication.
	-- But it's only done once, so it's not that bad. We can optimize this later if needed, but for now it's fine.
	return {
		Channel = self.Channel,

		Data = self.Data,
		Tags = self.Tags,
		Extensions = self._extensionModule,

		Id = self._packedId,
	}
end

--[=[
	@return RBXScriptConnection

	Connects to a signal that is fired when the :Destroy() method is called.
]=]
function ServerReplion.BeforeDestroy(self: ServerReplion, callback: (ServerReplion) -> ()): _T.Connection
	return self._beforeDestroy:Connect(callback)
end

--[=[
	@return RBXScriptConnection

	Connects to a signal that is fired when the value at the given path is changed.
]=]
function ServerReplion.OnChange(self: ServerReplion, path: Path, callback: _T.ChangeCallback): _T.Connection
	return self._signals:Get('onChange', path):Connect(callback)
end

--[=[
	@param callback (index: number, value: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a value is inserted in the array at the given path.
]=]
function ServerReplion.OnArrayInsert(self: ServerReplion, path: Path, callback: _T.ArrayCallback): _T.Connection
	return self._signals:Get('onArrayInsert', path):Connect(callback)
end

--[=[
	@param callback (index: number, value: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a value is removed in the array at the given path.
]=]
function ServerReplion.OnArrayRemove(self: ServerReplion, path: Path, callback: _T.ArrayCallback): _T.Connection
	return self._signals:Get('onArrayRemove', path):Connect(callback)
end

type DescendantCallback = (path: { string }, newDescendantValue: any, oldDescendantValue: any) -> ()

--[=[
	@param callback (path: { string }, newDescendantValue: any, oldDescendantValue: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a descendant value is changed.
]=]
function ServerReplion.OnDescendantChange(self: ServerReplion, path: Path, callback: DescendantCallback): _T.Connection
	return self._signals:Get('onDescendantChange', path):Connect(callback)
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
	Executes an extension function, if it doesn't exist, it will throw an error.
]=]
function ServerReplion.Execute(self: ServerReplion, name: string, ...: any): ...any
	local extensions = assert(self.Extensions, tostring(self) .. ' has not extensions.')
	local extension = assert(extensions[name], tostring(self) .. ' has no extension named ' .. name)

	self._signals:Pause()

	local result = table.pack(extension(self, ...))

	self._signals:Resume()

	-- We could optimize this by creating and ID for each function, but I don't think it's worth it.
	Network.sendTo(self._replicateTo, 'RunExtension', self._packedId, name, ...)

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
	local currentValue, key = Utils.getFromPath(pathTable, self.Data)
	local oldValue = currentValue[key]

	if equals(oldValue, newValue :: any) then
		return oldValue
	end

	local oldParentValue = if #pathTable > 1 then table.clone(currentValue) else nil
	currentValue[key] = newValue

	if not self._signals:IsPaused() then
		if oldParentValue then
			self._signals:FireParent('onChange', pathTable, currentValue, oldParentValue)
		end

		self._signals:Fire('onChange', path, newValue, oldValue)

		Network.sendTo(self._replicateTo, 'Set', self._packedId, Utils.getStringPath(path), newValue)
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
	```

	Updates the data with the given table. Only the keys that are different will be sent to the client.
]=]
function ServerReplion.Update(self: ServerReplion, path: Path | Dictionary, toUpdate: Dictionary?): Dictionary?
	local newValue, oldValue

	if toUpdate == nil then
		path = Utils.removeDuplicated(self.Data, path :: Dictionary)

		if isEmpty(path :: Dictionary) then
			return nil
		end

		oldValue = self.Data

		local newData: Dictionary = merge(self.Data, path :: Dictionary)
		self.Data = newData

		newValue = newData

		for index, value in path :: Dictionary do
			self._signals:Fire('onChange', index, value, oldValue[index])
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

		for index, value in toUpdate do
			self._signals:Fire('onChange', index, value, if oldValue then oldValue[index] else nil)
		end

		newValue = currentValue[key]
	end

	if not self._signals:IsPaused() then
		self._signals:Fire('onChange', path, newValue, oldValue)

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

		Network.sendTo(self._replicateTo, 'Update', self._packedId, Utils.getStringPath(path), toUpdate)
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
	if type(amount) ~= 'number' then
		error('[Replion] - Amount must be a number.')
	end

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

	local array = data[last]
	if type(array) == 'table' then
		local targetIndex: number = if index then index else #array + 1

		table.insert(array, targetIndex, value)

		if not self._signals:IsPaused() then
			self._signals:Fire('onArrayInsert', path, targetIndex, value)

			Network.sendTo(
				self._replicateTo,
				'ArrayUpdate',
				self._packedId,
				'i',
				Utils.getStringPath(path),
				value,
				index
			)
		end

		return targetIndex, value
	else
		error('[Replion] - Cannot insert into a non-array.')
	end
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

	local array = data[last]
	if type(array) == 'table' then
		local targetIndex: number = if index then index else #array
		local value = table.remove(array, targetIndex)

		if not self._signals:IsPaused() then
			self._signals:Fire('onArrayRemove', path, targetIndex, value)

			Network.sendTo(self._replicateTo, 'ArrayUpdate', self._packedId, 'r', Utils.getStringPath(path), index)
		end

		return value
	else
		error('[Replion] - Cannot remove from a non-array.')
	end
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
function ServerReplion.Find(self: ServerReplion, path: Path, value: any): (number?, any)
	local array: { any } = self:GetExpect(path)
	local index: number? = table.find(array, value)

	if index then
		return index, value
	else
		return
	end
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

	local array = data[last]
	if array then
		table.clear(array)

		if not self._signals:IsPaused() then
			self._signals:Fire('onChange', path, data[last], array)

			Network.sendTo(self._replicateTo, 'ArrayUpdate', self._packedId, 'c', Utils.getStringPath(path))
		end
	else
		error('[Replion] - Cannot clear from a non-array.')
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

function ServerReplion.Destroy(self: ServerReplion)
	self._beforeDestroy:Fire()
	self._beforeDestroy:DisconnectAll()

	self._signals:Destroy()

	table.insert(availableIds, self._id)

	Network.sendTo(self._replicateTo, 'Removed', self._packedId)
end

export type ServerReplion = typeof(setmetatable({} :: ServerReplionProps, ServerReplion))

return ServerReplion
