local ReplicatedStorage = game:GetService('ReplicatedStorage')
local DevPackages = ReplicatedStorage:FindFirstChild('DevPackages')

local TestEZ = require(DevPackages:FindFirstChild('TestEZ'))
TestEZ.TestBootstrap:run({ ReplicatedStorage:FindFirstChild('Tests') })
