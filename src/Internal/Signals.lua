--!strict

local Freeze = require(script.Parent.Parent.Parent.Freeze)
local Signal = require(script.Parent.Parent.Parent.Signal)

local _T = require(script.Parent.Types)
local Utils = require(script.Parent.Utils)

type Container = { [string]: Container, __signal: Signal.Signal<...any>? }
type Containers = { [string]: Container }

type SignalProps = {
	_containers: Containers?,
}

local Signals = {}
Signals.__index = Signals

function Signals.new()
	return setmetatable({
		_containers = {},
	}, Signals)
end

function Signals._getContainer(self: Signals, eventName: string): Container
	assert(self._containers, "You're trying to use a Replion that has been destroyed!")

	local container = self._containers[eventName]
	if not container then
		container = {}

		self._containers[eventName] = container
	end

	return container
end

function Signals.Connect(self: Signals, eventName: string, path: _T.Path, callback: (...any) -> nil): Signal.Connection
	local signal = assert(self:Get(eventName, path), 'Signal does not exist!')

	return signal:Connect(callback)
end

function Signals.Get(self: Signals, eventName: string, path: _T.Path, create: boolean?): Signal.Signal<...any>?
	local container = self:_getContainer(eventName)
	local signal

	for _, index in Utils.getPathTable(path) do
		local indexContainer = container[index]

		if not indexContainer then
			indexContainer = {}

			container[index] = indexContainer
		end

		container = indexContainer

		signal = container.__signal
	end

	if not signal and (create == nil or create) then
		signal = Signal.new()

		container.__signal = signal
	end

	return signal
end

function Signals.FireEvent(self: Signals, eventName: string, path: _T.Path, ...: any)
	local signal = self:Get(eventName, path)
	if signal then
		signal:Fire(...)
	end
end

function Signals.FireChange(self: Signals, path: _T.Path, newValue: any, oldValue: any)
	local pathTable = Utils.getPathTable(path)

	for i = #pathTable, 1, -1 do
		local eventPath = Freeze.List.slice(pathTable, 1, i)
		local signal = self:Get('onChange', eventPath, false)

		local newPathValue = Freeze.Dictionary.getIn(newValue, eventPath)
		local oldPathValue = Freeze.Dictionary.getIn(oldValue, eventPath)

		if signal then
			signal:Fire(newPathValue, oldPathValue)
		end

		if i > 1 then
			local parentPath = Freeze.List.slice(pathTable, 1, i - 1)
			local parentSignal = self:Get('onDescendantChange', parentPath, false)
			if parentSignal then
				parentSignal:Fire(eventPath, newPathValue, oldPathValue)
			end
		end
	end
end

function Signals.Destroy(self: Signals)
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

export type Signals = typeof(setmetatable({} :: SignalProps, Signals))

return Signals
