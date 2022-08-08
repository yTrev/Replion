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

type Channel = string
type WaitList = { { thread: thread, player: Player?, async: boolean? } }

export type ReplionServer = {
	new: (config: ReplionConfig) -> (ServerReplion),

	GetReplion: (self: ReplionServer, channel: Channel) -> (ServerReplion?),

	OnReplionAdded: (
		self: ReplionServer,
		callback: (channel: Channel, newReplion: ServerReplion) -> ()
	) -> (Connection),

	OnReplionRemoved: (
		self: ReplionServer,
		callback: (channel: Channel, newReplion: ServerReplion) -> ()
	) -> (Connection),

	WaitReplion: (self: ReplionServer, channel: Channel, timeout: number?) -> (ServerReplion?),
	AwaitReplion: (self: ReplionServer, channel: Channel, callback: (ServerReplion) -> (), timeout: number?) -> (),

	GetReplionsFor: (self: ReplionServer, player: Player) -> ({ ServerReplion }),
	GetReplionFor: (self: ReplionServer, player: Player, channel: Channel) -> (ServerReplion?),
	WaitReplionFor: (self: ReplionServer, player: Player, channel: Channel, timeout: number?) -> (ServerReplion?),
	AwaitReplionFor: (
		self: ReplionServer,
		player: Player,
		channel: Channel,
		callback: (ServerReplion) -> (),
		timeout: number?
	) -> (),
}

local replionAdded = Signal.new()
local replionRemoved = Signal.new()

local cache: { [Channel]: { ServerReplion } } = {}

local waitingList: { [Channel]: WaitList } = {}
local timeouts: { [thread]: thread } = {}

local function getChannelCache(channel: Channel)
	local channelCache = cache[channel]
	if channelCache == nil then
		channelCache = {} :: any
		cache[channel] = channelCache
	end

	return channelCache
end

local function getWaitList(channel: Channel): WaitList
	local waitList: WaitList? = waitingList[channel]
	if not waitList then
		waitList = {} :: any
		waitingList[channel] = waitList
	end

	return waitList :: WaitList
end

local function createTimeout(waitList, timeout: number, thread: thread)
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
	local channel: Channel = assert(config.Channel, '[Replion] - Channel is required!')

	-- Check if a Replion with the same Channel and ReplicateTo is already created.
	local channelCache = getChannelCache(channel)
	for _, replion in channelCache do
		local isEqual: boolean = replion._replicateTo == config.ReplicateTo

		if not isEqual then
			for _, player in config.ReplicateTo :: { Player } do
				isEqual = table.find(replion._replicateTo :: { Player }, player) ~= nil

				if isEqual then
					break
				end
			end
		end

		assert(
			not isEqual,
			string.format(
				'[Replion] - Channel %q already exists! for %q',
				channel,
				if type(config.ReplicateTo) == 'table'
					then table.concat(config.ReplicateTo, ', ')
					else tostring(config.ReplicateTo)
			)
		)
	end

	local newReplion: ServerReplion = ServerReplion.new(config)
	newReplion:BeforeDestroy(function()
		local index: number? = table.find(channelCache, newReplion)
		if index then
			table.remove(channelCache, index)
		end

		if #channelCache == 0 then
			cache[channel] = nil
		end

		replionRemoved:Fire(channel, newReplion)
	end)

	table.insert(channelCache, newReplion)

	replionAdded:Fire(channel, newReplion)

	local waitList = waitingList[channel]
	if waitList then
		for index, info in waitList do
			local thread = info.thread
			local player = info.player

			local replicateTo = newReplion._replicateTo
			if player and type(replicateTo) == 'table' and not table.find(replicateTo, player) then
				continue
			end

			local timeoutThread: thread? = timeouts[thread]
			if timeoutThread then
				task.cancel(timeoutThread)

				timeouts[thread] = nil
			end

			task.spawn(thread, newReplion)

			table.remove(waitList, index)
		end
	end

	return newReplion
end

--[=[
	Gets a Replion with the given channel. If multiple Replions exist with the same channel, it will throw an error.
]=]
function Server:GetReplion(channel: Channel): ServerReplion?
	local channelCache = cache[channel]
	if channelCache == nil then
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
function Server:GetReplionFor(player: Player, channel: Channel): ServerReplion?
	local channelCache = cache[channel]
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

	for _, replions in cache do
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
function Server:WaitReplion(channel: Channel, timeout: number?): ServerReplion?
	local replion = self:GetReplion(channel)
	if replion then
		return replion
	end

	local thread: thread = coroutine.running()
	local waitList = getWaitList(channel)

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
function Server:WaitReplionFor(player: Player, channel: Channel, timeout: number?): ServerReplion?
	local replion = self:GetReplionFor(player, channel)
	if replion then
		return replion
	end

	local thread: thread = coroutine.running()
	local waitList = getWaitList(channel)

	if timeout then
		timeouts[thread] = createTimeout(waitList, timeout, thread)
	end

	table.insert(waitList, { thread = thread, player = player })

	return coroutine.yield()
end

--[=[
	The callback will be called when the replion with the given id is added.
]=]
function Server:AwaitReplion(channel: Channel, callback: (ServerReplion) -> (), timeout: number?)
	local waitList = getWaitList(channel)
	local newThread = coroutine.create(callback)

	if timeout then
		timeouts[newThread] = createTimeout(waitList, timeout, newThread)
	end

	table.insert(waitList, { thread = newThread, async = true })
end

--[=[
	The callback will be called when the replion with the given id for the given player is added.
]=]
function Server:AwaitReplionFor(player: Player, channel: Channel, callback: (ServerReplion) -> (), timeout: number?)
	local waitList = getWaitList(channel)
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
function Server:OnReplionAdded(callback: (channel: Channel, newReplion: ServerReplion) -> ()): Connection
	return replionAdded:Connect(callback)
end

--[=[
	@return RBXScriptConnection

	The callback will be called when a replion is removed.
]=]
function Server:OnReplionRemoved(callback: (channel: Channel, newReplion: ServerReplion) -> ()): Connection
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
		for _, replions in cache do
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
	end)
end

return Server
