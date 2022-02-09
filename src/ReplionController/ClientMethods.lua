--!strict
-- ===========================================================================
-- Modules
-- ===========================================================================
local Packages = script:FindFirstAncestor('Packages')
local llama = require(Packages:FindFirstChild('llama'))

local Types = require(script.Parent.Parent.Shared.Types)
local Enums = require(script.Parent.Parent.Shared.Enums)
local Utils = require(script.Parent.Parent.Shared.Utils)

local ClientReplion = require(script.Parent.ClientReplion)

-- ===========================================================================
-- Variables
-- ===========================================================================
local merge = llama.Dictionary.merge
local set = llama.Dictionary.set
local copy = llama.List.copy
local removeIndex = llama.List.removeIndex

type ClientReplion = ClientReplion.ClientReplion

local function getAction(oldValue: any, newValue: any): Types.Enum
	if oldValue == nil then
		return Enums.Action.Added
	elseif newValue == nil then
		return Enums.Action.Removed
	else
		return Enums.Action.Changed
	end
end

local function replionUpdate(replion: ClientReplion, path: string, values: Types.Table)
	local signals = replion._signals

	local stringArray: Types.StringArray = Utils.convertPathToTable(path)
	local dataPath: any, last: string = Utils.getFromPath(stringArray, replion.Data)

	local oldValue: any = dataPath[last]

	dataPath[last] = merge(oldValue, values)

	if values[1] == nil then
		local newLastIndex = #stringArray + 1

		for index: string, value: any in pairs(values) do
			stringArray[newLastIndex] = index

			local indexSignal: any = Utils.getSignalFromPath(stringArray, signals)
			if indexSignal then
				local lastValue: any = oldValue[index]

				indexSignal:Fire(getAction(lastValue, value), value, lastValue)
			end
		end

		stringArray[newLastIndex] = nil
	end

	Utils.fireSignals(signals, stringArray, Enums.Action.Changed, values, oldValue)
end

local function replionSet(replion: ClientReplion, path: string, value: any)
	local signals = replion._signals

	local stringArray: Types.StringArray = Utils.convertPathToTable(path)
	local pathLength: number = #stringArray
	local last: string = stringArray[pathLength]

	local replionData = replion.Data
	local oldValue: any

	local action: Types.Enum

	if pathLength == 1 then
		oldValue = replionData[last]

		action = getAction(oldValue, value)
		replionData[last] = value
	else
		local dataPath: any = replionData
		local parent = stringArray[pathLength - 1]

		for i = 1, pathLength - 2 do
			dataPath = dataPath[stringArray[i]]
		end

		oldValue = dataPath[parent][last]

		action = getAction(oldValue, value)
		dataPath[parent] = set(dataPath[parent], last, value)
	end

	Utils.fireSignals(signals, stringArray, action, value, oldValue)
end

local function replionArrayInsert(replion: ClientReplion, path: string, index: number, value: any)
	local signals = replion._signals

	local stringArray: Types.StringArray = Utils.convertPathToTable(path)
	local dataPath: any, last: string = Utils.getFromPath(stringArray, replion.Data)

	local newData = copy(dataPath[last])
	table.insert(newData, index, value)

	dataPath[last] = newData

	Utils.fireSignalsForArray(signals, stringArray, Enums.Action.Added, index, value)
end

local function replionArrayRemove(replion: ClientReplion, path: string, index: number)
	local signals = replion._signals

	local stringArray: Types.StringArray = Utils.convertPathToTable(path)
	local dataPath: any, last: string = Utils.getFromPath(stringArray, replion.Data)

	local oldValue = dataPath[last][index]

	dataPath[last] = removeIndex(dataPath[last], index)

	Utils.fireSignalsForArray(signals, stringArray, Enums.Action.Removed, index, oldValue)
end

local function replionArrayClear(replion: ClientReplion, path: string)
	local signals = replion._signals

	local stringArray: Types.StringArray = Utils.convertPathToTable(path)
	local dataPath: any, last: string = Utils.getFromPath(stringArray, replion.Data)

	local oldValue = copy(dataPath[last])

	dataPath[last] = {}

	Utils.fireSignalsForArray(signals, stringArray, Enums.Action.Cleared, oldValue)
end

return {
	update = replionUpdate,
	set = replionSet,
	insert = replionArrayInsert,
	remove = replionArrayRemove,
	clear = replionArrayClear,
}
