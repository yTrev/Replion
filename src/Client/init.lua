--!strict
--[[
	Replion:Start()

	Replion:OnUpdate(path: { string }| string, callback: (...any) -> ()): Connection

	Replion:GetData(): any
	Replion:Get(path: { string } | string): any
	Replion:GetOption(path: { string } | string): Option<any>

	Replion.Data: any
]]

-- ===========================================================================
-- Roblox services
-- ===========================================================================
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- ===========================================================================
-- Modules
-- ===========================================================================
local Utils = require(script.Parent.Shared.Utils)
local Option = require(script.Parent.Shared.Option)
local Signal = require(script.Parent.Shared.Signal)
local Enums = require(script.Parent.Shared.Enums)

-- ===========================================================================
-- Variables
-- ===========================================================================
local ReplionFolder: Folder = ReplicatedStorage:WaitForChild('ReplionEvents') :: Folder

local started: boolean = false
local waitData: Signal = Signal.new()
local signals: { [string]: Signal.Signal } = {}

local Replion = {}
Replion.Action = Enums.Action

type Signal = Signal.Signal
type Connection = Signal.Connection

-- ===========================================================================
-- Private functions
-- ===========================================================================
function Replion:_processUpdate(action: string, path: { string }, newValue: any)
	local updateSignal: Signal? = Utils.getSignal(signals, path)

	local data = self:GetData()
	local last: string = path[#path]

	for i: number = 1, #path - 1 do
		data = data[path[i]]
	end

	if typeof(newValue) == 'table' then
		if typeof(data[last]) == 'table' then
			data[last] = Utils.assign(data[last], newValue)
		else
			data[last] = newValue
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
function Replion:GetData(): any
	return self.Data or waitData:Wait()
end

function Replion:OnUpdate(path: Utils.StringArray | string, callback): Connection
	assert(typeof(callback) == 'function', 'Invalid callback!')

	local signal: Signal = Utils.getSignal(signals, path, true)
	return signal:Connect(callback)
end

function Replion:Get(path: Utils.StringArray | string): any
	local pathInTable: { string }

	if typeof(path) == 'string' then
		pathInTable = Utils.convertPathToTable(path :: string)
	else
		pathInTable = path :: Utils.StringArray
	end

	local value: any = self:GetData()
	for _: number, name: string in ipairs(pathInTable) do
		value = value[name]
	end

	return value
end

function Replion:GetOption(path: Utils.StringArray | string): any
	return Option.Wrap(self:Get(path))
end

function Replion:Start()
	if started then
		return
	end

	started = true

	local requestData: RemoteEvent = ReplionFolder:FindFirstChild('RequestData') :: RemoteEvent
	local connection: RBXScriptConnection
	connection = requestData.OnClientEvent:Connect(function(data: any)
		connection:Disconnect()

		self.Data = data

		waitData:Fire(self.Data)
		waitData:Destroy()
	end)

	requestData:FireServer()

	local onUpdate: RemoteEvent = ReplionFolder:FindFirstChild('OnUpdate') :: RemoteEvent
	onUpdate.OnClientEvent:Connect(function(...: any)
		self:_processUpdate(...)
	end)
end

return Replion
