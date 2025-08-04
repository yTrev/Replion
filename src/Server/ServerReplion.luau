local Players = game:GetService('Players')

local Network = require(script.Parent.Parent.Internal.Network)
local Signal = require(script.Parent.Parent.Parent.Signal)

local Utils = require(script.Parent.Parent.Internal.Utils)
local Graph = require(script.Parent.Parent.Internal.Graph)

local _T = require(script.Parent.Parent.Internal.Types)

local Freeze = require(script.Parent.Parent.Parent.Freeze)

export type ServerReplionData<D = any> = {
	Channel: string,
	Data: D,
	Destroyed: boolean?,
	Tags: { string },
	ReplicateTo: _T.ReplicateTo,

	_beforeDestroy: Signal.Signal<nil>,
	_rootNode: Graph.Node?,
	_replicateToChanged: Signal.Signal<_T.ReplicateTo, _T.ReplicateTo>,

	_id: number,
	_packedId: string,

	new: <T>(config: ReplionConfig<T>) -> ServerReplion<D>,
	BeforeDestroy: (self: ServerReplion<D>, callback: () -> ()) -> Signal.Connection,

	OnDataChange: (self: ServerReplion<D>, callback: (newData: D, path: _T.Path) -> ()) -> Signal.Connection,
	OnChange: <T>(
		self: ServerReplion<D>,
		path: _T.Path,
		callback: (newValue: T, oldValue: T) -> ()
	) -> Signal.Connection,

	OnArrayInsert: (self: ServerReplion<D>, path: _T.Path, callback: _T.ArrayCallback) -> Signal.Connection,
	OnArrayRemove: (self: ServerReplion<D>, path: _T.Path, callback: _T.ArrayCallback) -> Signal.Connection,

	SetReplicateTo: (self: ServerReplion<D>, replicateTo: _T.ReplicateTo) -> (),

	Set: <T>(self: ServerReplion<D>, path: _T.Path, newValue: T) -> T,
	Update: (self: ServerReplion<D>, path: _T.Path | any, toUpdate: _T.Dictionary?) -> (),

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
	ReplicateTo: _T.ReplicateTo,

	DisableAutoDestroy: boolean?,

	Tags: { string }?,
}

local ID_LIMIT = 65535
local MIN_IDS_TO_RECYCLE = 16

local currentId = 0
local availableIds: { number } = {}
local warnsSent = {}

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
	@prop DisableAutoDestroy boolean?
	@readonly

	@within ServerReplion
]=]

--[=[
	@class ServerReplion	

	@server
]=]
local ServerReplion = {}
ServerReplion.__index = ServerReplion

export type ServerReplion<D = any> = typeof(setmetatable({} :: ServerReplionData<D>, ServerReplion))

function ServerReplion.new<D>(config: ReplionConfig<D>): ServerReplion<D>
	assert(type(config.Channel) == 'string', `"Channel" expected string, got {type(config.Channel)}`)
	assert(config.ReplicateTo, 'ReplicateTo is required!')

	local replicateTo = config.ReplicateTo
	local selectedId

	if currentId + 1 > ID_LIMIT or #availableIds >= MIN_IDS_TO_RECYCLE then
		selectedId = table.remove(availableIds, 1)
	else
		currentId += 1

		selectedId = currentId
	end

	assert(selectedId, 'No available ID!')
	assert(selectedId <= ID_LIMIT, `ID limit reached! You already have {ID_LIMIT} ServerReplions!`)

	local self: ServerReplion<D> = setmetatable({
		Data = config.Data,
		Channel = config.Channel,
		Tags = if config.Tags then config.Tags else {},
		ReplicateTo = replicateTo,

		DisableAutoDestroy = config.DisableAutoDestroy,

		_id = selectedId,
		_packedId = utf8.char(selectedId),
		_beforeDestroy = Signal.new(),
		_rootNode = Graph.createRootNode(),
		_replicateToChanged = Signal.new(),
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
	return Graph.connect(self._rootNode, 'onDataChange', { '__root' }, callback)
end

--[=[
	@param path Path
	@param callback (newValue: any, oldValue: any) -> ()
	
	@return RBXScriptConnection

	Connects to a signal that is fired when the value at the given path is changed.
]=]
function ServerReplion:OnChange<V>(path, callback)
	return Graph.connect(self._rootNode, 'onChange', path, callback)
end

--[=[
	@param path Path
	@param callback (index: number, value: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a value is inserted in the array at the given path.
]=]
function ServerReplion:OnArrayInsert(path, callback)
	return Graph.connect(self._rootNode, 'onArrayInsert', path, callback)
end

--[=[
	@param path Path
	@param callback (index: number, value: any) -> ()

	@return RBXScriptConnection

	Connects to a signal that is fired when a value is removed in the array at the given path.
]=]
function ServerReplion:OnArrayRemove(path, callback)
	return Graph.connect(self._rootNode, 'onArrayRemove', path, callback)
end

--[=[
	@param replicateTo ReplicateTo	

	Sets the players to which the data should be replicated.
]=]
function ServerReplion:SetReplicateTo(replicateTo)
	assert(
		replicateTo == 'All'
			or type(replicateTo) == 'table'
			or typeof(replicateTo) == 'Instance' and replicateTo:IsA('Player'),
		'ReplicateTo must be a Player, a table of Players or "All"'
	)

	local oldReplicateTo = self.ReplicateTo
	if oldReplicateTo == replicateTo then
		return
	end

	local oldReplicateToPlayers = if oldReplicateTo == 'All'
		then Players:GetPlayers()
		elseif type(oldReplicateTo) == 'table' then oldReplicateTo
		else { oldReplicateTo }

	local newReplicateToPlayers = if replicateTo == 'All'
		then Players:GetPlayers()
		elseif type(replicateTo) == 'table' then replicateTo
		else { replicateTo }

	-- Send Removed event for old players that are not in the new list
	for _, player in oldReplicateToPlayers do
		if table.find(newReplicateToPlayers, player) then
			continue
		end

		Network.sendTo(player, 'Removed', self._packedId)
	end

	-- Send Added event for new players that are not in the old list
	for _, player in newReplicateToPlayers do
		if table.find(oldReplicateToPlayers, player) then
			continue
		end

		Network.sendTo(player, 'Added', self:_serialize())
	end

	self.ReplicateTo = replicateTo
	self._replicateToChanged:Fire(replicateTo, oldReplicateTo)

	Network.sendTo(replicateTo, 'UpdateReplicateTo', self._packedId, replicateTo)
end

--[=[
	```lua
	local newCoins: number = Replion:Set('Coins', 79)
	print(newCoins) --> 79
	```

	@param path Path | { [any] : any }
	@param newValue T

	Sets the value at the given path to the given value.
	If you're updating a table is recommended to use [ServerReplion:Update] instead of `ServerReplion:Set` 
	to avoid sending unnecessary data to the client.
]=]
function ServerReplion:Set<T>(path, newValue: T): T
	local pathTable = Utils.getPathTable(path)

	local currentValue: T? = Freeze.Dictionary.getIn(self.Data, pathTable)
	if Freeze.Dictionary.equals(currentValue :: any, newValue) then
		if _G.__DEV__ and type(currentValue) == 'table' then
			local scriptName, line = debug.info(2, 'sl')
			local lineString = `{scriptName}:{line}`
			local pathString = Utils.getPathString(path)

			if not warnsSent[lineString] then
				if currentValue == newValue then
					warn(
						`Warning: Skipping Replion:Set('{pathString}') due to identical table references.\n`
							.. `Consider using Replion:Update('{pathString}') at {scriptName}:{line} instead.`
					)
				elseif currentValue ~= newValue and type(newValue) == 'table' then
					warn(
						`Warning: Replion:Set('{pathString}') detected a new table reference, but all values inside are identical.\n`
							.. `This may indicate the use of a shallow clone for the table at Replion:Get('{pathString}') without properly cloning nested values. `
							.. `Review your table cloning logic at {scriptName}:{line}.`
					)
				end

				warnsSent[lineString] = true
			end
		end

		return currentValue :: T
	end

	if _G.__DEV__ and type(currentValue) == 'table' and type(newValue) == 'table' then
		-- Check if the value has the exact same keys
		-- otherwise warn about a possible benefit of using Replion:Update
		local currentValueKeys = Freeze.Dictionary.keys(currentValue)
		local newValueKeys = Freeze.Dictionary.keys(newValue)

		if Freeze.List.equals(currentValueKeys, newValueKeys) then
			local scriptName, line = debug.info(2, 'sl')
			local pathString = Utils.getPathString(path)
			local lineString = `{scriptName}:{line}`

			if not warnsSent[lineString] then
				warnsSent[lineString] = true

				local changedValues = Freeze.Dictionary.filter(newValue, function(value, key)
					return not Freeze.Dictionary.equals((currentValue :: any)[key], value)
				end)

				-- Check if all values have changed
				if Freeze.Dictionary.count(changedValues) ~= Freeze.Dictionary.count(newValue) then
					local formatedValue = ''
					for key, value in changedValues do
						formatedValue ..= `\n\t{key} = {value},`
					end

					warn(
						`Warning: Sending a table with identical keys but different values to the client.\n`
							.. `Consider using Replion:Update('{pathString}', \{{formatedValue}\n}) at {scriptName}:{line} for optimized updates.`
					)
				end
			end
		end
	end

	local newData = Freeze.Dictionary.setIn(self.Data, pathTable, newValue)
	local oldData = self.Data

	self.Data = newData

	Network.sendTo(self.ReplicateTo, 'Set', self._packedId, path, newValue)

	Graph.fireEvent(self._rootNode, 'onDataChange', '__root', newData, pathTable)
	Graph.fireChange(self._rootNode, pathTable, newData, oldData)

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
	If you want to remove a key, set it to `Replion.None`.

	You can update the root data by passing a table as the first argument.
]=]
function ServerReplion:Update(path, toUpdate)
	local pathTable = if toUpdate then Utils.getPathTable(path) else nil
	local pathCurrentValue = if pathTable then Freeze.Dictionary.getIn(self.Data, pathTable) else self.Data
	local targetTable = toUpdate or path :: _T.Dictionary

	local changedValues = Freeze.Dictionary.filter(targetTable, function(value, key)
		if not pathCurrentValue then
			return true
		end

		return not Freeze.Dictionary.equals(pathCurrentValue[key], value)
	end)

	local nothingChanged = next(changedValues) == nil
	if nothingChanged then
		return
	end

	local oldData = self.Data
	local newData = if pathTable
		then Freeze.Dictionary.mergeIn(self.Data, pathTable, changedValues)
		else Freeze.Dictionary.merge(self.Data, changedValues)

	self.Data = newData

	Graph.fireEvent(self._rootNode, 'onDataChange', '__root', newData, pathTable)
	Graph.fireChange(self._rootNode, pathTable, newData, oldData)

	-- Fix unordered arrays
	local arraySize = table.maxn(changedValues)
	local isUnordered
	if arraySize > 0 then
		local size = 0

		for i in changedValues do
			size += 1

			if i ~= size then
				isUnordered = true

				break
			end
		end

		-- is an unordered array, transform into dictionary
		isUnordered = isUnordered or size ~= arraySize

		if _G.__DEV__ and isUnordered then
			local scriptName, line = debug.info(2, 'sl')
			local lineString = `{scriptName}:{line}`

			if not warnsSent[lineString] then
				warnsSent[lineString] = true

				warn(
					`Warning: You're trying to send an unordered array to the client, RemotesEvents can't send unordered arrays.\n`
						.. `The array will be transformed into a dictionary to be sent to the client.\n`
						.. `at {scriptName}:{line}`
				)
			end
		end
	end

	local serializedUpdate = Freeze.Dictionary.map(changedValues, function(value, key)
		return if value == Freeze.None then Utils.SerializedNone else value, if isUnordered then tostring(key) else key
	end)

	if not pathTable then
		Network.sendTo(self.ReplicateTo, 'Update', self._packedId, serializedUpdate, nil, isUnordered)
	else
		Network.sendTo(self.ReplicateTo, 'Update', self._packedId, path, serializedUpdate, isUnordered)
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

	local currentValue = self:GetExpect(path, `"{Utils.getPathString(path)}" is not a valid path!`)
	if amount == 0 then
		return currentValue
	end

	if _G.__DEV__ and type(currentValue) ~= 'number' then
		local scriptName, line = debug.info(2, 'sl')
		local lineString = `{scriptName}:{line}`

		if not warnsSent[lineString] then
			warnsSent[lineString] = true

			warn(
				`Warning: Attempt to increase non-numeric value at "{Utils.getPathString(path)}"\n`
					.. `Check if the path is correct at {scriptName}:{line}.`
			)
		end

		return currentValue
	end

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

	local array = self:GetExpect(path, `"{Utils.getPathString(path)}" is not a valid path!`)

	local targetIndex = if index then index else #array + 1
	local newArray = table.clone(array)
	table.insert(newArray, targetIndex, value)

	local oldData = self.Data
	local newData = Freeze.Dictionary.setIn(self.Data, pathTable, newArray)

	self.Data = newData

	Graph.fireEvent(self._rootNode, 'onDataChange', '__root', newData, pathTable)
	Graph.fireEvent(self._rootNode, 'onArrayInsert', pathTable, targetIndex, value)
	Graph.fireChange(self._rootNode, pathTable, newData, oldData)

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

	local array = self:GetExpect(path, `"{Utils.getPathString(path)}" is not a valid path!`)

	local targetIndex = if index then index else #array
	local value = array[targetIndex]

	local newArray = table.clone(array)
	table.remove(newArray, targetIndex)

	local oldData = self.Data
	local newData = Freeze.Dictionary.setIn(self.Data, pathTable, newArray)

	self.Data = newData

	Graph.fireEvent(self._rootNode, 'onDataChange', '__root', newData, pathTable)
	Graph.fireEvent(self._rootNode, 'onArrayRemove', path, targetIndex, value)
	Graph.fireChange(self._rootNode, pathTable, newData, oldData)

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
	if next(array) == nil then
		return
	end

	local pathTable = Utils.getPathTable(path)
	local oldData = self.Data
	local newData = Freeze.Dictionary.setIn(self.Data, pathTable, {})

	self.Data = newData

	Graph.fireEvent(self._rootNode, 'onDataChange', '__root', newData, pathTable)
	Graph.fireChange(self._rootNode, pathTable, newData, oldData)

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
	local coins: number? = Replion:Get('Coins')
	```

	@param path Path

	Returns the value at the given path.
]=]
function ServerReplion:Get<T>(path): T?
	assert(path, 'Path is required!')

	local pathTable = Utils.getPathTable(path)
	local value: T? = Freeze.Dictionary.getIn(self.Data, pathTable)

	if _G.__DEV__ and value == nil then
		for i, key in pathTable do
			if type(key) == 'string' then
				local trimmedString = Utils.trimString(key)

				if trimmedString == key then
					continue
				end

				local pathWithoutTrimmedString = Freeze.List.set(pathTable, i, trimmedString)
				local valueWithTrimmedString = Freeze.Dictionary.getIn(self.Data, pathWithoutTrimmedString)

				if valueWithTrimmedString then
					local scriptName, line = debug.info(2, 'sl')

					warn(
						`Warning: the path "{Utils.getPathString(path)}" has a key with leading or trailing whitespaces.\n`
							.. `This is likely a mistake, consider using "{Utils.getPathString(pathWithoutTrimmedString)}" at {scriptName}:{line} instead.`
					)
				end
			end
		end
	end

	return value
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

	self._beforeDestroy:Fire()
	self._beforeDestroy:DisconnectAll()

	self._replicateToChanged:Destroy()
	Graph.destroyRootNode(self._rootNode)

	self._rootNode = nil
	self.Destroyed = true

	Network.sendTo(self.ReplicateTo, 'Removed', self._packedId)

	table.insert(availableIds, self._id)
end

return ServerReplion
