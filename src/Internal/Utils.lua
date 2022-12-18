--!strict
local _T = require(script.Parent.Types)

local None = newproxy(false)
local SerializedNone = '\0'

local function getPathTable(path: _T.Path): { any }
	if type(path) == 'table' then
		return path
	elseif type(path) == 'string' then
		return string.split(path, '.')
	else
		return { path }
	end
end

local function getFromPath(path: _T.Path, data: any): (any, string?)
	local pathInTable: { any } = getPathTable(path)

	local pathLength: number = #pathInTable
	local value: any = data

	for i = 1, pathLength - 1 do
		value = value[pathInTable[i]]
	end

	return value, pathInTable[pathLength]
end

local function removeDuplicated(main: _T.Dictionary, other: _T.Dictionary): _T.Dictionary
	local result: _T.Dictionary = {}

	for key, value in other do
		if main[key] ~= value then
			result[key] = value
		end
	end

	return result
end

local function getValue(value)
	return if value == None or value == SerializedNone then nil else value
end

local function merge(t: _T.Dictionary, t2: _T.Dictionary): _T.Dictionary
	local result = table.clone(t)

	for index, value in t2 do
		result[index] = getValue(value)
	end

	return result
end

local function isEmpty(t: _T.Dictionary): boolean
	return next(t) == nil
end

local function equals(t: _T.Dictionary, t2: _T.Dictionary): boolean
	if type(t) ~= 'table' or type(t2) ~= 'table' then
		return t == t2
	end

	for index, value in t do
		if t2[index] ~= value then
			return false
		end
	end

	for index, value in t2 do
		if t[index] ~= value then
			return false
		end
	end

	return true
end

local function serializePath(path: _T.Path): _T.Path
	if type(path) == 'string' then
		return path
	elseif type(path) == 'table' then
		local newPath: { string } = {}

		for i, value in path do
			if type(value) ~= 'string' and type(value) ~= 'number' then
				return path
			end

			newPath[i] = value
		end

		return newPath
	end

	return path
end

return table.freeze({
	None = None,
	SerializedNone = SerializedNone,

	getValue = getValue,

	getPathTable = getPathTable,
	getFromPath = getFromPath,

	removeDuplicated = removeDuplicated,

	merge = merge,
	isEmpty = isEmpty,
	equals = equals,

	serializePath = serializePath,
})
