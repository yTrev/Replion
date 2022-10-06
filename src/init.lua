--!strict
local Server = require(script.Server)
local Client = require(script.Client)

local Utils = require(script.Internal.Utils)
local Types = require(script.Internal.Types)

export type ServerReplion = Server.ServerReplion
export type ClientReplion = Client.ClientReplion

export type ExtensionCallback = Types.ExtensionCallback<ServerReplion>
export type Extensions = { [string]: ExtensionCallback }

local Replion = {
	Server = Server,
	Client = Client,

	None = Utils.None,
}

table.freeze(Replion)

return Replion
