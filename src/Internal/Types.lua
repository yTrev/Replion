--!strict
local Signal = require(script.Parent.Parent.Parent.Signal)

export type Signal = typeof(Signal.new())
export type Signals = { [string]: Signal }
export type Connection = typeof(Signal.new():Connect(warn))
export type ExtensionCallback<T> = (replion: T, ...any) -> ...any

export type Path = any
export type Tags = { string }?
export type Dictionary = { [any]: any }

-- {id, channel, data, tags, extensions}
export type SerializedReplion = { any }

export type ChangeCallback = (newValue: any, oldValue: any) -> ()
export type ArrayCallback = (index: number, value: any) -> ()
export type BeforeDestroy<T> = (replion: T, ...any) -> ()

return nil
