--!strict
--!optimize 2
--!native
local Signal = require(script.Parent.Parent.Parent.Signal)

local _T = require(script.Parent.Types)
local Utils = require(script.Parent.Utils)

type Container = { [string]: Container, __signal: Signal.Signal<...any>? }
type Containers = { [string]: Container }

-- Use this function instead of Freeze.Dictionary.getIn to be able to inline it
local function getIn(value: any, path: { any }): any
	for _, index in path do
		if not value then
			return nil
		end

		value = value[index]
	end

	return value
end

export type Signals = {
	new: () -> Signals,
	_containers: { [any]: Container }?,

	_getContainer: (self: Signals, eventName: string, create: boolean?) -> Container,

	Connect: (self: Signals, eventName: string, path: _T.Path, callback: (...any) -> ()) -> Signal.Connection,
	Get: (self: Signals, eventName: string, path: _T.Path, create: boolean?) -> Signal.Signal<...any>?,

	FireEvent: (self: Signals, eventName: string, path: _T.Path, ...any) -> (),
	FireChange: (self: Signals, path: _T.Path, newValue: any, oldValue: any) -> (),

	Destroy: (self: Signals) -> (),
}

local SignalsMeta = {}
SignalsMeta.__index = SignalsMeta

local Signals: Signals = SignalsMeta :: any

function Signals.new()
	return (setmetatable({
		_containers = {},
	}, Signals) :: any) :: Signals
end

function Signals:_getContainer(eventName, create)
	assert(self._containers, "You're trying to use a Replion that has been destroyed!")

	if create and not self._containers[eventName] then
		self._containers[eventName] = {}
	end

	return self._containers[eventName]
end

function Signals:Connect(eventName, path, callback)
	if _G.__DEV__ and not _G.__IGNORE_INSTANCES_WARNING__ then
		-- Warn about the possible memory leak when using Instances as indexes
		local hasInstances = false
		for _, value in Utils.getPathTable(path) do
			if typeof(value) ~= 'Instance' then
				continue
			end

			hasInstances = true

			break
		end

		if hasInstances then
			local scriptName, line = debug.info(3, 'sl')

			task.spawn(
				error,
				`[Memory Leak Warning] Instance used as a Connection index at {scriptName}:{line}. `
					.. 'Using Instances will cause memory leaks as Replion cannot automatically '
					.. 'dispose of such connections. Consider using a string or number as your index to prevent this issue.'
			)
		end
	end

	local signal = assert(self:Get(eventName, path), 'Signal does not exist!')

	return signal:Connect(callback)
end

function Signals:Get(eventName, path, create)
	-- Only create the container/signal if it's really needed
	-- This is to prevent creating a lot of empty tables and unused signals
	local shouldCreate = create == nil or create
	local container = self:_getContainer(eventName, shouldCreate)
	if not container then
		return
	end

	for _, index in Utils.getPathTable(path) do
		if not container[index] then
			if shouldCreate then
				container[index] = {}
			else
				return nil
			end
		end

		container = container[index]

		if not container then
			return nil
		end
	end

	if shouldCreate and not container.__signal then
		container.__signal = Signal.new()
	end

	return container.__signal
end

function Signals:FireEvent(eventName, path, ...)
	local signal = self:Get(eventName, path, false)
	if signal then
		signal:Fire(...)
	end
end

function Signals:FireChange(path, newValue, oldValue)
	-- If it is destroyed or there are no containers, there's no need to continue
	if not self._containers or not next(self._containers) then
		return
	end

	local pathTable = Utils.getPathTable(path)
	local pathLength = #pathTable

	local onDescendantChange = self._containers.onDescendantChange ~= nil

	-- TODO: I still think that we can improve this function even more
	-- it is up to 7x faster than the previous version, but I think we can do better
	for i = pathLength, 1, -1 do
		-- Mutate the path table to prevent creating a new table for each iteration
		-- we need this function to be as fast as possible, because in bigger games
		-- we end up calling this function a lot of times
		if i < pathLength then
			pathTable[i + 1] = nil
		end

		local signalContainer = getIn(self._containers.onChange, pathTable)
		local signal = if signalContainer then signalContainer.__signal else nil
		local parentSignal

		if onDescendantChange and i > 1 then
			-- Temporary remove the index from the path table to get the parent signal
			local pathIndex = pathTable[i]
			pathTable[i] = nil

			local parentContainer = getIn(self._containers.onDescendantChange, pathTable)
			parentSignal = if parentContainer then parentContainer.__signal else nil

			pathTable[i] = pathIndex
		end

		-- If there's no signal or parent signal, there's no need to continue
		-- That will prevent from iterating over newValue and oldValue
		if not signal and not parentSignal then
			continue
		end

		-- Use inlined getIn for better performance
		local newPathValue = getIn(newValue, pathTable)
		local oldPathValue = getIn(oldValue, pathTable)

		if signal then
			signal:Fire(newPathValue, oldPathValue)
		end

		if parentSignal then
			-- I don't like this clone, but we need it because we're mutating the path table
			parentSignal:Fire(table.clone(pathTable), newPathValue, oldPathValue)
		end
	end
end

function Signals:Destroy()
	assert(self._containers, 'This Replion has already been destroyed!')

	local function destroySignals(container: Container)
		if container.__signal then
			container.__signal:Destroy()
			container.__signal = nil
		end

		for _, indexContainer in container do
			destroySignals(indexContainer)
		end
	end

	for _, container in self._containers do
		destroySignals(container)
	end

	self._containers = nil
end

return Signals
