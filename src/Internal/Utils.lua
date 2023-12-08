--!strict
local RunService = game:GetService('RunService')

local Freeze = require(script.Parent.Parent.Parent.Freeze)
local _T = require(script.Parent.Types)

local SERIALIZED_NONE = '\0'

local function getPathTable(path: _T.Path): { any }
	if type(path) == 'table' then
		return path
	elseif type(path) == 'string' then
		return string.split(path, '.')
	else
		return { path }
	end
end

local function getPathString(path: _T.Path): string
	if type(path) == 'string' then
		return path
	elseif type(path) == 'table' then
		return table.concat(path, '.')
	else
		return tostring(path)
	end
end

local function getValue<T>(value: T): T?
	return if value == Freeze.None or value == SERIALIZED_NONE then nil else value
end

local function safeCancelThread(thread: thread)
	if coroutine.status(thread) ~= 'dead' then
		task.cancel(thread)
	end
end

return table.freeze({
	SerializedNone = SERIALIZED_NONE,

	ShouldMock = RunService:IsStudio() and not RunService:IsRunning(),

	getValue = getValue,
	getPathTable = getPathTable,
	getPathString = getPathString,

	safeCancelThread = safeCancelThread,
})
