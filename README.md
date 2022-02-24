<p align="center">
	<img src=".github/logo.svg" height="180" />
	<br />
	Replion is a module that allows the replication of information from Server to Client lightly and efficiently.
</p>

# Installation

## Wally
Add Replion as a dependency to your `wally.toml` file:
```
Replion = "ytrev/replion@0.3.3"
```

# Usage
A simple example that shows how to use Replion.

### **Server**
```lua
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local ReplionService = require(ReplicatedStorage.Packages.Replion)

local function createReplion(player: Player)
	ReplionService.new({
		Name = 'Data',
		Player = player,
		Data = {
			Coins = 0,
		},
	})
end

Players.PlayerAdded:Connect(createReplion)

for _: number, player: Player in ipairs(Players:GetPlayers()) do
	createReplion(player)
end

while true do
	for _: number, player: Player in ipairs(Players:GetPlayers()) do
		local playerReplion = ReplionService:GetReplion(player, 'Data')
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

local ReplionController = require(ReplicatedStorage.Packages.Replion)

ReplionController:AwaitReplion('Data')
	:andThen(function(clientReplion)
		clientReplion:OnUpdate('Coins', function(action, newValue)
			print(string.format('Coins %s to %i', action.Name, newValue))
		end)
	end)
	:catch(warn)

ReplionController.Start()
```