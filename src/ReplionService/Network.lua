--!strict
-- ===========================================================================
-- Services
-- ===========================================================================
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- ===========================================================================
-- Modules
-- ===========================================================================
local Packages = script:FindFirstAncestor('Packages')
local t = require(Packages:FindFirstChild('t'))

local Enums = require(script.Parent.Parent.Shared.Enums)
local Types = require(script.Parent.Parent.Shared.Types)
local Utils = require(script.Parent.Parent.Shared.Utils)
local Containers = require(script.Parent.Containers)

-- ===========================================================================
-- Constants
-- ===========================================================================
local NO_CHANGE_DETECTED: string = 'No changed detected when trying to update the %q, on %q!'
local EVENTS_BY_METHOD = {
	Update = 'Update',
	Set = 'Set',
	Add = 'Set',
	Increase = 'Set',
	Decrease = 'Set',
	Insert = 'ArrayInsert',
	Remove = 'ArrayRemove',
	Clear = 'ArrayClear',
}

local NetworkServer = {}
NetworkServer.Testing = false

local networkFolder: Folder = Instance.new('Folder')
networkFolder.Name = 'ReplionNetwork'
networkFolder.Parent = ReplicatedStorage

local methodsFolder: Folder = Instance.new('Folder')
methodsFolder.Name = 'Methods'
methodsFolder.Parent = networkFolder

local function createRemoteEvent(name: string, parent: Folder?): RemoteEvent
	local remoteEvent: RemoteEvent = Instance.new('RemoteEvent')
	remoteEvent.Name = name
	remoteEvent.Parent = parent or networkFolder

	return remoteEvent
end

local MethodEvents = {
	Update = createRemoteEvent('Update', methodsFolder),
	Set = createRemoteEvent('Set', methodsFolder),
	ArrayInsert = createRemoteEvent('ArrayInsert', methodsFolder),
	ArrayRemove = createRemoteEvent('ArrayRemove', methodsFolder),
	ArrayClear = createRemoteEvent('ArrayClear', methodsFolder),
}

local replionCreated: RemoteEvent = createRemoteEvent('ReplionCreated')
local replionDeleted: RemoteEvent = createRemoteEvent('ReplionDeleted')
local requestReplions: RemoteEvent = createRemoteEvent('RequestReplions')

local enumCheck = t.strictInterface({
	Name = t.string,
	Value = t.numberPositive,
})

local fireUpdateCheck = t.tuple(t.table, enumCheck, t.array(t.string))
function NetworkServer.FireUpdate(replion, action: Types.Enum, path: Types.Path, ...: any)
	assert(fireUpdateCheck(replion, action, path))

	assert(
		action ~= Enums.Action.None,
		string.format(NO_CHANGE_DETECTED, Utils.getStringFromPath(path), tostring(replion))
	)

	local method: string = debug.info(2, 'n')
	local targetEvent: string = assert(EVENTS_BY_METHOD[method], 'Invalid method: ' .. method)
	local event: RemoteEvent = MethodEvents[targetEvent]

	-- TODO
	-- In the future, we should add suport for multiple players.
	if not NetworkServer.Testing then
		local pathTable = Utils.getStringArrayFromPath(path)

		event:FireClient(replion.Player, replion.Name, pathTable, ...)
	end
end

function NetworkServer.FireEvent(event: Types.Enum, ...)
	if NetworkServer.Testing then
		return
	end

	if event == Enums.Event.Created then
		replionCreated:FireClient(...)
	elseif event == Enums.Event.Deleted then
		replionDeleted:FireClient(...)
	end
end

function NetworkServer.OnReplionRequest(player: Player)
	local playerReplions = Containers.getContainer(player, true)

	if playerReplions then
		local replions: { [string]: any } = {}

		for name: string, replion in pairs(playerReplions.Replions) do
			replions[name] = { Data = replion.Data, Tags = replion.Tags }
		end

		requestReplions:FireClient(player, replions)
	end
end

requestReplions.OnServerEvent:Connect(NetworkServer.OnReplionRequest)

return NetworkServer
