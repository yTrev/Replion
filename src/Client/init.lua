--[[
	Replion:Start()

	Replion:OnUpdate(path: { string }| string, callback: (...any) -> ()): Connection

	Replion:Get(path: { string } | string): any
	Replion:GetOption(path: { string } | string): Option<any>
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
local ReplionFolder: Folder = ReplicatedStorage:WaitForChild('ReplionEvents')

local started: boolean = false
local waitData: Signal.Signal = Signal.new()
local signals: { Signal.Signal } = {}

local Replion = {
	Action = Enums.Action,
}

function Replion:_getData()
	local data = self.Data
	return data and data or waitData:Wait()
end

function Replion:_processUpdate(action: string, path: { string }, newValue: any)
	local updateSignal: Signal.Signal? = Utils.getSignal(signals, path)

	local data = self:_getData()
	local last: string = path[#path]

	for i: number = 1, #path - 1 do
		data = data[path[i]]
	end

	if typeof(newValue) == 'table' then
		data[last] = Utils.assign(data[last], newValue)
	else
		data[last] = newValue
	end

	local actionEnum: string = self.Action[action]
	if updateSignal then
		updateSignal:Fire(actionEnum, newValue, last)
	end

	local rootSignal: Signal.Signal? = signals[path[1]]
	if rootSignal and rootSignal ~= updateSignal then
		rootSignal:Fire(actionEnum, last, newValue)
	end
end

function Replion:OnUpdate(path: Utils.StringArray | string, callback)
	local signal: any = Utils.getSignal(signals, path, true)
	return signal:Connect(callback)
end

function Replion:Get(path: Utils.String | string)
	if typeof(path) == 'string' then
		path = Utils.convertPathToTable(path :: string)
	end

	local value: any = self:_getData()
	for _: number, name: string in ipairs(path) do
		value = value[name]
	end

	return value
end

function Replion:GetOption(path: Utils.StringArray | string)
	return Option.Wrap(self:Get(path))
end

function Replion:Start()
	if started then
		return
	end

	started = true

	local requestData: RemoteEvent = ReplionFolder:FindFirstChild('RequestData')
	local connection: RBXScriptConnection
	connection = requestData.OnClientEvent:Connect(function(data: any)
		connection:Disconnect()

		self.Data = data

		waitData:Fire(self.Data)
		waitData:Destroy()
		waitData = nil
	end)

	requestData:FireServer()

	local onUpdate: RemoteEvent = ReplionFolder:FindFirstChild('OnUpdate')
	onUpdate.OnClientEvent:Connect(function(...: any)
		self:_processUpdate(...)
	end)
end

return Replion
