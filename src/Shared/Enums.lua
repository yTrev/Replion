--!strict
local Types = require(script.Parent.Types)

type EnumList = {
	[string | number]: Types.Enum,
}

type Enums = { [string]: EnumList }

local function createEnum(name: string, value: number): Types.Enum
	return table.freeze({
		Name = name,
		Value = value,
	} :: any) :: Types.Enum
end

local function enum(enums: { string }): EnumList
	local newEnum: EnumList = {}

	for i, memberName: string in ipairs(enums) do
		local newEnumItem = createEnum(memberName, i)

		newEnum[memberName] = newEnumItem
		newEnum[i] = newEnumItem
	end

	return table.freeze(newEnum)
end

local Enums: Enums = {
	Action = enum({ 'Added', 'Changed', 'Removed', 'Cleared', 'None' }),
	Event = enum({ 'Created', 'Deleted' }),
}

table.freeze(Enums)

return Enums
