-- ===========================================================================
-- Roblox services
-- ===========================================================================
local RunService = game:GetService('RunService')

if RunService:IsClient() then
	return require(script.Client)
else
	return require(script.Server)
end
