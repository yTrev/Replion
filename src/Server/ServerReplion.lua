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
	@type SerializedReplion { Data: {[any]: any}, Channel: string, Tags: {string}?, Extensions: ModuleScript? }

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
	Executes an extension function if it exists.
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
	Connects to a signal that is fired when the :Destroy() method is called.
]=]
function ServerReplion.BeforeDestroy(self: ServerReplion, callback: (ServerReplion) -> ()): _T.Connection
	return self._beforeDestroy:Connect(callback)
end

--[=[
	Connects to a signal that is fired when the value at the given path is changed.
]=]
function ServerReplion.OnChange(self: ServerReplion, path: Path, callback: _T.ChangeCallback): _T.Connection
	return self._signals:Get('onChange', path):Connect(callback)
end

--[=[
	Connects to a signal that is fired when a value is inserted in the array at the given path.
]=]
function ServerReplion.OnArrayInsert(self: ServerReplion, path: Path, callback: _T.ArrayCallback): _T.Connection
	return self._signals:Get('onArrayInsert', path):Connect(callback)
end

--[=[
	Connects to a signal that is fired when a value is removed in the array at the given path.
]=]
function ServerReplion.OnArrayRemove(self: ServerReplion, path: Path, callback: _T.ArrayCallback): _T.Connection
	return self._signals:Get('onArrayRemove', path):Connect(callback)
end

type DescendantCallback = (path: { string }, newDescendantValue: any, oldDescendantValue: any) -> ()

--[=[
	Connects to a signal that is fired when a descendant value is changed.
]=]
function ServerReplion.OnDescendantChange(
	self: ServerReplion,
	path: _T.Path,
	callback: DescendantCallback
): _T.Connection
	return self._signals:Get('onDescendantChange', path):Connect(callback)
end

--[=[
	```lua
	local newCoins: number = Replion:Set('Coins', 79)
	print(newCoins) -> 79
	```
]=]
function ServerReplion.Set(self: ServerReplion, path: Path, newValue: any): any
	local pathTable = Utils.getPathTable(path)
	local currentValue, key = Utils.getFromPath(pathTable, self.Data)
	local oldValue = currentValue[key]

	if equals(oldValue, newValue) then
		return
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
	Updates the data with the given table.
]=]
function ServerReplion.Update(self: ServerReplion, path: Path | Dictionary, toUpdate: Dictionary?): Dictionary?
	local newValue, oldValue

	if toUpdate == nil then
		path = Utils.removeDuplicated(self.Data, path :: Dictionary)

		if isEmpty(path :: Dictionary) then
			return nil
		end

		oldValue = self.Data

		for index, value in path :: Dictionary do
			self._signals:Fire('onChange', index, value, oldValue[index])
		end

		local newData: Dictionary = merge(self.Data, path :: Dictionary)
		self.Data = newData

		newValue = newData
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
]=]
function ServerReplion.Decrease(self: ServerReplion, path: Path, amount: number): number
	return self:Increase(path, -amount)
end

--[=[
	```lua
	local newCoins: number = Replion:Insert('Coins', 20)
	```
]=]
function ServerReplion.Insert(self: ServerReplion, path: Path, value: any, index: number?): (number, any)
	local data, last = Utils.getFromPath(path, self.Data)

	local array = data[last]
	if type(array) == 'table' then
		index = if index then index else #array + 1

		table.insert(array, index :: number, value)

		if not self._signals:IsPaused() then
			self._signals:Fire('onArrayInsert', path, index, value)

			Network.sendTo(
				self._replicateTo,
				'ArrayUpdate',
				self._packedId,
				'i',
				Utils.getStringPath(path),
				index,
				value
			)
		end

		return index :: number, value
	else
		error('[Replion] - Cannot insert into a non-array.')
	end
end

function ServerReplion.Remove(self: ServerReplion, path: Path, index: number?): any
	local data, last = Utils.getFromPath(path, self.Data)

	local array = data[last]
	if type(array) == 'table' then
		index = if index then index else #array + 1

		local value = table.remove(array, index :: number)

		if not self._signals:IsPaused() then
			self._signals:Fire('onArrayRemove', path, index, value)

			Network.sendTo(
				self._replicateTo,
				'ArrayUpdate',
				self._packedId,
				'r',
				Utils.getStringPath(path),
				index,
				value
			)
		end

		return value
	else
		error('[Replion] - Cannot remove from a non-array.')
	end
end

function ServerReplion.Find(self: ServerReplion, path: Path, value: any): (number?, any)
	local array: { any } = self:GetExpect(path)
	local index: number? = table.find(array, value)

	if index then
		return index, value
	else
		return
	end
end

function ServerReplion.Clear(self: ServerReplion, path: Path)
	local data, last = Utils.getFromPath(path, self.Data)

	local array = data[last]
	if array then
		table.clear(array)

		if not self._signals:IsPaused() then
			self._signals:Fire('onClear', path, data[last], array)

			Network.sendTo(self._replicateTo, 'ArrayUpdate', self._packedId, 'c', path)
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
	local coins: number = Replion:Get('Coins')
	```

	@param message string
	@error "Invalid path" -- This error is thrown when the path does not have a value.
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
