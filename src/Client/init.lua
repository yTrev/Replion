--!strict
local RunService = game:GetService('RunService')

local Utils = require(script.Parent.Internal.Utils)
local Signal = require(script.Parent.Parent.Signal)
local Network = require(script.Parent.Internal.Network)
local ClientReplion = require(script.ClientReplion)
local _T = require(script.Parent.Internal.Types)

export type ClientReplion<D = any> = ClientReplion.ClientReplion<D>
type SerializedReplion = _T.SerializedReplion
type SerializedReplions = { SerializedReplion }

export type ReplionClient = {
	OnReplionAdded: (self: ReplionClient, callback: (addedReplion: ClientReplion) -> ()) -> Signal.Connection,
	OnReplionAddedWithTag: (
		self: ReplionClient,
		tag: string,
		callback: (addedReplion: ClientReplion) -> ()
	) -> Signal.Connection,

	OnReplionRemoved: (self: ReplionClient, callback: (removedReplion: ClientReplion) -> ()) -> Signal.Connection,
	OnReplionRemovedWithTag: (
		self: ReplionClient,
		tag: string,
		callback: (addedReplion: ClientReplion) -> ()
	) -> Signal.Connection,

	GetReplion: (self: ReplionClient, channel: string) -> ClientReplion?,
	WaitReplion: (self: ReplionClient, channel: string) -> ClientReplion,
	AwaitReplion: (self: ReplionClient, channel: string, callback: (newReplion: ClientReplion) -> ()) -> (),
}

local cache: { [string]: ClientReplion? } = {}
local waitingList: { [string]: { thread } } = {}

local addedSignal = Signal.new()
local removedSignal = Signal.new()

local function getWaitList(channel: string)
	local list = waitingList[channel]
	if not list then
		list = {}
		waitingList[channel] = list
	end

	return list
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
		for _, thread in waitList do
			task.spawn(thread, newReplion)
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
	@return RBXScriptConnection

	Calls the callback when a replion is added.
]=]
function Client:OnReplionAdded(callback): Signal.Connection
	return addedSignal:Connect(callback)
end

--[=[
	@return RBXScriptConnection

	Calls the callback when a replion is removed.
]=]
function Client:OnReplionRemoved(callback): Signal.Connection
	return removedSignal:Connect(callback)
end

--[=[
	@return RBXScriptConnection

	Calls the callback when a replion with the given tag is added.
]=]
function Client:OnReplionAddedWithTag(tag, callback): Signal.Connection
	return self:OnReplionAdded(function(replion: ClientReplion)
		local tags: { string }? = replion.Tags

		if tags and table.find(tags, tag) ~= nil then
			callback(replion)
		end
	end)
end

--[=[
	@return RBXScriptConnection

	Calls the callback when a replion with the given tag is removed.
]=]
function Client:OnReplionRemovedWithTag(tag, callback): Signal.Connection
	return self:OnReplionRemoved(function(replion: ClientReplion)
		local tags: { string }? = replion.Tags

		if tags and table.find(tags, tag) ~= nil then
			callback(replion)
		end
	end)
end

--[=[
	Returns the replion with the given channel.
]=]
function Client:GetReplion(channel): ClientReplion?
	return cache[channel]
end

--[=[
	@yields

	Yields until the replion with the given channel is added.
]=]
function Client:WaitReplion(channel): ClientReplion
	local replion = cache[channel]
	if replion then
		return replion
	end

	local waitList = getWaitList(channel)
	local thread = coroutine.running()

	table.insert(waitList, thread)

	return coroutine.yield()
end

--[=[
	This function will call the callback when a replion with the channel is created.
]=]
function Client:AwaitReplion(channel, callback)
	local replion = cache[channel]
	if replion then
		return callback(replion)
	end

	local waitList = getWaitList(channel)
	local newThread = coroutine.create(callback)

	table.insert(waitList, newThread)
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

	updateRemote.OnClientEvent:Connect(function(id: string, path: _T.Path | _T.Dictionary, toUpdate: _T.Dictionary?)
		local replion = cache[id]

		if replion then
			replion:_update(path, toUpdate)
		end
	end)

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
