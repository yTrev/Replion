local ReplicatedStorage = game:GetService('ReplicatedStorage')

_G.NOCOLOR = true

local Jest = require(ReplicatedStorage.DevPackages.Jest)

local processServiceExists, ProcessService = pcall(function()
	-- selene: allow(incorrect_standard_library_use)
	return game:GetService('ProcessService')
end)

local root = ReplicatedStorage.Packages.Replion

local status, result = Jest.runCLI(root, {
	verbose = true,
	ci = false,
}, { root }):awaitStatus()

if status == 'Rejected' then
	print(result)
end

if status == 'Resolved' and result.results.numFailedTestSuites == 0 and result.results.numFailedTests == 0 then
	if processServiceExists then
		ProcessService:ExitAsync(0)
	end
end

if processServiceExists then
	ProcessService:ExitAsync(1)
end

return nil
