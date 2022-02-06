local RunService = game:GetService('RunService')

if RunService:IsServer() then
	return require(script.ReplionService)
else
	return require(script.ReplionController)
end
