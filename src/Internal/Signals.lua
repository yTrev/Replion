--!strict
local Signal = require(script.Parent.Parent.Parent.Signal)

local _T = require(script.Parent.Types)
local Utils = require(script.Parent.Utils)

type Signals = {
	[string]: _T.Signal,
}

type Container = {
	[string]: Signals,
}

local Signals = {}
Signals.__index = Signals

function Signals.new()
	return setmetatable({}, Signals)
end

function Signals:_getContainer(name: string)
	local container = self[name]
	if not container then
		container = {}

		self[name] = container
	end

	return container
end

function Signals:Pause()
	self._paused = true
end

function Signals:Resume()
	self._paused = false
end

function Signals:IsPaused()
	return self._paused
end

function Signals:Get(name: string, path: _T.Path)
	local container = self:_getContainer(name)

	local pathInString = Utils.getStringPath(path)
	local signal = container[pathInString]

	if not signal then
		signal = Signal.new()

		container[pathInString] = signal
	end

	return signal
end

function Signals:GetSignals(name: string): Container?
	return self[name]
end

function Signals:Fire(name: string, path: _T.Path, ...: any)
	if self._paused then
		return
	end

	local signalsContainer: Container? = self[name]

	if signalsContainer then
		local pathInString: string = Utils.getStringPath(path)
		local signal = signalsContainer[pathInString]

		if signal then
			signal:Fire(...)
		end
	end

	local onDescendantChange = self.onDescendantChange
	if onDescendantChange then
		local pathTable = Utils.getPathTable(path)

		for i = #pathTable, 1, -1 do
			local eventPath = table.concat(pathTable, '.', 1, i)

			local onDescendantSignal = onDescendantChange[eventPath]
			if onDescendantSignal then
				onDescendantSignal:Fire(pathTable, ...)
			end
		end
	end
end

function Signals:FireParent(name: string, path: _T.Path, ...: any)
	if self._paused then
		return
	end

	local signalsContainer: Container? = self[name]
	if signalsContainer then
		local pathTable: { string } = Utils.getPathTable(path)
		local parentName: string = table.concat(pathTable, '.', 1, #pathTable - 1)

		local parentSignal = signalsContainer[parentName]

		if parentSignal then
			parentSignal:Fire(...)
		end
	end
end

function Signals:Destroy()
	for name, signals in self do
		for _, signal in signals do
			signal:DisconnectAll()
		end

		self[name] = nil
	end
end

return Signals
