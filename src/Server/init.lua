local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

local Freeze = require(script.Parent.Parent.Freeze)
local Utils = require(script.Parent.Internal.Utils)
local Network = require(script.Parent.Internal.Network)
local ServerReplion = require(script.ServerReplion)

local Signal = require(script.Parent.Parent.Signal)
local _T = require(script.Parent.Internal.Types)

export type ServerReplion<D = any> = ServerReplion.ServerReplion<D>
type ReplionConfig<T> = ServerReplion.ReplionConfig<T>

type WaitList = { { thread: thread, player: Player?, async: boolean? } }

export type ReplionServer = {
	new: <T>(config: ReplionConfig<T>) -> ServerReplion<T>,

	GetReplion: <T>(self: ReplionServer, channel: string) -> ServerReplion<T>?,

	WaitReplion: <T>(self: ReplionServer, channel: string, timeout: number?) -> ServerReplion<T>?,
	AwaitReplion: <T>(
		self: ReplionServer,
		channel: string,
		callback: (ServerReplion<T>) -> (),
		timeout: number?
	) -> (() -> ())?,

	GetReplionsFor: (self: ReplionServer, player: Player) -> { ServerReplion },
	GetReplionFor: <T>(self: ReplionServer, player: Player, channel: string) -> ServerReplion<T>?,
	WaitReplionFor: <T>(self: ReplionServer, player: Player, channel: string, timeout: number?) -> ServerReplion<T>?,
	AwaitReplionFor: <T>(
		self: ReplionServer,
		player: Player,
		channel: string,
		callback: (ServerReplion<T>) -> (),
		timeout: number?
	) -> (() -> ())?,

	OnReplionAdded: <T>(
		self: ReplionServer,
		callback: (channel: string, replion: ServerReplion<T>) -> ()
	) -> Signal.Connection,

	OnReplionRemoved: <T>(
		self: ReplionServer,
		callback: (channel: string, replion: ServerReplion<T>) -> ()
	) -> Signal.Connection,
}

local replionAdded: Signal.Signal<string, ServerReplion> = Signal.new()
local replionRemoved: Signal.Signal<string, ServerReplion> = Signal.new()

local replionsCache: { [string]: { [number]: ServerReplion } } = {}
local waitingList: { [string]: WaitList } = {}
local playersReplionsIndex: { [Player]: { [string]: number } } = {}

local timeouts: { [thread]: thread } = {}

local function getCache<T>(cache: { [any]: T }, channel: any): T
	local channelCache = cache[channel]

	if not channelCache then
		channelCache = {} :: any
		cache[channel] = channelCache
	end

	return channelCache
end

local function cancelWait(waitList: WaitList, thread: thread)
	for index, info in waitList do
		if info.thread ~= thread then
			continue
		end

		table.remove(waitList, index)

		-- if is an await function, just cancel it
		if info.async then
			Utils.safeCancelThread(thread)
		else
			pcall(task.spawn, thread)
		end

		timeouts[thread] = nil

		break
	end
end

local function createTimeout(waitList: WaitList, timeout: number, thread: thread)
	return task.delay(timeout, cancelWait, waitList, thread)
end

--[=[
	@type ReplionConfig { Channel: string, Data: { [any]: any }, Tags: { string }?, ReplicateTo: ReplicateTo, DisableAutoDestroy: boolean? }
	@within Server
]=]

--[=[
	@class Server
	@server
]=]
local Server: ReplionServer = {} :: ReplionServer

--[=[
	Creates a new Replion.
]=]
function Server.new<T>(config: ReplionConfig<T>): ServerReplion<T>
	local channel: string = assert(config.Channel, 'Channel is required!')

	-- Check if a Replion with the same Channel and ReplicateTo is already created.
	local channelCache = getCache(replionsCache, channel)
	local newReplicateTo = config.ReplicateTo

	for _, replion in channelCache do
		local replicateTo = replion.ReplicateTo
		local isEqual = replicateTo == newReplicateTo

		if not isEqual and type(replicateTo) == 'table' and type(newReplicateTo) == 'table' then
			for _, player in replicateTo do
				isEqual = table.find(newReplicateTo, player) ~= nil

				if isEqual then
					break
				end
			end
		end

		if isEqual then
			local replicatingTo: string

			if typeof(replicateTo) == 'Instance' or typeof(replicateTo) == 'userdata' then
				replicatingTo = tostring(replicateTo)
			elseif type(replicateTo) == 'string' then
				replicatingTo = replicateTo
			elseif type(replicateTo) == 'table' then
				for _, player in replicateTo do
					replicatingTo = (if replicatingTo then replicatingTo .. ', ' else '') .. tostring(player)
				end
			end

			error(`Channel "{channel}" already exists! for "{replicatingTo}"`)
		end
	end

	local newReplion: ServerReplion<T> = ServerReplion.new(config)
	newReplion:BeforeDestroy(function()
		channelCache[newReplion._id] = nil

		if not next(channelCache) then
			replionsCache[channel] = nil
		end

		replionRemoved:Fire(channel, newReplion)
		newReplion = nil :: any
	end)

	-- Because of the new optimizations we need to update the playersReplionsIndex
	-- when the replicateTo changes
	newReplion._replicateToChanged:Connect(function(replicateTo, oldReplicateTo)
		if typeof(oldReplicateTo) == 'Instance' and oldReplicateTo:IsA('Player') then
			local playerCache = playersReplionsIndex[oldReplicateTo]
			if playerCache then
				playerCache[channel] = nil
			end
		elseif typeof(oldReplicateTo) == 'table' then
			for _, player in oldReplicateTo do
				local playerCache = playersReplionsIndex[player]
				if not playerCache then
					continue
				end

				playerCache[channel] = nil
			end
		end

		if typeof(replicateTo) == 'Instance' and replicateTo:IsA('Player') then
			local playerCache = getCache(playersReplionsIndex, replicateTo)
			playerCache[channel] = newReplion._id
		elseif typeof(replicateTo) == 'table' then
			for _, player in replicateTo do
				local playerCache = getCache(playersReplionsIndex, player)
				playerCache[channel] = newReplion._id
			end
		end
	end)

	channelCache[newReplion._id] = newReplion
	replionAdded:Fire(channel, newReplion)

	-- In the future we can extend this to support other types of replication
	if typeof(newReplicateTo) == 'Instance' or (Utils.ShouldMock and typeof(newReplicateTo) == 'userdata') then
		local playerIndexes = getCache(playersReplionsIndex, newReplicateTo)
		playerIndexes[channel] = newReplion._id
	elseif type(newReplicateTo) == 'table' then
		for _, player in newReplicateTo do
			local playerIndexes = getCache(playersReplionsIndex, player)
			playerIndexes[channel] = newReplion._id
		end
	end

	local waitList = waitingList[channel]
	if waitList then
		for i = #waitList, 1, -1 do
			local info = waitList[i]

			local thread = info.thread
			local player = info.player

			-- Need to make sure that the player is in the replicateTo list
			if player then
				local isReplicating = false
				if typeof(newReplicateTo) == 'Instance' or typeof(newReplicateTo) == 'userdata' then
					isReplicating = newReplicateTo == player
				elseif type(newReplicateTo) == 'table' then
					isReplicating = table.find(newReplicateTo, player) ~= nil
				end

				if not isReplicating then
					continue
				end
			end

			local timeoutThread = timeouts[thread]
			if timeoutThread then
				Utils.safeCancelThread(timeoutThread)

				timeouts[thread] = nil
			end

			if coroutine.status(thread) == 'suspended' then
				task.spawn(thread, newReplion)
			end

			table.remove(waitList, i)
		end
	end

	return newReplion
end

--[=[
	@param channel string

	Gets a Replion with the given channel. If multiple Replions exist with the same channel, it will throw an error.
]=]
function Server:GetReplion<T>(channel: string): ServerReplion<T>?
	local channelCache = replionsCache[channel]
	if not channelCache then
		return nil
	end

	assert(
		Freeze.Dictionary.count(channelCache) == 1,
		`There are multiple replions with the channel "{channel}". Did you mean to use GetReplionFor?`
	)

	local _, replion = next(channelCache)
	return replion
end

--[=[
	@param player Player
	@param channel string

	Returns the first Replion that matches the channel.
]=]
function Server:GetReplionFor<T>(player, channel): ServerReplion<T>?
	local channelCache = replionsCache[channel]
	if not channelCache then
		return nil
	end

	local playerIndexes = playersReplionsIndex[player]
	if not playerIndexes then
		return nil
	end

	return channelCache[playerIndexes[channel]]
end

--[=[
	@param player Player

	Returns all replions for the given player. Includes replions that are replicated to "All".
]=]
function Server:GetReplionsFor(player)
	local playerReplions = {}

	for _, replions in replionsCache do
		for _, replion in replions do
			local replicateTo = replion.ReplicateTo

			local isReplicatingToPlayer: boolean = replicateTo == 'All'
			if not isReplicatingToPlayer then
				if type(replicateTo) == 'table' then
					isReplicatingToPlayer = table.find(replicateTo, player) ~= nil
				elseif replicateTo == player then
					isReplicatingToPlayer = true
				end
			end

			if isReplicatingToPlayer then
				table.insert(playerReplions, replion :: any)
			end
		end
	end

	return playerReplions
end

--[=[
	@param channel string
	@param timeout number?

	@yields

	Wait for a replion with the given channel to be created.
]=]
function Server:WaitReplion<T>(channel, timeout): ServerReplion<T>?
	local replion = self:GetReplion(channel)
	if replion then
		return replion
	end

	local thread: thread = coroutine.running()
	local waitList = getCache(waitingList, channel)

	if timeout then
		timeouts[thread] = createTimeout(waitList, timeout, thread)
	end

	table.insert(waitList, { thread = thread })

	return coroutine.yield()
end

--[=[
	@param player Player
	@param channel string
	@param timeout number?

	@yields

	Wait for a replion to be created for the player.
]=]
function Server:WaitReplionFor<T>(player: Player, channel: string, timeout: number?): ServerReplion<T>?
	local replion = self:GetReplionFor(player, channel)
	if replion then
		return replion
	end

	if typeof(player) == 'Instance' and not player:IsDescendantOf(Players) then
		if _G.__DEV__ then
			local scriptName, line = debug.info(2, 'sl')

			warn(`Warning: Trying to wait for a player that is not in the game at {scriptName}:{line}`)
		end

		return nil
	end

	local thread: thread = coroutine.running()
	local waitList = getCache(waitingList, channel)

	if timeout then
		timeouts[thread] = createTimeout(waitList, timeout, thread)
	end

	table.insert(waitList, { thread = thread, player = player })

	return coroutine.yield()
end

--[=[
	@param channel string
	@param callback (replion: ServerReplion) -> ()
	@param timeout number?

	@return (() -> ())?

	The callback will be called when the replion with the given id is added.
	Returns a function that can be called to cancel the wait.
]=]
function Server:AwaitReplion<T>(channel, callback, timeout)
	local replion: ServerReplion<T>? = self:GetReplion(channel)
	if replion then
		return callback(replion :: any)
	end

	local waitList = getCache(waitingList, channel)
	local newThread = coroutine.create(callback)

	if timeout then
		timeouts[newThread] = createTimeout(waitList, timeout, newThread)
	end

	table.insert(waitList, { thread = newThread, async = true })

	return function()
		cancelWait(waitList, newThread)
	end
end

--[=[
	@param player Player
	@param channel string
	@param callback (replion: ServerReplion) -> ()
	@param timeout number?

	@return (() -> ())?

	The callback will be called when the replion with the given id for the given player is added.
	Returns a function that can be called to cancel the wait.
]=]
function Server:AwaitReplionFor<T>(player, channel, callback, timeout)
	local replion: ServerReplion<T>? = self:GetReplionFor(player, channel)
	if replion then
		return callback(replion :: any)
	end

	if typeof(player) == 'Instance' and player.Parent == nil then
		if _G.__DEV__ then
			local scriptName, line = debug.info(2, 'sl')

			warn(`Warning: Trying to await for a player that is not in the game at {scriptName}:{line}`)
		end

		return nil
	end

	local waitList = getCache(waitingList, channel)
	local newThread = coroutine.create(callback)

	if timeout then
		timeouts[newThread] = createTimeout(waitList, timeout, newThread)
	end

	table.insert(waitList, { thread = newThread, player = player, async = true })

	return function()
		cancelWait(waitList, newThread)
	end
end

--[=[
	@param callback (channel: string, replion: ServerReplion) -> ()

	@return RBXScriptConnection

	The callback will be called when a replion is added.
]=]
function Server:OnReplionAdded<T>(callback)
	return replionAdded:Connect(callback)
end

--[=[
	@param callback (channel: string, replion: ServerReplion) -> ()

	@return RBXScriptConnection

	The callback will be called when a replion is removed.
]=]
function Server:OnReplionRemoved<T>(callback)
	return replionRemoved:Connect(callback)
end

-- Only setup the remotes if we are not mocking
if not Utils.ShouldMock and RunService:IsServer() then
	Network.create({
		'Added',
		'Removed',
		'Update',
		'UpdateReplicateTo',
		'Set',
		'ArrayUpdate',
	})

	local function onPlayerAdded(player)
		local replicatedToPlayer = Server:GetReplionsFor(player)
		local playerReplions: { { any } } = {}

		for _, replion in replicatedToPlayer do
			table.insert(playerReplions, (replion :: any):_serialize())
		end

		if #playerReplions > 0 then
			Network.sendTo(player, 'Added', playerReplions)
		end
	end

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		local aliveReplions = {}

		for _, replions in replionsCache do
			for _, replion: any in replions do
				local replicateTo = replion.ReplicateTo
				if replicateTo == 'All' then
					continue
				end

				if type(replicateTo) == 'table' then
					replion:SetReplicateTo(Freeze.List.removeValue(replicateTo, player))
				elseif replicateTo == player then
					if not replion.DisableAutoDestroy then
						replion:Destroy()

						continue
					end

					replion:BeforeDestroy(function()
						local index = table.find(aliveReplions, replion)
						if not index then
							return
						end

						table.remove(aliveReplions, index)

						if #aliveReplions == 0 then
							playersReplionsIndex[player] = nil
						end
					end)

					table.insert(aliveReplions, replion)
				end
			end
		end

		-- Clean up players replions index
		if #aliveReplions == 0 then
			playersReplionsIndex[player] = nil
		end

		-- Clean up the waiting list for this player.
		for index, waitList in waitingList do
			for i = #waitList, 1, -1 do
				local info = waitList[i]

				local thread = info.thread
				local waitingPlayer = info.player

				if waitingPlayer == player then
					if info.async then
						Utils.safeCancelThread(thread)
					else
						pcall(task.spawn, thread)
					end

					timeouts[thread] = nil

					table.remove(waitList, i)
				end
			end

			if #waitList == 0 then
				waitingList[index] = nil
			end
		end
	end)
end

return Server
