--!strict
local RunService = game:GetService('RunService')

local Signal = require(script.Parent.Parent.Signal)
local Network = require(script.Parent.Internal.Network)
local ClientReplion = require(script.ClientReplion)
local _T = require(script.Parent.Internal.Types)

export type ClientReplion = ClientReplion.ClientReplion
type SerializedReplion = _T.SerializedReplion
type SerializedReplions = { SerializedReplion }

export type ReplionClient = {
	OnReplionAdded: (self: ReplionClient, callback: (addedReplion: ClientReplion) -> ()) -> _T.Connection,
	OnReplionAddedWithTag: (
		self: ReplionClient,
		tag: string,
		callback: (addedReplion: ClientReplion) -> ()
	) -> _T.Connection,

	OnReplionRemoved: (self: ReplionClient, callback: (removedReplion: ClientReplion) -> ()) -> _T.Connection,
	OnReplionRemovedWithTag: (
		self: ReplionClient,
		tag: string,
		callback: (addedReplion: ClientReplion) -> ()
	) -> _T.Connection,

	GetReplion: (self: ReplionClient, channel: string) -> ClientReplion?,
	WaitReplion: (self: ReplionClient, channel: string) -> ClientReplion,
	AwaitReplion: (self: ReplionClient, channel: string, callback: (newReplion: ClientReplion) -> ()) -> (),

	Start: () -> (),
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
function Client:OnReplionAdded(callback: (addedReplion: ClientReplion) -> ()): _T.Connection
	return addedSignal:Connect(callback :: any)
end

--[=[
	@return RBXScriptConnection

	Calls the callback when a replion is removed.
]=]
function Client:OnReplionRemoved(callback: (removedReplion: ClientReplion) -> ()): _T.Connection
	return removedSignal:Connect(callback :: any)
end

--[=[
	@return RBXScriptConnection

	Calls the callback when a replion with the given tag is added.
]=]
function Client:OnReplionAddedWithTag(tag: string, callback: (ClientReplion) -> ()): _T.Connection
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
function Client:OnReplionRemovedWithTag(tag: string, callback: (ClientReplion) -> ()): _T.Connection
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
function Client:GetReplion(channel: string): ClientReplion?
	return cache[channel]
end

--[=[
	@yields

	Yields until the replion with the given channel is added.
]=]
function Client:WaitReplion(channel: string): ClientReplion
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
function Client:AwaitReplion(channel: string, callback: (newReplion: ClientReplion) -> ())
	local replion = cache[channel]
	if replion then
		return callback(replion)
	end

	local waitList = getWaitList(channel)
	local newThread = coroutine.create(callback)

	table.insert(waitList, newThread)
end

if RunService:IsClient() then
	local addedRemote = Network.get('Added')
	local removedRemote = Network.get('Removed')
	local updateRemote = Network.get('Update')
	local setRemote = Network.get('Set')
	local runExtension = Network.get('RunExtension')
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
			replion:Update(path, toUpdate)
		end
	end)

	setRemote.OnClientEvent:Connect(function(id: string, path: _T.Path, newValue: any)
		local replion = cache[id]

		if replion then
			replion:Set(path, newValue)
		end
	end)

	runExtension.OnClientEvent:Connect(function(id: string, extensionName: string, ...: any)
		local replion = cache[id]
		if replion then
			replion:Execute(extensionName, ...)
		end
	end)

	arrayUpdate.OnClientEvent:Connect(function(id: string, action: string, ...: any)
		local replion = cache[id]
		if replion then
			if action == 'i' then
				replion:Insert(...)
			elseif action == 'r' then
				replion:Remove(...)
			elseif action == 'c' then
				replion:Clear(...)
			end
		end
	end)
end

table.freeze(Client)

return Client
