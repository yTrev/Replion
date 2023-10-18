--!strict
export type Path = { any } | string
export type Tags = { string }?
export type Dictionary = { [any]: any }

-- {id, channel, data, replicateTo, tags}
export type SerializedReplion = { any }

export type ChangeCallback = (newValue: any, oldValue: any) -> ()
export type ArrayCallback = (index: number, value: any) -> ()
export type BeforeDestroy<T> = (replion: T, ...any) -> ()

export type ReplicateTo = Player | { Player } | 'All'
export type Cache<T> = { [string]: T }

return nil
