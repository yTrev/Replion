--!strict
local Signal = require(script.Parent.Parent.Signal)
local Network = require(script.Parent.Internal.Network)
local ClientReplion = require(script.ClientReplion)
local _T = require(script.Parent.Internal.Types)

export type ClientReplion = ClientReplion.ClientReplion
type SerializedReplion = _T.SerializedReplion
type SerializedReplions = { SerializedReplion }

local cache: { [string]: ClientReplion? } = {}

local waitingList: { [string]: { thread } } = {}

local addedSignal = Signal.new()
local removedSignal = Signal.new()

local addedRemote = Network.get('Added') :: RemoteEvent
local removedRemote = Network.get('Removed') :: RemoteEvent
local updateRemote = Network.get('Update') :: RemoteEvent
local setRemote = Network.get('Set') :: RemoteEvent
local runExtension = Network.get('RunExtension') :: RemoteEvent
local arrayUpdate = Network.get('ArrayUpdate') :: RemoteEvent

local function getWaitList(channel: string)
	local list = waitingList[channel]
	if not list then
		list = {}
		waitingList[channel] = list
	end

	return list
end

local function createReplion(serializedReplion: SerializedReplion)
	local channel = serializedReplion.Channel
	if cache[channel] then
		return
	end

	local newReplion = ClientReplion.new(serializedReplion)

	cache[channel] = newReplion
	cache[newReplion._id] = newReplion

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
local Client = {}

--[=[
	The callback will be called when a replion is added.
]=]
function Client:OnReplionAdded(callback: (addedReplion: ClientReplion) -> ()): _T.Connection
	return addedSignal:Connect(callback :: any)
end

--[=[
	The callback will be called when a replion is removed.
]=]
function Client:OnReplionRemoved(callback: (removedReplion: ClientReplion) -> ()): _T.Connection
	return removedSignal:Connect(callback :: any)
end

--[=[
	This function will return the replion that is associated with the channel.
]=]
function Client:GetReplion(channel: string): ClientReplion?
	return cache[channel]
end

--[=[
	This function will yield the current thread until a replion with the channel is created.
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

function Client.Start()
	addedRemote.OnClientEvent:Connect(function(serializedReplions: SerializedReplion | SerializedReplions)
		if #serializedReplions > 0 then
			for _, serializedReplion in serializedReplions :: SerializedReplions do
				createReplion(serializedReplion)
			end
		elseif next(serializedReplions) then
			createReplion(serializedReplions :: SerializedReplion)
		end
	end)

	removedRemote.OnClientEvent:Connect(function(id: string)
		local replion = cache[id]
		if replion then
			removedSignal:Fire(replion)

			replion:Destroy()

			cache[id] = nil
			cache[replion._channel] = nil
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
