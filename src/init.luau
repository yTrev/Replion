--!strict
local Client = require(script.Client)
local Server = require(script.Server)

local Freeze = require(script.Parent.Freeze)

export type ServerReplion<T = any> = Server.ServerReplion<T>
export type ClientReplion<T = any> = Client.ClientReplion<T>

return table.freeze({
	Server = Server,
	Client = Client,

	None = Freeze.None,
})
