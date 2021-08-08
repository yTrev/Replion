--!strict
local Signal = require(script.Parent.Signal)

type Signal = Signal.Signal
export type StringArray = { string }

local function convertTablePathToString(path: StringArray): string
	return table.concat(path, '.')
end

local function convertPathToTable(path: string): StringArray
	return string.split(path, '.')
end

local function getSignal(signals, path: string | StringArray, create: boolean?): any
	local pathInString: string
	if typeof(path) == 'table' then
		pathInString = convertTablePathToString(path)
	else
		pathInString = path :: string
	end

	local pathSignal: Signal? = signals[pathInString]
	if pathSignal == nil and create then
		pathSignal = Signal.new()
		signals[pathInString] = pathSignal
	end

	return pathSignal
end

local function shallowCopy(tableToCopy: any): any
	local n: number = #tableToCopy
	local new = table.create(n)

	if n > 0 then
		table.move(tableToCopy, 1, n, 1, new)
	else
		for k: any, value: any in pairs(tableToCopy) do
			new[k] = value
		end
	end

	return new
end

local function assign(targetTable, newValues: { any })
	local newTable = shallowCopy(targetTable)

	for k: any, value: any in pairs(newValues) do
		newTable[k] = value
	end

	return newTable
end

return {
	getSignal = getSignal,
	convertTablePathToString = convertTablePathToString,
	convertPathToTable = convertPathToTable,
	assign = assign,
}
