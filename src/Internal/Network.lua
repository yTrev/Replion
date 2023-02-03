--!strict
local RunService = game:GetService('RunService')

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
local NOT_INITIALIZED: string = '[Replion] - Did you forget to require the Replion module on the server?'
local RUNNING_TESTS: boolean = workspace:GetAttribute('RUNNING_TESTS')

local RemotesFolder: Folder

if IS_SERVER then
	RemotesFolder = Instance.new('Folder')
	RemotesFolder.Name = 'Remotes'
	RemotesFolder.Parent = script.Parent.Parent
else
	RemotesFolder = assert(script.Parent.Parent:WaitForChild('Remotes', 5), NOT_INITIALIZED) :: Folder
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
	for _, id: string in events do
		get(id)
	end
end

local function sendTo(replicateTo: any, id: string, ...: any)
	if RUNNING_TESTS then
		return
	end

	local remote = get(id) :: RemoteEvent

	if replicateTo == 'All' then
		remote:FireAllClients(...)
	elseif type(replicateTo) == 'table' then
		for _, player in replicateTo :: { Player } do
			remote:FireClient(player, ...)
		end
	elseif typeof(replicateTo) == 'Instance' and replicateTo:IsA('Player') then
		remote:FireClient(replicateTo, ...)
	else
		error('[Replion] - Invalid replicateTo!')
	end
end

return table.freeze({
	get = get,
	create = create,
	sendTo = sendTo,
}) :: Network
