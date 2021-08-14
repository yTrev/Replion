--!strict

--[[
	Replion = Replion.new(player: Player, data: table): Replion
	Replion.Data: any
	Replion.Player: Player

	Replion:GetReplion(player: Player): Replion?

	Replion:OnUpdate(path: { string } | string, callback: (...any) -> ()): Connection

	Replion:Set(path: { string } | string, newValue: any): any
	Replion:Update(path: { string } | string, valuesToUpdate: any): any
	Replion:Increase(path: { string } | string, number: number): number
	Replion:Decrease(path: { string } | string, number: number): number

	Replion:Get(path: { string } | string): any

	Replion:Destroy()
]]

-- ===========================================================================
-- Roblox services
-- ===========================================================================
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- ===========================================================================
-- Modules
-- ===========================================================================
local Option = require(script.Parent.Shared.Option)
local Utils = require(script.Parent.Shared.Utils)
local Signal = require(script.Parent.Shared.Signal)
local Enums = require(script.Parent.Shared.Enums)

-- ===========================================================================
-- Variables
-- ===========================================================================
local replions: { [Player]: Replion } = {}

local ReplionFolder: Folder = Instance.new('Folder')
ReplionFolder.Name = 'ReplionEvents'

local OnUpdateEvent: RemoteEvent = Instance.new('RemoteEvent')
OnUpdateEvent.Name = 'OnUpdate'
OnUpdateEvent.Parent = ReplionFolder

local RequestData: RemoteEvent = Instance.new('RemoteEvent')
RequestData.Name = 'RequestData'
RequestData.Parent = ReplionFolder

ReplionFolder.Parent = ReplicatedStorage

local Replion = {}
Replion.__index = Replion

Replion.Action = Enums.Action
Replion.TESTING = nil

function Replion.new(player: Player, initialData: any): Replion
	if replions[player] then
		return replions[player]
	end

	assert(
		typeof(player) == 'Instance' and player:IsA('Player') or Replion.TESTING and typeof(player) == 'table',
		'Invalid player!'
	)

	assert(typeof(initialData) == 'table', string.format("%q isn't a valid data!", tostring(initialData)))

	local self = setmetatable({
		Data = initialData,
		Player = player,
		_signals = {},
	}, Replion)

	replions[player] = self

	return self
end

function Replion:__tostring()
	return string.format('Replion<%s>', self.Player.Name)
end

function Replion:_fireUpdate(action: any, path: { string }, newValue: any)
	action:Expect(string.format('No change on %q update!', Utils.convertTablePathToString(path)))

	action = action:Unwrap()

	if not Replion.TESTING then
		OnUpdateEvent:FireClient(self.Player, action, path, newValue)
	end

	local signal: Signal.Signal? = Utils.getSignal(self._signals, path)
	if signal then
		signal:Fire(action, newValue)
	end

	local rootSignal: Signal.Signal? = Utils.getSignal(self._signals, path[1])
	if rootSignal and rootSignal ~= signal then
		rootSignal:Fire(action, newValue)
	end
end

function Replion:_getFromPath(path: Utils.StringArray): (any, string)
	local dataPath = self.Data

	for i: number = 1, #path - 1 do
		dataPath = dataPath[path[i]]
	end

	return dataPath, path[#path]
end

function Replion:OnUpdate(path: Utils.StringArray | string, callback: (any) -> ()): Signal.Connection
	local pathInString: string

	if typeof(path) == 'table' then
		pathInString = Utils.convertTablePathToString(path :: Utils.StringArray)
	else
		pathInString = path :: string
	end

	assert(typeof(pathInString) == 'string', string.format("%q isn't a valid path!", tostring(pathInString)))
	assert(typeof(callback) == 'function', string.format("%q isn't a valid callback!", tostring(callback)))

	local signal: Signal.Signal = Utils.getSignal(self._signals, pathInString, true)
	return signal:Connect(callback)
end

function Replion:Set(path: Utils.StringArray | string, newValue: any): any
	local pathInTable: Utils.StringArray

	if typeof(path) == 'string' then
		pathInTable = Utils.convertPathToTable(path)
	else
		pathInTable = path :: Utils.StringArray
	end

	local dataPath: any, last: string = self:_getFromPath(pathInTable)

	local lastValue: any = dataPath[last]
	local action: string?

	if lastValue == nil then
		action = Enums.Action.Added
	elseif newValue ~= lastValue then
		action = newValue == nil and Enums.Action.Removed or Enums.Action.Changed
	end

	dataPath[last] = newValue

	self:_fireUpdate(Option.Wrap(action), pathInTable, newValue)

	return dataPath[last]
end

function Replion:Update(path: Utils.StringArray | string, valuesToUpdate: any): any
	local pathInTable: Utils.StringArray

	if typeof(path) == 'string' then
		pathInTable = Utils.convertPathToTable(path)
	else
		pathInTable = path :: Utils.StringArray
	end

	local dataPath: any, last: string = self:_getFromPath(pathInTable)
	local lastValue: any = dataPath[last]
	local action: string?

	if lastValue == nil then
		dataPath[last] = valuesToUpdate
		action = Enums.Action.Added
	else
		dataPath[last] = Utils.assign(lastValue, valuesToUpdate)
		action = Enums.Action.Changed
	end

	self:_fireUpdate(Option.Wrap(action), pathInTable, valuesToUpdate)

	return dataPath[last]
end

function Replion:Get(path: Utils.StringArray | string): any
	local pathInTable: Utils.StringArray

	if typeof(path) == 'string' then
		pathInTable = Utils.convertPathToTable(path)
	else
		pathInTable = path :: Utils.StringArray
	end

	local value: any = self.Data
	for _: number, name: string in ipairs(pathInTable) do
		value = value[name]
	end

	return value
end

function Replion:Increase(path: Utils.StringArray | string, number: number): number
	local pathInTable: Utils.StringArray

	if typeof(path) == 'string' then
		pathInTable = Utils.convertPathToTable(path)
	else
		pathInTable = path :: Utils.StringArray
	end

	local dataPath: any, last: string = self:_getFromPath(pathInTable)
	local lastValue: any = dataPath[last]

	assert(
		typeof(lastValue) == 'number',
		string.format("%q isn't a number!", Utils.convertTablePathToString(pathInTable))
	)

	local action: string? = Enums.Action.Changed
	local newValue: number = lastValue + number

	if newValue ~= lastValue then
		dataPath[last] = newValue
		action = Enums.Action.Changed
	end

	self:_fireUpdate(Option.Wrap(action), pathInTable, newValue)

	return newValue
end

function Replion:Decrease(path: Utils.StringArray | string, number: number): number
	return self:Increase(path, -number)
end

function Replion:GetReplion(player: Player): Replion?
	return replions[player]
end

function Replion:Destroy()
	for _, signal: Signal.Signal in pairs(self._signals) do
		signal:Destroy()
	end

	self._signals = nil

	replions[self.Player] = nil

	setmetatable(self, nil)
end

RequestData.OnServerEvent:Connect(function(player: Player)
	local playerReplion: Replion? = replions[player]

	if playerReplion then
		RequestData:FireClient(player, playerReplion.Data)
	else
		RequestData:FireClient(player, nil)
	end
end)

export type Replion = typeof(Replion.new(Instance.new('Player'), {}))

return Replion
