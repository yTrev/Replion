local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local Utils = require(script.Parent.Utils)

export type Remotes = {
	[string]: RemoteEvent,
}

type Network = {
	get: (id: string) -> RemoteEvent,
	create: (events: { string }) -> (),

	sendTo: (replicateTo: any, id: string, ...any) -> (),
}

local IS_SERVER: boolean = RunService:IsServer()
local IS_CLIENT: boolean = RunService:IsClient()
local NOT_INITIALIZED: string = 'Did you forget to require the Replion module on the server?'

local RemotesFolder: Folder

-- TODO: Make something to allow to fake RemoteEvents for testing
if not Utils.ShouldMock then
	if IS_SERVER then
		RemotesFolder = Instance.new('Folder')
		RemotesFolder.Name = 'Remotes'
		RemotesFolder.Parent = script.Parent.Parent
	else
		RemotesFolder = assert(script.Parent.Parent:WaitForChild('Remotes', 5), NOT_INITIALIZED) :: Folder
	end
end

local function get(id: string): RemoteEvent
	local remote = RemotesFolder:FindFirstChild(id)
	if remote then
		return remote :: RemoteEvent
	elseif IS_CLIENT then
		error(NOT_INITIALIZED)
	end

	local newRemote = Instance.new('RemoteEvent')
	newRemote.Name = id
	newRemote.Parent = RemotesFolder

	return newRemote
end

local function create(events: { string })
	for _, id in events do
		get(id)
	end
end

local function sendTo(replicateTo: any, id: string, ...: any)
	if Utils.ShouldMock then
		return
	end

	local remote = get(id) :: RemoteEvent

	if replicateTo == 'All' then
		remote:FireAllClients(...)
	elseif type(replicateTo) == 'table' then
		for _, player in replicateTo :: { Player } do
			if not player:IsDescendantOf(Players) then
				continue
			end

			remote:FireClient(player, ...)
		end
	elseif typeof(replicateTo) == 'Instance' and replicateTo:IsA('Player') then
		remote:FireClient(replicateTo, ...)
	else
		error('Invalid replicateTo!')
	end
end

return table.freeze({
	get = get,
	create = create,
	sendTo = sendTo,
}) :: Network
