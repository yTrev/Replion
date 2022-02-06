# Replion
Replion is a module that allows the replication of information from _Server_ to _Client_ lightly and efficiently.

# Example
A simple example that shows how to use Replion.

### **Server**
```lua
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local ReplionService = require(ReplicatedStorage.Replion)

local DEFAULT_DATA = {
	Coins = 0,
}

local function createReplion(player: Player)
	ReplionService.new({
		Name = "Default",
		Player = player,
		Data = DEFAULT_DATA,
	})
end

Players.PlayerAdded:Connect(createReplion)

for _: number, player: Player in ipairs(Players:GetPlayers()) do
	createReplion(player)
end

while true do
	for _: number, player: Player in ipairs(Players:GetPlayers()) do
		local playerReplion = ReplionService:GetReplion(player)
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

local ReplionController = require(ReplicatedStorage.Replion)

ReplionController:AwaitReplion("Default")
	:andThen(function(clientReplion)
		clientReplion:OnUpdate('Coins', 10)
	end)
	:catch(warn)

ReplionController.Start()
```