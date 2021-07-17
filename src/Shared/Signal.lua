--!strict
type Callback = (...any) -> ()

local Connection = {}
Connection.__index = Connection

function Connection.new(signal: Signal, callback: Callback): Connection
	return setmetatable({
		_callback = callback,
		_signal = signal,
		_isConnected = true,
	}, Connection)
end

function Connection:Disconnect()
	if not self._isConnected then
		return
	end

	local connections: { Connection } = self._signal._connections
	local index: number? = table.find(connections, self)
	if index then
		local n: number = #connections

		connections[index] = connections[n]
		connections[n] = nil
	end

	self._isConnected = false
end

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
	return setmetatable({
		_connections = {},
		_threads = {},
	}, Signal)
end

function Signal.Is(object)
	return typeof(object) == 'table' and getmetatable(object) == Signal
end

function Signal:Connect(callback): Connection
	local newConnection = Connection.new(self, callback)
	table.insert(self._connections, newConnection)

	return newConnection
end

function Signal:Fire(...: any)
	for _: number, connection: Connection in ipairs(self._connections) do
		connection._callback(...)
	end

	for _: number, toResume: thread in ipairs(self._threads) do
		coroutine.resume(toResume, ...)
	end
end

function Signal:Wait(): thread
	table.insert(self._threads, coroutine.running())

	return coroutine.yield()
end

function Signal:Destroy()
	self._connections = nil
	self._thread = nil

	setmetatable(self, nil)
end

export type Signal = typeof(Signal.new())
export type Connection = typeof(Connection.new(Signal.new(), function() end))

return Signal
