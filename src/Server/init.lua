--!strict
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

local replionAdded = Signal.new()
local replionRemoved = Signal.new()

local replionsCache: _T.Cache<{ ServerReplion<any> }> = {}
local waitingList: _T.Cache<WaitList> = {}

local timeouts: { [thread]: thread } = {}

local function getCache<T>(cache: _T.Cache<T>, channel: string): T
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
			task.spawn(thread)
		end

		timeouts[thread] = nil

		break
	end
end

local function createTimeout(waitList: WaitList, timeout: number, thread: thread)
	return task.delay(timeout, cancelWait, waitList, thread)
end

--[=[
	@type ReplionConfig { Channel: string, Data: { [any]: any }, Tags: { string }?, ReplicateTo: ReplicateTo }
	@within Server
]=]

--[=[
	@class Server
	@server
]=]
local Server: ReplionServer = {} :: any

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

			if typeof(replicateTo) == 'Instance' then
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

	local newReplion: ServerReplion = ServerReplion.new(config)
	newReplion:BeforeDestroy(function()
		local index = table.find(channelCache, newReplion)
		if index then
			table.remove(channelCache, index)
		end

		if #channelCache == 0 then
			replionsCache[channel] = nil
		end

		replionRemoved:Fire(channel, newReplion)
	end)

	table.insert(channelCache, newReplion)

	replionAdded:Fire(channel, newReplion)

	local waitList = waitingList[channel]
	if waitList then
		for i = #waitList, 1, -1 do
			local info = waitList[i]

			local thread = info.thread
			local player = info.player

			local replicateTo = newReplion.ReplicateTo

			-- Need to make sure that the player is in the replicateTo list
			if player then
				local isReplicating = false
				if typeof(replicateTo) == 'Instance' then
					isReplicating = replicateTo == player
				elseif type(replicateTo) == 'table' then
					isReplicating = table.find(replicateTo, player) ~= nil
				end

				if not isReplicating then
					continue
				end
			end

			local timeoutThread: thread? = timeouts[thread]
			if timeoutThread then
				Utils.safeCancelThread(timeoutThread)

				timeouts[thread] = nil
			end

			task.spawn(thread, newReplion)

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
		#channelCache == 1,
		`There are multiple replions with the channel "{channel}". Did you mean to use GetReplionFor?`
	)

	return channelCache[1]
end

--[=[
	@param player Player
	@param channel string

	Returns the first Replion that matches the channel.
]=]
function Server:GetReplionFor<T>(player, channel): ServerReplion<T>?
	local channelCache = replionsCache[channel]
	if channelCache then
		for _, replion in channelCache do
			if replion.ReplicateTo == player and replion.Channel == channel then
				return replion :: any
			end
		end
	end

	return nil
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
function Server:WaitReplionFor<T>(player, channel, timeout): ServerReplion<T>?
	local replion = self:GetReplionFor(player, channel)
	if replion then
		return replion
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

	local function onPlayerAdded(player: Player)
		local replicatedToPlayer = Server:GetReplionsFor(player)
		local playerReplions = {}

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

	Players.PlayerRemoving:Connect(function(player: Player)
		for _, replions in replionsCache do
			for _, replion: any in replions do
				local replicateTo = replion.ReplicateTo
				if replicateTo == 'All' then
					continue
				end

				if type(replicateTo) == 'table' then
					local newReplicate = Freeze.List.removeValue(replicateTo, player)
					replion:SetReplicateTo(newReplicate)
				elseif replicateTo == player then
					replion:Destroy()
				end
			end
		end

		-- Clean up the waiting list for this player.
		for _, waitList in waitingList do
			for i = #waitList, 1, -1 do
				local info = waitList[i]

				local thread = info.thread
				local waitingPlayer = info.player

				if waitingPlayer == player then
					if info.async then
						Utils.safeCancelThread(thread)
					else
						task.spawn(thread)
					end

					timeouts[thread] = nil

					table.remove(waitList, i)
				end
			end
		end
	end)
end

return Server
