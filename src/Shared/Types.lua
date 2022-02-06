type Array<V> = { V }
type Dictionary<K, V> = { [K]: V }

export type Callback = (...any) -> (...any)

export type Path = { string } | string
export type GenericArray = Array<any>
export type StringArray = Array<string>
export type StringDictionary = Dictionary<string, any>
export type Table = Dictionary<any, any>

export type PacketData = {
	Name: string,
	Action: number,
	Path: { string },
	Value: any,
}

export type Enum = {
	Name: string,
	Value: number,
}

export type Signal = {
	new: () -> Signal,
	Wrap: (rbxScriptSignal: RBXScriptSignal) -> Signal,
	Is: (obj: Signal) -> boolean,
	Connect: (self: Signal, fn: Callback) -> Connection,
	GetConnections: (self: Signal) -> { Connection },
	Wait: (self: Signal) -> (...any?),
	Fire: (self: Signal, ...any) -> (),
	FireDeferred: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
	Destroy: (self: Signal) -> (),

	_handlerListHead: boolean | Connection,
	_proxyHandler: nil | RBXScriptConnection,
}

export type Connection = {
	new: (signal: Signal, fn: Callback) -> Connection,
	Disconnect: (self: Connection) -> (),
	Destroy: (self: Connection) -> (),
	Connected: boolean,

	_signal: Signal,
	_fn: Callback,
	_next: boolean,
}

export type Signals = { [string]: Signal }

return nil
