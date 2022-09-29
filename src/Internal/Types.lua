--!strict
local Signal = require(script.Parent.Parent.Parent.Signal)

export type Signal = typeof(Signal.new())
export type Signals = { [string]: Signal }
export type Connection = typeof(Signal.new():Connect(warn))
export type ExtensionCallback<T> = (replion: T, ...any) -> (...any)

export type Path = string | { string }
export type Tags = { string }?
export type Dictionary = { [any]: any }
export type SerializedReplion = {
	Data: Dictionary,
	Channel: string,
	Tags: { string }?,
	Extensions: ModuleScript?,
	Id: string,
}

export type ChangeCallback = (newValue: any, oldValue: any) -> ()
export type ArrayCallback = (index: number, value: any) -> ()
export type BeforeDestroy<T> = (replion: T, ...any) -> ()

return nil
