--!strict
-- ===========================================================================
-- Roblox services
-- ===========================================================================
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- ===========================================================================
-- Modules
-- ===========================================================================
local Utils = require(script.Parent.Shared.Utils)
local Signal = require(script.Parent.Shared.Signal)
local Enums = require(script.Parent.Shared.Enums)

-- ===========================================================================
-- Constants
-- ===========================================================================
local RETRY_DELAY: number = 0.5

-- ===========================================================================
-- Types
-- ===========================================================================
type Callback = (...any) -> ()
type Signal = Signal.Signal
type Connection = Signal.Connection
type StringArray = Utils.StringArray
type StringPath = StringArray | string
type SignalDictionary = { [string]: Signal }

-- ===========================================================================
-- Variables
-- ===========================================================================
local started: boolean = false
local waitData: Signal = Signal.new()
local signals: SignalDictionary = {}

--[=[
	@interface Action
	@tag Enum
	@within ReplionClient
	.Added "Added" -- A new value was added;
	.Changed "Changed" -- A value was changed;
	.Removed "Removed" -- A value was removed.
]=]

--[=[
	The Player Data. Doesn't exist until you call Start the Replion.
	@prop Data any?
	@within ReplionClient
	@readonly
]=]

--[=[
	@prop Action Action
	@tag Enums
	@within ReplionClient
	@readonly
]=]

--[=[
	@class ReplionClient
	@client
]=]
local Replion = {}
Replion.Action = Enums.Action

-- ===========================================================================
-- Private functions
-- ===========================================================================
local function getAction(lastValue: any, newValue: any): string
	if lastValue == nil then
		return Enums.Action.Added
	elseif newValue == nil then
		return Enums.Action.Removed
	else
		return Enums.Action.Changed
	end
end

function Replion:_processUpdate(action: string, path: StringArray, newValue: any)
	local updateSignal: Signal? = Utils.getSignal(signals, path)

	local data = self:GetData()
	local last: string = path[#path]

	for i: number = 1, #path - 1 do
		data = data[path[i]]
	end

	if typeof(newValue) == 'table' and typeof(data[last]) == 'table' then
		local lastData = data[last]
		data[last] = Utils.assign(data[last], newValue)

		-- We don't need to send an update signal if the table is an array
		if newValue[1] == nil then
			local newLastIndex = #path + 1

			for index: string, value: any in pairs(newValue) do
				path[newLastIndex] = index

				local indexSignal: Signal? = Utils.getSignal(signals, path)
				if indexSignal then
					local lastValue: any = lastData[index]

					indexSignal:Fire(getAction(lastValue, value), value, lastValue)
				end
			end

			path[newLastIndex] = nil
		end
	else
		data[last] = newValue
	end

	local actionEnum: string = self.Action[action]
	if updateSignal then
		(updateSignal :: Signal):Fire(actionEnum, newValue, last)
	end

	local rootSignal: Signal? = signals[path[1]]
	if rootSignal and rootSignal ~= updateSignal then
		rootSignal:Fire(actionEnum, last, newValue)
	end
end

-- ===========================================================================
-- Public functions
-- ===========================================================================
--[=[
	Returns the Data table, will yield if the Data does not exist.
	@yields
	@return any
	@within ReplionClient
]=]
function Replion:GetData(): any
	return self.Data or waitData:Wait()
end

--[=[
	@error Invalid callback -- Occur when the callback isn't a function.
	@param path { string } | string
	@return callback (...any) -> ()
	@return Connection
	@within ReplionClient
]=]
function Replion:OnUpdate(path: StringPath, callback: Callback): Connection
	assert(typeof(callback) == 'function', 'Invalid callback!')

	local signal: Signal = Utils.getSignal(signals, path, true)
	return signal:Connect(callback)
end

--[=[
	Returns the value at the given path.
	@param path { string } | string
	@return any
	@within ReplionClient
]=]
function Replion:Get(path: StringPath): any
	local pathInTable: StringArray

	if typeof(path) == 'string' then
		pathInTable = Utils.convertPathToTable(path :: string)
	else
		pathInTable = path :: StringArray
	end

	local value: any = self:GetData()
	for _: number, name: string in ipairs(pathInTable) do
		value = value[name]
	end

	return value
end

--[=[
	Starts the Replion, will request the Player Data from the server.
	Until this function is called, the Replion will not have any data.
	@within ReplionClient
]=]
function Replion:Start()
	if started then
		return
	end

	started = true

	local eventsFolder: Folder = ReplicatedStorage:WaitForChild('ReplionEvents') :: Folder

	local requestData: RemoteEvent = eventsFolder:FindFirstChild('RequestData') :: RemoteEvent
	local connection: RBXScriptConnection
	connection = requestData.OnClientEvent:Connect(function(data: any)
		-- Data not ready, wait and retry.
		if data == nil then
			task.delay(RETRY_DELAY, requestData.FireServer, requestData)
		else
			connection:Disconnect()

			self.Data = data

			waitData:Fire(data)
			waitData:Destroy()
		end
	end)

	requestData:FireServer()

	local onUpdate: RemoteEvent = eventsFolder:FindFirstChild('OnUpdate') :: RemoteEvent
	onUpdate.OnClientEvent:Connect(function(action: string, path: StringArray, newValue: any)
		self:_processUpdate(action, path, newValue)
	end)
end

return Replion
