--!strict

local function enum(name: string, enums: { string })
	local newEnum = {}

	for _, memberName: string in pairs(enums) do
		newEnum[memberName] = memberName
	end

	return setmetatable(newEnum, {
		__index = function(_, key)
			error(string.format('%q (%s) is not a valid member of %s', tostring(key), typeof(key), name), 2)
		end,

		__newindex = function()
			error(string.format('Creating new member in %q is not allowed!', name), 2)
		end,
	})
end

return {
	Action = enum('Action', { 'Added', 'Changed', 'Removed' }),
}
