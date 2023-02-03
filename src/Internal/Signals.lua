--!strict
local Signal = require(script.Parent.Parent.Parent.Signal)

local _T = require(script.Parent.Types)
local Utils = require(script.Parent.Utils)

type Container = { [string]: any }

type SignalProps = {
	_containers: { [string]: Container }?,
}

local Signals = {}
Signals.__index = Signals

function Signals.new()
	return setmetatable({
		_containers = {},
	}, Signals)
end

function Signals._getContainer(self: Signals, name: string): Container?
	if self._containers then
		local container = self._containers[name]
		if not container then
			container = {}

			self._containers[name] = container
		end

		return container
	else
		return nil
	end
end

function Signals.Get(self: Signals, name: string, path: _T.Path, create: boolean?): _T.Signal?
	local container = self:_getContainer(name)
	if container then
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
	else
		return nil
	end
end

function Signals.GetSignals(self: Signals, name: string): Container?
	local containers = self._containers
	if containers then
		return containers[name]
	else
		local source, line = debug.info(4, 'sl')
		if source then
			error(
				string.format(
					"[Replion] You're trying to use a Replion that has been destroyed, at %s:%d",
					source,
					line
				)
			)
		end

		return nil
	end
end

function Signals.Fire(self: Signals, name: string, path: _T.Path, ...: any)
	local signalsContainer: Container? = self:GetSignals(name)
	if signalsContainer then
		local signal = self:Get(name, path)

		if signal then
			signal:Fire(...)
		end
	end

	local onDescendantChange: Container? = self:GetSignals('onDescendantChange')
	if onDescendantChange then
		local pathTable = Utils.getPathTable(path)

		for i = #pathTable, 1, -1 do
			local onDescendantSignal = self:Get('onDescendantChange', table.concat(pathTable, '.', 1, i), false)

			if onDescendantSignal then
				onDescendantSignal:Fire(pathTable, ...)
			end
		end
	end
end

function Signals.FireParent(self: Signals, name: string, path: _T.Path, ...: any)
	local signalsContainer: Container? = self:GetSignals(name)
	if signalsContainer then
		local pathTable = table.clone(Utils.getPathTable(path))
		pathTable[#pathTable] = nil

		local parentSignal = self:Get(name, pathTable)
		if parentSignal then
			parentSignal:Fire(...)
		end
	end
end

function Signals.Destroy(self: Signals)
	local containers = self._containers
	if containers then
		local function destroySignals(container: Container)
			for name, indexContainer in container do
				if name == '__signal' then
					indexContainer:Destroy()
				else
					destroySignals(indexContainer)
				end
			end
		end

		destroySignals(containers)
	end

	self._containers = nil :: any
end

export type Signals = typeof(setmetatable({} :: SignalProps, Signals))

return Signals
