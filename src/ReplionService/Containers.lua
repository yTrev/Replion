--!strict
export type Container = {
	n: number,
	Replions: { [string]: any },
}

export type Containers = {
	[Player]: Container?,
}

local Containers: Containers = {}

local function getContainer(player: Player, dontCreate: boolean?): Container?
	local container = Containers[player]

	if container == nil and not dontCreate then
		container = { n = 0, Replions = {} }
		Containers[player] = container
	end

	return container
end

local function getFromContainer(player: Player, name: string): any
	local container: Container? = getContainer(player, true)
	if container then
		return container.Replions[name]
	else
		return nil
	end
end

local function addToContainer(replion: any)
	local container: Container = getContainer(replion.Player) :: Container

	assert(container[replion.Name] == nil, string.format('Replion with name %q already exists', replion.Name))

	container.Replions[replion.Name] = replion
	container.n += 1

	return replion
end

local function removeFromContainer(replion: any)
	local container: Container? = getContainer(replion.Player, true)

	if container ~= nil then
		container.Replions[replion.Name] = nil

		container.n -= 1

		-- If there are no more replions, remove the player's container
		-- This is to prevent the container from being a memory leak
		if container.n == 0 then
			Containers[replion.Player] = nil
		end
	end
end

return {
	addToContainer = addToContainer,
	removeFromContainer = removeFromContainer,
	getContainer = getContainer,
	getFromContainer = getFromContainer,
}
