# Replion
Replion is a module that allows the replication of information from _Server_ to _Client_ lightly and efficiently.

# Example
A simple example that shows how to use Replion.

### **Server**
```lua
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local Replion = require(ReplicatedStorage.Replion)

local DEFAULT_DATA = {
	Coins = 0,
}

local function createReplion(player: Player)
	Replion.new({
		Player = player,
		Data = DEFAULT_DATA
	})
end

Players.PlayerAdded:Connect(createReplion)
Players.PlayerRemoving:Connect(function(player: Player)
	local playerReplion: Replion.Replion? = Replion:GetReplion(player)
	if playerReplion then
		playerReplion:Destroy()
	end
end)

for _: number, player: Player in ipairs(Players:GetPlayers()) do
	createReplion(player)
end

while true do
	for _: number, player: Player in ipairs(Players:GetPlayers()) do
		local playerReplion: Replion.Replion? = Replion:GetReplion(player)
		if playerReplion then
			playerReplion:Increase('Coins', 10)
		end
	end

	task.wait(1)
end
```

### **Client**
```lua
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Replion = require(ReplicatedStorage.Replion)

Replion:OnUpdate('Coins', function(action: string, newValue: number)
	print(action, newValue)
end)

Replion:Start()
```