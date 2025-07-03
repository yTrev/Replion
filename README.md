<p align="center">
	<img src=".github/logo.svg" height="180" />
	<br />
	Replion is a module that allows the replication of information from Server to Client lightly and efficiently.
</p>

# Installation

## Wally

Add Replion as a dependency to your `wally.toml` file:

```
Replion = "ytrev/replion@2.0.0"
```

# Usage

A simple example that shows how to use Replion.

### **Server**

```lua
local Players = game:GetService('Players')

local Replion = require(path.to.replion)

type DataReplion = Replion.ServerReplion<{
	Coins: number,
}>

local function createReplion(player: Player)
	Replion.Server.new({
		Channel = 'Data',
		ReplicateTo = player,

		Data = {
			Coins = 0,
		}
	})
end

Players.PlayerAdded:Connect(createReplion)

for _, player: Player in Players:GetPlayers() do
	task.spawn(createReplion, player)
end

while true do
	for _, player: Player in Players:GetPlayers() do
		local playerReplion: DataReplion? = Replion.Server:GetReplionFor(player, 'Data')
		if not playerReplion then
			continue
		end

		playerReplion:Increase('Coins', 10)
	end

	task.wait(1)
end
```

### **Client**

```lua
local Replion = require(path.to.replion)

Replion.Client:AwaitReplion('Data', function(dataReplion)
	print('Coins:', dataReplion:Get('Coins'))

	local connection = dataReplion:OnChange('Coins', function(newCoins: number, oldCoins: number)
		print('Coins:', newCoins)
	end)
end)
```
