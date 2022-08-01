local ReplicatedStorage = game:GetService('ReplicatedStorage')
local DevPackages = ReplicatedStorage:FindFirstChild('DevPackages')

workspace:SetAttribute('RUNNING_TESTS', true)

local TestEZ = require(DevPackages:FindFirstChild('TestEZ'))
TestEZ.TestBootstrap:run({ ReplicatedStorage:FindFirstChild('Tests') })
