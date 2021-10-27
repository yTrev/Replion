local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Replion = ReplicatedStorage:FindFirstChild('Replion')

require(script.Parent:FindFirstChild('TestEZ')).TestBootstrap:run({ Replion })
