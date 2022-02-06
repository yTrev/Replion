--!strict
-- ===========================================================================
-- Roblox services
-- ===========================================================================
local Players = game:GetService('Players')

-- ===========================================================================
-- Modules
-- ===========================================================================
local Packages = script:FindFirstAncestor('Packages')
local Promise = require(Packages:FindFirstChild('Promise'))
local t = require(Packages:FindFirstChild('t'))
local Signal = require(Packages:FindFirstChild('Signal'))

local Containers = require(script.Containers)
local ServerReplion = require(script.ServerReplion)

local Enums = require(script.Parent.Shared.Enums)
local Types = require(script.Parent.Shared.Types)
local Network = require(script.Network)

-- ===========================================================================
-- Variables
-- ===========================================================================
local ReplionService = {}
ReplionService.Enums = Enums
ReplionService.ServerReplion = ServerReplion

local replionAdded: Types.Signal = Signal.new()
local replionRemoved: Types.Signal = Signal.new()

local waitingPromises = {}

local function getPlayerCache(player)
	if not waitingPromises[player] then
		waitingPromises[player] = {}
	end

	return waitingPromises[player]
end

type ServerReplion = ServerReplion.ServerReplion

--[=[
	@interface Action
	@tag Enum
	@within ReplionService
	.Added "Added" -- A new value was added;
	.Changed "Changed" -- A value was changed;
	.Removed "Removed" -- A value was removed.
]=]

--[=[
	@prop Action Enum
	@tag Enums
	@within ReplionService
	@readonly
]=]

--[=[
	@class ReplionService
	@server
	```lua
	local ReplionService = require(path.to.Replion)
	local newReplion = ReplionService.new({
		Name = 'Data',
		Player = player,
		Data = {
			Coins = 10,
		},
	})

	newReplion:Increase('Coins', 20)
	print(newReplion:Get('Coins')) --> 30
	```
]=]

--[=[
	@param config Configuration
	@return ServerReplion?
]=]
function ReplionService.new(config: ServerReplion.Configuration)
	local newReplion = ServerReplion.new(config)

	replionAdded:Fire(newReplion)

	Network.FireEvent(Enums.Event.Created, newReplion.Player, newReplion.Name, newReplion.Data, newReplion.Tags)

	return Containers.addToContainer(newReplion) :: ServerReplion
end

local getReplionCheck = t.strict(t.tuple(t.instanceIsA('Player'), t.string))
--[=[
	@param player Player
	@param name string
	@return ServerReplion?
	@since v0.3.0
]=]
function ReplionService:GetReplion(player: Player, name: string): ServerReplion?
	getReplionCheck(player, name)

	return Containers.getFromContainer(player, name) :: ServerReplion?
end

local getReplionsCheck = t.strict(t.instanceIsA('Player'))
--[=[
	@param player Player
	@return { [string]: ServerReplion }?
	@since v0.3.0
]=]
function ReplionService:GetReplions(player: Player): { [string]: ServerReplion }?
	getReplionsCheck(player)

	local container: Containers.Container? = Containers.getContainer(player)

	if container then
		return container.Replions
	else
		return nil
	end
end

local onReplionAddedCheck = t.strict(t.tuple(t.callback, t.optional(t.instanceIsA('Player'))))
--[=[
	@param callback () -> (ServerReplion)
	@return RBXScriptConnection
	@since v0.3.0
]=]
function ReplionService:OnReplionAdded(callback, targetPlayer: Player?): Types.Connection
	onReplionAddedCheck(callback, targetPlayer)

	return replionAdded:Connect(function(newReplion: ServerReplion)
		if targetPlayer == nil or newReplion.Player == targetPlayer then
			callback(newReplion)
		end
	end)
end

--[=[
	@param callback () -> (ServerReplion)
	@return RBXScriptConnection
	@since v0.3.0
]=]
function ReplionService:OnReplionRemoved(callback, targetPlayer: Player?): Types.Connection
	onReplionAddedCheck(callback, targetPlayer)

	return replionRemoved:Connect(function(newReplion: ServerReplion)
		if targetPlayer == nil or newReplion.Player == targetPlayer then
			callback(newReplion)
		end
	end)
end

local awaitReplionCheck = t.strict(t.tuple(t.instanceIsA('Player'), t.string))
--[=[
	@return Promise
	@since v0.3.0
]=]
function ReplionService:AwaitReplion(player: Player, name: string)
	awaitReplionCheck(player, name)

	local replion: ServerReplion? = self:GetReplion(player, name)
	if replion ~= nil then
		return Promise.resolve(replion)
	end

	local cache = getPlayerCache(player)
	local id = newproxy(false)

	local newPromise = Promise.fromEvent(replionAdded, function(newReplion: ServerReplion)
		return newReplion.Player == player and newReplion.Name == name
	end)

	newPromise:finally(function()
		cache[id] = nil
	end)

	cache[id] = newPromise

	return newPromise
end

function ReplionService:WaitReplion(player: Player, name: string): ServerReplion?
	local _success: boolean, replion: ServerReplion? = self:AwaitReplion(player, name):await()

	return replion
end

Players.PlayerRemoving:Connect(function(player: Player)
	local playerCache = waitingPromises[player]
	if playerCache then
		for _, promise in pairs(playerCache) do
			promise:cancel()
		end

		waitingPromises[player] = nil
	end

	local playerReplions: Containers.Container? = Containers.getContainer(player, true)

	if playerReplions ~= nil then
		for _, replion in pairs(playerReplions.Replions) do
			replion:Destroy()
		end
	end
end)

return ReplionService
