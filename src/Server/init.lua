--!strict
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')

local Network = require(script.Parent.Internal.Network)
local ServerReplion = require(script.ServerReplion)

local Signal = require(script.Parent.Parent.Signal)
local _T = require(script.Parent.Internal.Types)

export type ServerReplion = ServerReplion.ServerReplion
type ReplionConfig = ServerReplion.ReplionConfig
type Connection = _T.Connection

type WaitList = { { thread: thread, player: Player?, async: boolean? } }
type Cache<T> = { [string]: T }

export type ReplionServer = {
	new: (config: ReplionConfig) -> ServerReplion,

	GetReplion: (self: ReplionServer, channel: string) -> ServerReplion?,

	OnReplionAdded: (
		self: ReplionServer,
		callback: (channel: string, newReplion: ServerReplion) -> ()
	) -> Connection,

	OnReplionRemoved: (
		self: ReplionServer,
		callback: (channel: string, newReplion: ServerReplion) -> ()
	) -> Connection,

	WaitReplion: (self: ReplionServer, channel: string, timeout: number?) -> ServerReplion?,
	AwaitReplion: (self: ReplionServer, channel: string, callback: (ServerReplion) -> (), timeout: number?) -> (),

	GetReplionsFor: (self: ReplionServer, player: Player) -> { ServerReplion },
	GetReplionFor: (self: ReplionServer, player: Player, channel: string) -> ServerReplion?,
	WaitReplionFor: (self: ReplionServer, player: Player, channel: string, timeout: number?) -> ServerReplion?,
	AwaitReplionFor: (
		self: ReplionServer,
		player: Player,
		channel: string,
		callback: (ServerReplion) -> (),
		timeout: number?
	) -> (),
}

local replionAdded = Signal.new()
local replionRemoved = Signal.new()

local replionsCache: Cache<{ ServerReplion }> = {}
local waitingList: Cache<WaitList> = {}

local timeouts: { [thread]: thread } = {}

local function getCache<T>(cache: Cache<T>, channel: string): T
	local channelCache = cache[channel]

	if not channelCache then
		channelCache = {} :: any
		cache[channel] = channelCache
	end

	return channelCache
end

local function createTimeout(waitList: WaitList, timeout: number, thread: thread)
	return task.delay(timeout, function()
		for index, info in waitList do
			if info.thread == thread then
				table.remove(waitList, index)

				-- if is an await function, just cancel it
				if info.async then
					task.cancel(thread)
				else
					task.spawn(thread)
				end

				timeouts[thread] = nil

				break
			end
		end
	end)
end

--[=[
	@type Channel string
	@within Server
]=]

--[=[
	@type ReplionConfig {Channel: string, Data: {[any]: any}, Tags: {string}?, Extensions: ModuleScript?}
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
function Server.new(config: ReplionConfig): ServerReplion
	local channel: string = assert(config.Channel, '[Replion] - Channel is required!')

	-- Check if a Replion with the same Channel and ReplicateTo is already created.
	local channelCache = getCache(replionsCache, channel)
	local newReplicateTo = config.ReplicateTo

	for _, replion in channelCache do
		local replicateTo = replion._replicateTo
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

			error(string.format('[Replion] - Channel %q already exists! for %q', channel, replicatingTo))
		end
	end

	local newReplion: ServerReplion = ServerReplion.new(config)
	newReplion:BeforeDestroy(function()
		local index: number? = table.find(channelCache, newReplion)
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

			local replicateTo = newReplion._replicateTo

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
				task.cancel(timeoutThread)

				timeouts[thread] = nil
			end

			task.spawn(thread, newReplion)

			table.remove(waitList, i)
		end
	end

	return newReplion
end

--[=[
	Gets a Replion with the given channel. If multiple Replions exist with the same channel, it will throw an error.
]=]
function Server:GetReplion(channel: string): ServerReplion?
	local channelCache = replionsCache[channel]
	if not channelCache then
		return nil
	end

	assert(
		#channelCache == 1,
		'[Replion] - There are multiple replions with the channel "'
			.. tostring(channel)
			.. '". Did you mean to use GetReplionFor?'
	)

	return channelCache[1]
end

--[=[
	Returns the first Replion that matches the channel.
]=]
function Server:GetReplionFor(player: Player, channel: string): ServerReplion?
	local channelCache = replionsCache[channel]
	if channelCache then
		for _, replion in channelCache do
			if replion._replicateTo == player and replion.Channel == channel then
				return replion :: any
			end
		end
	end

	return nil
end

--[=[
	Returns all replions for the given player. Includes replions that are replicated to "All".
]=]
function Server:GetReplionsFor(player: Player): { ServerReplion }
	local playerReplions: { ServerReplion } = {}

	for _, replions in replionsCache do
		for _, replion in replions do
			local replicateTo = replion._replicateTo

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
	@yields

	Wait for a replion with the given channel to be created.
]=]
function Server:WaitReplion(channel: string, timeout: number?): ServerReplion?
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
	@yields

	Wait for a replion to be created for the player.
]=]
function Server:WaitReplionFor(player: Player, channel: string, timeout: number?): ServerReplion?
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
	The callback will be called when the replion with the given id is added.
]=]
function Server:AwaitReplion(channel: string, callback: (ServerReplion) -> (), timeout: number?)
	local replion = self:GetReplion(channel)
	if replion then
		return callback(replion)
	end

	local waitList = getCache(waitingList, channel)
	local newThread = coroutine.create(callback)

	if timeout then
		timeouts[newThread] = createTimeout(waitList, timeout, newThread)
	end

	table.insert(waitList, { thread = newThread, async = true })
end

--[=[
	The callback will be called when the replion with the given id for the given player is added.
]=]
function Server:AwaitReplionFor(player: Player, channel: string, callback: (ServerReplion) -> (), timeout: number?)
	local replion = self:GetReplionFor(player, channel)
	if replion then
		return callback(replion)
	end

	local waitList = getCache(waitingList, channel)
	local newThread = coroutine.create(callback)

	if timeout then
		timeouts[newThread] = createTimeout(waitList, timeout, newThread)
	end

	table.insert(waitList, { thread = newThread, player = player, async = true })
end

--[=[
	@return RBXScriptConnection

	The callback will be called when a replion is added.
]=]
function Server:OnReplionAdded(callback: (channel: string, newReplion: ServerReplion) -> ()): Connection
	return replionAdded:Connect(callback)
end

--[=[
	@return RBXScriptConnection

	The callback will be called when a replion is removed.
]=]
function Server:OnReplionRemoved(callback: (channel: string, newReplion: ServerReplion) -> ()): Connection
	return replionRemoved:Connect(callback)
end

-- Setup remotes, if we are the server.
if RunService:IsServer() then
	Network.create({
		'Added',
		'Removed',
		'Update',

		'Set',
		'RunExtension',

		'ArrayUpdate',
	})

	Players.PlayerAdded:Connect(function(player: Player)
		local replicatedToPlayer = Server:GetReplionsFor(player)
		local playerReplions = {}

		for _, replion: any in replicatedToPlayer do
			table.insert(playerReplions, replion:_serialize())
		end

		if #playerReplions > 0 then
			Network.sendTo(player, 'Added', playerReplions)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		for _, replions in replionsCache do
			for _, replion: any in replions do
				local replicateTo = replion._replicateTo
				if replicateTo == 'All' then
					continue
				end

				if type(replicateTo) == 'table' then
					local index: number? = table.find(replicateTo, player)
					if index then
						table.remove(replicateTo, index)
					end
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
						task.cancel(thread)
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
