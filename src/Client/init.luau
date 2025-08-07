local RunService = game:GetService('RunService')

local Utils = require(script.Parent.Internal.Utils)
local Signal = require(script.Parent.Parent.Signal)
local Network = require(script.Parent.Internal.Network)
local ClientReplion = require(script.ClientReplion)
local _T = require(script.Parent.Internal.Types)

export type ClientReplion<D = any> = ClientReplion.ClientReplion<D>
type SerializedReplion = _T.SerializedReplion
type SerializedReplions = { SerializedReplion }
type WaitList = { { thread: thread, async: boolean? } }

export type ReplionClient = {
	OnReplionAdded: (self: ReplionClient, callback: (ClientReplion) -> ()) -> Signal.Connection,
	OnReplionAddedWithTag: (
		self: ReplionClient,
		tag: string,
		callback: (replion: ClientReplion) -> ()
	) -> Signal.Connection,

	OnReplionRemoved: (self: ReplionClient, callback: (replion: ClientReplion) -> ()) -> Signal.Connection,
	OnReplionRemovedWithTag: (
		self: ReplionClient,
		tag: string,
		callback: (replion: ClientReplion) -> ()
	) -> Signal.Connection,

	GetReplion: (self: ReplionClient, channel: string) -> ClientReplion?,
	WaitReplion: (self: ReplionClient, channel: string, timeout: number?) -> ClientReplion,
	AwaitReplion: (
		self: ReplionClient,
		channel: string,
		callback: (replion: ClientReplion) -> (),
		timeout: number?
	) -> (() -> ())?,
}

local cache: { [string]: ClientReplion? } = {}
local waitingList: { [string]: WaitList? } = {}

local timeouts: { [thread]: thread } = {}

local addedSignal = Signal.new()
local removedSignal = Signal.new()

local function getWaitList(channel: string)
	local list = waitingList[channel]
	if not list then
		list = {}
		waitingList[channel] = list
	end

	return assert(list, 'Invalid wait list')
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

local function createReplion(serializedReplion: SerializedReplion)
	local channel = serializedReplion[2]
	if cache[channel] then
		return
	end

	local newReplion = ClientReplion.new(serializedReplion)

	cache[channel] = newReplion
	cache[serializedReplion[1]] = newReplion

	addedSignal:Fire(newReplion)

	local waitList = waitingList[channel]
	if waitList then
		for _, info in waitList do
			if coroutine.status(info.thread) == 'suspended' then
				task.spawn(info.thread, newReplion)
			end
		end

		waitingList[channel] = nil
	end
end

--[=[
	@class Client
	
	@client
]=]
local Client: ReplionClient = {} :: any

--[=[
	@param callback (addedReplion: ClientReplion) -> ()

	@return RBXScriptConnection

	Calls the callback when a replion is added.
]=]
function Client:OnReplionAdded(callback)
	return addedSignal:Connect(callback)
end

--[=[
	@param callback (replion: ClientReplion) -> ()

	@return RBXScriptConnection

	Calls the callback when a replion is removed.
]=]
function Client:OnReplionRemoved(callback)
	return removedSignal:Connect(callback)
end

--[=[
	@param tag string
	@param callback (replion: ClientReplion) -> ()

	@return RBXScriptConnection

	Calls the callback when a replion with the given tag is added.
]=]
function Client:OnReplionAddedWithTag(tag, callback)
	return self:OnReplionAdded(function(replion: ClientReplion)
		local tags: { string }? = replion.Tags

		if tags and table.find(tags, tag) ~= nil then
			callback(replion)
		end
	end)
end

--[=[
	@param tag string
	@param callback (replion: ClientReplion) -> ()

	@return RBXScriptConnection

	Calls the callback when a replion with the given tag is removed.
]=]
function Client:OnReplionRemovedWithTag(tag, callback)
	return self:OnReplionRemoved(function(replion: ClientReplion)
		local tags: { string }? = replion.Tags

		if tags and table.find(tags, tag) ~= nil then
			callback(replion)
		end
	end)
end

--[=[
	@param channel string

	Returns the replion with the given channel.
]=]
function Client:GetReplion(channel)
	return cache[channel]
end

--[=[
	@param channel string
	@param timeout number?

	@yields

	Yields until the replion with the given channel is added.
]=]
function Client:WaitReplion(channel, timeout)
	local replion = cache[channel]
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
	@param channel string
	@param callback (replion: ClientReplion) -> ()
	@param timeout number?

	@return (() -> ())?

	This function will call the callback when a replion with the channel is created.
	Returns a function that can be called to cancel the wait.
]=]
function Client:AwaitReplion(channel, callback, timeout)
	local replion = cache[channel]
	if replion then
		return callback(replion)
	end

	local waitList = getWaitList(channel)
	local newThread = coroutine.create(callback)

	if timeout then
		timeouts[newThread] = createTimeout(waitList, timeout, newThread)
	end

	table.insert(waitList, { thread = newThread, async = true })

	return function()
		cancelWait(waitList, newThread)
	end
end

if not Utils.ShouldMock and RunService:IsClient() then
	local addedRemote = Network.get('Added')
	local removedRemote = Network.get('Removed')
	local updateRemote = Network.get('Update')
	local setRemote = Network.get('Set')
	local updateReplicateTo = Network.get('UpdateReplicateTo')
	local arrayUpdate = Network.get('ArrayUpdate')

	addedRemote.OnClientEvent:Connect(function(serializedReplions: any)
		if type(serializedReplions[1]) == 'table' then
			for _, serializedReplion in serializedReplions do
				createReplion(serializedReplion)
			end
		else
			createReplion(serializedReplions)
		end
	end)

	removedRemote.OnClientEvent:Connect(function(id: string)
		local replion = cache[id]
		if replion then
			cache[id] = nil
			cache[replion._channel] = nil

			removedSignal:Fire(replion)

			replion:Destroy()
		end
	end)

	updateRemote.OnClientEvent:Connect(
		function(id: string, path: _T.Path | _T.Dictionary, toUpdate: _T.Dictionary?, isUnoredered: boolean?)
			local replion = cache[id]

			if replion then
				replion:_update(path, toUpdate, isUnoredered)
			end
		end
	)

	updateReplicateTo.OnClientEvent:Connect(function(id: string, replicateTo: _T.ReplicateTo)
		local replion = cache[id]

		if replion then
			replion.ReplicateTo = replicateTo
		end
	end)

	setRemote.OnClientEvent:Connect(function(id: string, path: _T.Path, newValue: any)
		local replion = cache[id]

		if replion then
			replion:_set(path, newValue)
		end
	end)

	arrayUpdate.OnClientEvent:Connect(function(id: string, action: string, ...: any)
		local replion = cache[id]
		if replion then
			if action == 'i' then
				replion:_insert(...)
			elseif action == 'r' then
				replion:_remove(...)
			elseif action == 'c' then
				replion:_clear(...)
			end
		end
	end)
end

return table.freeze(Client)
