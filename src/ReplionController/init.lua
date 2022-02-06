--!strict
-- ===========================================================================
-- Services
-- ===========================================================================
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- ===========================================================================
-- Modules
-- ===========================================================================
local Packages = script:FindFirstAncestor('Packages')

local Promise = require(Packages:FindFirstChild('Promise'))
local llama = require(Packages:FindFirstChild('llama'))
local t = require(Packages:FindFirstChild('t'))
local Signal = require(Packages:FindFirstChild('Signal'))

local Types = require(script.Parent.Shared.Types)
local Enums = require(script.Parent.Shared.Enums)
local Utils = require(script.Parent.Shared.Utils)
local ClientReplion = require(script.ClientReplion)

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

local merge = llama.Dictionary.merge
local set = llama.Dictionary.set
local copy = llama.List.copy
local removeIndex = llama.List.removeIndex

-- ===========================================================================
-- Private functions
-- ===========================================================================
local function getAction(lastValue: any, newValue: any)
	if lastValue == nil then
		return Enums.Action.Added
	elseif newValue == nil then
		return Enums.Action.Removed
	else
		return Enums.Action.Changed
	end
end

local function createReplion(name: string, data: Types.Table, tags: Types.StringArray)
	if replions[name] then
		return
	end

	local newReplion = ClientReplion.new(data, tags)
	replions[name] = newReplion

	replionAdded:Fire(name, newReplion)
end

local function replionUpdate(name: string, path: string, values: Types.Table)
	local replion = replions[name] :: ClientReplion
	local signals = replion._signals

	local stringArray: Types.StringArray = Utils.convertPathToTable(path)
	local dataPath: any, last: string = Utils.getFromPath(stringArray, replion.Data)

	local currentValue: any = dataPath[last]

	dataPath[last] = merge(currentValue, values)

	if values[1] == nil then
		local newLastIndex = #stringArray + 1

		for index: string, value: any in pairs(values) do
			stringArray[newLastIndex] = index

			local indexSignal: any = Utils.getSignalFromPath(stringArray, signals)
			if indexSignal then
				local lastValue: any = currentValue[index]

				indexSignal:Fire(getAction(lastValue, value), value, lastValue)
			end
		end

		stringArray[newLastIndex] = nil
	end

	Utils.fireSignals(signals, stringArray, Enums.Action.Changed, values, last)
end

local function replionSet(name: string, path: string, value: any)
	local replion = replions[name] :: ClientReplion
	local signals = replion._signals

	local stringArray: Types.StringArray = Utils.convertPathToTable(path)
	local pathLength: number = #stringArray
	local last: string = stringArray[pathLength]

	local replionData = replion.Data

	local action: Types.Enum

	if #stringArray == 1 then
		action = getAction(replionData[last], value)
		replionData[last] = set(replionData, last, value)
	else
		local dataPath: any = replionData
		local parent = stringArray[pathLength - 1]

		for i = 1, pathLength - 2 do
			dataPath = dataPath[stringArray[i]]
		end

		action = getAction(dataPath[parent][last], value)
		dataPath[parent] = set(dataPath[parent], last, value)
	end

	Utils.fireSignals(signals, stringArray, action, value, last)
end

local function replionArrayInsert(name: string, path: string, index: number, value: any)
	local replion = replions[name] :: ClientReplion
	local signals = replion._signals

	local stringArray: Types.StringArray = Utils.convertPathToTable(path)
	local dataPath: any, last: string = Utils.getFromPath(stringArray, replion.Data)

	local newData = copy(dataPath[last])
	table.insert(newData, index, value)

	dataPath[last] = newData

	Utils.fireSignals(signals, stringArray, Enums.Action.Added, index, value)
end

local function replionArrayRemove(name: string, path: string, index: number)
	local replion = replions[name] :: ClientReplion
	local signals = replion._signals

	local stringArray: Types.StringArray = Utils.convertPathToTable(path)
	local dataPath: any, last: string = Utils.getFromPath(stringArray, replion.Data)

	local oldValue = dataPath[last][index]

	dataPath[last] = removeIndex(dataPath[last], index)

	Utils.fireSignals(signals, stringArray, Enums.Action.Removed, index, oldValue)
end

local function replionArrayClear(name: string, path: string)
	local replion = replions[name] :: ClientReplion
	local signals = replion._signals

	local stringArray: Types.StringArray = Utils.convertPathToTable(path)
	local dataPath: any, last: string = Utils.getFromPath(stringArray, replion.Data)

	local oldValue = copy(dataPath[last])

	dataPath[last] = {}

	Utils.fireSignals(signals, stringArray, Enums.Action.Cleared, oldValue)
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

	local methodsFolder: Folder = eventsFolder:FindFirstChild('Methods') :: Folder

	local updateEvent = methodsFolder:FindFirstChild('Update') :: RemoteEvent
	local setEvent = methodsFolder:FindFirstChild('Set') :: RemoteEvent
	local arrayInsertEvent = methodsFolder:FindFirstChild('ArrayInsert') :: RemoteEvent
	local arrayRemoveEvent = methodsFolder:FindFirstChild('ArrayRemove') :: RemoteEvent
	local arrayClear = methodsFolder:FindFirstChild('ArrayClear') :: RemoteEvent

	updateEvent.OnClientEvent:Connect(replionUpdate)
	setEvent.OnClientEvent:Connect(replionSet)
	arrayInsertEvent.OnClientEvent:Connect(replionArrayInsert)
	arrayRemoveEvent.OnClientEvent:Connect(replionArrayRemove)
	arrayClear.OnClientEvent:Connect(replionArrayClear)
end

--[=[
	@prop Action Enums
	@tag Enum
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

type EventCallback = (string, ClientReplion) -> ()

local callbackCheck = t.strict(t.callback)
--[=[
	Connects that will be called when a replion is created.

	@callback (string, ClientReplion) -> ()
	@return Connection
]=]
function ReplionController:OnReplionAdded(callback: EventCallback): Types.Connection
	callbackCheck(callback)

	return replionAdded:Connect(callback)
end

local filteredCallback = t.strict(t.string, t.callback)
--[=[
	Connects that will be called when a replion that contains the given tag is created.

	@callback (string, ClientReplion) -> ()
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
	Connects that will be called when a replion is detroy'ed.

	@callback (string, ClientReplion) -> ()
	@return Connection
]=]
function ReplionController:OnReplionRemoved(callback: EventCallback): Types.Connection
	callbackCheck(callback)

	return replionRemoved:Connect(callback)
end

--[=[
	Connects that will be called when a replion that contains the given tag is detroy'ed.

	@callback (string, ClientReplion) -> ()
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

	local createdReplion: ClientReplion? = replions[name]
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
