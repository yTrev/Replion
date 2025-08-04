export type Path = { any } | string | any
export type Tags = { string }?
export type Dictionary = { [any]: any }

-- { id, channel, data, replicateTo, tags }
export type SerializedReplion = { any }

export type ArrayCallback = <T>(index: number, value: T) -> ()
export type BeforeDestroy<T> = (replion: T, ...any) -> ()

export type ReplicateTo = Player | { Player } | 'All'

return nil
