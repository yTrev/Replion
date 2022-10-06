local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Replion = require(ReplicatedStorage.Packages.Replion)

local Extensions: Replion.Extensions = {
	AddItem = function(replion, item: string): boolean
		local items = replion:Get('Items')
		if items[item] then
			return false
		end

		replion:Set({ 'Items', item }, true)

		return true
	end,
}

return Extensions
