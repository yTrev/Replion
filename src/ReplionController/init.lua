--!strict
-- ===========================================================================
-- Services
-- ===========================================================================
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- ===========================================================================
-- Modules
-- ===========================================================================
local Replion = script.Parent

local Promise = require(Replion.Parent.Promise)
local t = require(Replion.Parent.t)
local Signal = require(Replion.Parent.Signal)

local Types = require(Replion.Shared.Types)
local Enums = require(Replion.Shared.Enums)

local ClientReplion = require(script.ClientReplion)
local ClientMethods = require(script.ClientMethods)

-- ===========================================================================
-- Variables
-- ===========================================================================
type ClientReplion = ClientReplion.ClientReplion

local eventsFolder: Folder = ReplicatedStorage:FindFirstChild('ReplionNetwork') :: Folder

local replions: { [string]: ClientReplion? } = {}
local starting: boolean = false
local statedCompleted: boolean = false

local onStart: BindableEvent = Instance.new('BindableEvent')
local replionAdded: Types.Signal = Signal.new()
local replionRemoved: Types.Signal = Signal.new()

-- ===========================================================================
-- Private functions
-- ===========================================================================
local function createReplion(name: string, data: Types.Table, tags: Types.StringArray)
	if replions[name] then
		return
	end

	local newReplion = ClientReplion.new(data, tags)
	replions[name] = newReplion

	replionAdded:Fire(name, newReplion)
end

local function configureConnnections()
	local replionCreated = eventsFolder:FindFirstChild('ReplionCreated') :: RemoteEvent
	local replionDeleted = eventsFolder:FindFirstChild('ReplionDeleted') :: RemoteEvent

	replionCreated.OnClientEvent:Connect(createReplion)

	replionDeleted.OnClientEvent:Connect(function(name: string)
		local replion = replions[name] :: ClientReplion

		replionRemoved:Fire(name, replion)

		replions[name] = nil;
		(replion :: any):Destroy()
	end)

	local function connectEvent(remote: RemoteEvent, fn: (ClientReplion, ...any) -> ())
		remote.OnClientEvent:Connect(function(name: string, ...: any)
			local replion = replions[name] :: ClientReplion

			if replion then
				fn(replion, ...)
			end
		end)
	end

	local methodsFolder: Folder = eventsFolder:FindFirstChild('Methods') :: Folder

	local updateEvent = methodsFolder:FindFirstChild('Update') :: RemoteEvent
	local setEvent = methodsFolder:FindFirstChild('Set') :: RemoteEvent
	local arrayInsertEvent = methodsFolder:FindFirstChild('ArrayInsert') :: RemoteEvent
	local arrayRemoveEvent = methodsFolder:FindFirstChild('ArrayRemove') :: RemoteEvent
	local arrayClear = methodsFolder:FindFirstChild('ArrayClear') :: RemoteEvent

	connectEvent(updateEvent, ClientMethods.update)
	connectEvent(setEvent, ClientMethods.set)
	connectEvent(arrayInsertEvent, ClientMethods.insert)
	connectEvent(arrayRemoveEvent, ClientMethods.remove)
	connectEvent(arrayClear, ClientMethods.clear)
end

--[=[
	@type EventCallback (name: string, replion: ClientReplion) -> ()
	@within ReplionController
]=]

--[=[
	@prop Action Enums
	@tag Enum
	@within ReplionController
	@readonly
]=]

--[=[
	@prop ClientReplion ClientReplion
	@within ReplionController
	@readonly
]=]

--[=[
	@class ReplionController
	@client
]=]
local ReplionController = {}
ReplionController.Enums = Enums
ReplionController.ClientReplion = ClientReplion

--[=[
	Starts the ReplionController. This should be called once.
]=]
function ReplionController.Start()
	if starting then
		return
	end

	starting = true

	local requestReplions = eventsFolder:FindFirstChild('RequestReplions') :: RemoteEvent

	local connection: RBXScriptConnection?
	connection = requestReplions.OnClientEvent:Connect(function(playerReplions: { [string]: any })
		if connection == nil then
			return
		end

		(connection :: RBXScriptConnection):Disconnect()
		connection = nil

		for name: string, info: any in pairs(playerReplions) do
			createReplion(name, info.Data, info.Tags)
		end

		configureConnnections()

		statedCompleted = true
		onStart:Fire()

		task.defer(onStart.Destroy, onStart)
	end)

	task.spawn(function()
		while connection ~= nil do
			requestReplions:FireServer()

			task.wait(1)
		end
	end)
end

--[=[
	@return Promise
]=]
function ReplionController.OnStart()
	return if statedCompleted then Promise.resolve() else Promise.fromEvent(onStart.Event)
end

type EventCallback = (name: string, replion: ClientReplion) -> ()

local callbackCheck = t.strict(t.callback)
--[=[
	A callback that is called when a replion is created.

	@param callback EventCallback
	@return Connection
]=]
function ReplionController:OnReplionAdded(callback: EventCallback): Types.Connection
	callbackCheck(callback)

	return replionAdded:Connect(callback)
end

local filteredCallback = t.strict(t.string, t.callback)
--[=[
	A callback that will be called when a replion that contains the given tag is created.

	@param callback EventCallback
	@return Connection
]=]
function ReplionController:OnReplionAddedWithTag(tag: string, callback: EventCallback): Types.Connection
	filteredCallback(tag, callback)

	return replionAdded:Connect(function(name: string, replion: ClientReplion)
		if replion.Tags and table.find(replion.Tags, tag) then
			callback(name, replion)
		end
	end)
end

--[=[
	A callback that is called when a replion is removed.

	@param callback EventCallback
	@return Connection
]=]
function ReplionController:OnReplionRemoved(callback: EventCallback): Types.Connection
	callbackCheck(callback)

	return replionRemoved:Connect(callback)
end

--[=[
	A callback that will be called when a replion that contains the given tag is removed.

	@param callback EventCallback
	@return Connection
]=]
function ReplionController:OnReplionRemovedWithTag(tag: string, callback: EventCallback): Types.Connection
	filteredCallback(tag, callback)

	return replionRemoved:Connect(function(name: string, replion: ClientReplion)
		if replion.Tags and table.find(replion.Tags, tag) then
			callback(name, replion)
		end
	end)
end

local stringCheck = t.strict(t.string)
--[=[
	About Promises: https://eryn.io/roblox-lua-promise/api/Promise/

	@return Promise
]=]
function ReplionController:AwaitReplion(name: string)
	stringCheck(name)

	local createdReplion = replions[name]
	if createdReplion then
		return Promise.resolve(createdReplion)
	end

	return Promise.fromEvent(replionAdded, function(replionName: string)
		return replionName == name
	end):andThen(function(_, replion)
		return replion
	end)
end

--[=[
	@return ClientReplion
	@yields
	
	Alias for `ReplionController:AwaitReplion(name):expect()`
]=]
function ReplionController:WaitReplion(name: string): ClientReplion
	return self:AwaitReplion(name):expect()
end

--[=[
	@return ClientReplion?
]=]
function ReplionController:GetReplion(name: string): ClientReplion?
	stringCheck(name)

	return replions[name]
end

return ReplionController
