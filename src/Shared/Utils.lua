--!strict
local Packages = script:FindFirstAncestor('Packages')
local Signal = require(Packages:FindFirstChild('Signal'))

local Types = require(script.Parent.Types)

local function convertTablePathToString(path: Types.StringArray): string
	return table.concat(path, '.')
end

local function convertPathToTable(path: string): Types.StringArray
	return string.split(path, '.')
end

local function getStringArrayFromPath(path: Types.Path): Types.StringArray
	if typeof(path) == 'string' then
		return convertPathToTable(path)
	elseif typeof(path) == 'table' then
		return path
	else
		error(string.format('%q is not a valid path', typeof(path)))
	end
end

local function getStringFromPath(path: Types.Path): string
	if type(path) == 'string' then
		return path
	else
		return convertTablePathToString(path)
	end
end

local function getFromPath(path: Types.Path, data: Types.StringDictionary): (any, string)
	local pathInTable: Types.StringArray = getStringArrayFromPath(path)

	local pathLength: number = #pathInTable
	local value: any = data

	for i = 1, pathLength - 1 do
		value = value[pathInTable[i]]
	end

	return value, pathInTable[pathLength]
end

local function getSignalFromPath(path: Types.Path?, signals: Types.Signals, create: boolean?): Types.Signal | nil
	if path == nil then
		return nil
	end

	local pathInString: string = getStringFromPath(path :: Types.Path)

	local signal: any = signals[pathInString]
	if signal == nil and create then
		signal = Signal.new()
		signals[pathInString] = signal
	end

	return signal
end

local function fireSignals(signals: Types.Signals, stringArray: Types.StringArray, ...)
	local rootSignal: any = signals[stringArray[1]]

	if rootSignal then
		local action, newValue, oldValue = ...
		rootSignal:Fire(action, stringArray, newValue, oldValue)
	end

	if #stringArray > 1 then
		local updateSignal = getSignalFromPath(stringArray, signals)
		if updateSignal then
			updateSignal:Fire(...)
		end
	end
end

local function fireSignalsForArray(signals: Types.Signals, stringArray: Types.StringArray, ...)
	local rootSignal: any = signals[stringArray[1]]

	if rootSignal then
		rootSignal:Fire(...)
	end

	if #stringArray > 1 then
		local updateSignal = getSignalFromPath(stringArray, signals)
		if updateSignal then
			updateSignal:Fire(...)
		end
	end
end

return {
	convertTablePathToString = convertTablePathToString,
	convertPathToTable = convertPathToTable,
	getFromPath = getFromPath,
	getStringArrayFromPath = getStringArrayFromPath,
	getStringFromPath = getStringFromPath,
	getSignalFromPath = getSignalFromPath,
	fireSignals = fireSignals,
	fireSignalsForArray = fireSignalsForArray,
}
