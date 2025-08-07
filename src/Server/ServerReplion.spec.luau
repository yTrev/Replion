--!nocheck
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Replion = require(script.Parent.Parent)
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)

local expect = JestGlobals.expect
local describe = JestGlobals.describe
local it = JestGlobals.it
local beforeEach = JestGlobals.beforeEach
local jest = JestGlobals.jest

local ReplionServer

beforeEach(function()
	jest.resetModules()

	ReplionServer = require(script.Parent)
end)

describe('ServerReplion:_serialize', function()
	it('should serialize the Replion', function()
		local newReplion = ReplionServer.new({
			Data = {},
			Channel = '_serialize',
			ReplicateTo = 'All',
			Tags = {},
		})

		local serialized = newReplion:_serialize()

		expect(type(serialized)).toBe('table')
		expect(serialized).toEqual({
			newReplion._packedId,
			newReplion.Channel,
			newReplion.Data,
			newReplion.ReplicateTo,
			newReplion.Tags,
		})
	end)
end)

describe('ServerReplion:Destroy', function()
	it('should destroy the Replion', function()
		local newReplion = ReplionServer.new({
			Data = {},
			Channel = 'Destroy',
			ReplicateTo = 'All',
			Tags = {},
		})

		newReplion:Destroy()

		expect(newReplion.Destroyed).toBe(true)
	end)

	it('should error when using a destroyed Replion', function()
		local newReplion = ReplionServer.new({
			Data = {},
			Channel = 'Destroy',
			ReplicateTo = 'All',
			Tags = {},
		})

		newReplion:Destroy()

		expect(function()
			newReplion:Set('Foo', true)
		end).toThrow()
	end)

	it('should disconnect all connections', function()
		local newReplion = ReplionServer.new({
			Data = {},
			Channel = 'Destroy',
			ReplicateTo = 'All',
			Tags = {},
		})

		local connections = {
			newReplion:OnChange('onChange', function() end),
			newReplion:OnArrayInsert('onArrayInsert', function() end),
			newReplion:OnArrayRemove('onArrayRemove', function() end),
			newReplion:OnDataChange(function() end),
			newReplion:BeforeDestroy(function() end),
		}

		newReplion:Destroy()

		for _, connection in connections do
			expect(connection.Connected).toBe(false)
		end
	end)

	it('should call the BeforeDestroy callback', function()
		local newReplion = ReplionServer.new({
			Data = {},
			Channel = 'BeforeDestroy',
			ReplicateTo = 'All',
			Tags = {},
		})

		local fnMock = jest.fn()

		newReplion:BeforeDestroy(fnMock)
		newReplion:Destroy()

		expect(fnMock).toHaveBeenCalledTimes(1)
		expect(newReplion.Destroyed).toBe(true)
	end)
end)

describe('ServerReplion:Get', function()
	it('should get the value of the Replion', function()
		local newReplion = ReplionServer.new({
			Data = {
				Foo = true,

				A = {
					B = {
						[1] = 'Bar',
					},
				},
			},

			Channel = 'Get',
			ReplicateTo = 'All',
			Tags = {},
		})

		expect(newReplion:Get('Foo')).toBe(true)
		expect(newReplion:Get({ 'A', 'B', 1 })).toBe('Bar')
	end)
end)

describe('ServerReplion:GetExpect', function()
	it('should get the value of the Replion', function()
		local newReplion = ReplionServer.new({
			Data = {
				Foo = true,

				A = {
					B = {
						[1] = 'Bar',
					},
				},
			},

			Channel = 'GetExpect',
			ReplicateTo = 'All',
			Tags = {},
		})

		expect(newReplion:GetExpect('Foo')).toBe(true)
		expect(newReplion:GetExpect({ 'A', 'B', 1 })).toBe('Bar')
	end)

	it('should error when the value does not exist', function()
		local newReplion = ReplionServer.new({
			Data = {},

			Channel = 'GetExpectError',
			ReplicateTo = 'All',
			Tags = {},
		})

		expect(function()
			newReplion:GetExpect('Foo')
		end).toThrow()
	end)

	it('should error with a custom message', function()
		local newReplion = ReplionServer.new({
			Data = {},

			Channel = 'GetExpectErrorCustomMessage',
			ReplicateTo = 'All',
			Tags = {},
		})

		expect(function()
			newReplion:GetExpect('Foo', 'Custom message')
		end).toThrow('Custom message')
	end)
end)

describe('ServerReplion:Set', function()
	it('should set the value of the Replion', function()
		local newReplion = ReplionServer.new({
			Data = {},

			Channel = 'Set',
			ReplicateTo = 'All',
			Tags = {},
		})

		newReplion:Set('Foo', true)

		expect(newReplion:Get('Foo')).toBe(true)
	end)

	it('should call the OnChange signal', function()
		local newReplion = ReplionServer.new({
			Data = {
				Daily = {
					Quests = {
						[1] = {
							id = '1234-5678',
						},
					},
				},
			},

			Channel = 'SetOnChange',
			ReplicateTo = 'All',
			Tags = {},
		})

		local fnMock = jest.fn()
		local fnMock2 = jest.fn()

		newReplion:OnChange('Foo', fnMock)
		newReplion:Set('Foo', true)

		expect(fnMock).toHaveBeenCalledWith(true, nil)

		newReplion:OnChange('Daily.Quests', fnMock2)
		newReplion:Set({ 'Daily', 'Quests', 1, 'id' }, '8765-4321')

		expect(fnMock2).toHaveBeenCalledWith({ [1] = { id = '8765-4321' } }, { [1] = { id = '1234-5678' } })
	end)

	it('should call the OnChange signal once when some values change', function()
		local newReplion = ReplionServer.new({
			Channel = 'SetOnChangeOnce',
			ReplicateTo = 'All',
			Tags = {},
			Data = { A = {} },
		})

		local fnMock = jest.fn()

		newReplion:OnChange('A', fnMock)
		newReplion:Set('A', { { 1 } })

		expect(fnMock).toHaveBeenCalledTimes(1)
	end)

	it('should call the OnChange signal if an value inside a table changes', function()
		local newReplion = ReplionServer.new({
			Channel = 'SetOnChangeNested',
			ReplicateTo = 'All',
			Tags = {},
			Data = { A = { B = { C = true } } },
		})

		local fnMock = jest.fn()

		newReplion:OnChange('A', fnMock)

		newReplion:Set('A.B.C', false)

		expect(fnMock).toHaveBeenCalledWith({ B = { C = false } }, { B = { C = true } })
	end)
end)

describe('ServerReplion:SetReplicateTo', function()
	it('should set the ReplicateTo value of the Replion', function()
		local newReplion = ReplionServer.new({
			Data = {},

			Channel = 'SetReplicateTo',
			ReplicateTo = {},
			Tags = {},
		})

		newReplion:SetReplicateTo('All')

		expect(newReplion.ReplicateTo).toBe('All')
	end)

	it('should fire the _replicateToChanged signal', function()
		local newReplion = ReplionServer.new({
			Data = {},

			Channel = '_replicateToChanged',
			ReplicateTo = {},
			Tags = {},
		})

		local currentReplicateTo = newReplion.ReplicateTo
		local fnMock = jest.fn()

		newReplion._replicateToChanged:Connect(fnMock)
		newReplion:SetReplicateTo('All')

		expect(fnMock).toHaveBeenCalledWith('All', currentReplicateTo)
	end)

	it("should remove players from the Replion's internal cache", function()
		local newFakePlayer = newproxy()
		local otherFakePlayer = newproxy()

		local newReplion = ReplionServer.new({
			Data = {},

			Channel = 'SetReplicateToCache',
			ReplicateTo = { newFakePlayer },
			Tags = {},
		})

		expect(ReplionServer:GetReplionFor(newFakePlayer, 'SetReplicateToCache')).toBeDefined()

		newReplion:SetReplicateTo({ otherFakePlayer })

		expect(ReplionServer:GetReplionFor(newFakePlayer, 'SetReplicateToCache')).toBe(nil)
		expect(ReplionServer:GetReplionFor(otherFakePlayer, 'SetReplicateToCache')).toBeDefined()
	end)

	it('should error if the ReplicateTo value is invalid', function()
		local newReplion = ReplionServer.new({
			Data = {},

			Channel = 'SetReplicateToError',
			ReplicateTo = {},
			Tags = {},
		})

		expect(function()
			newReplion:SetReplicateTo('Invalid')
		end).toThrow()
	end)
end)

describe('ServerReplion:Clear', function()
	it('should clear the array', function()
		local newReplion = ReplionServer.new({
			Data = { Array = { 1, 2, 3 } },

			Channel = 'Clear',
			ReplicateTo = 'All',
			Tags = {},
		})

		newReplion:Clear('Array')

		expect(newReplion:Get('Array')).toEqual({})
	end)

	it('should call the OnChange signal', function()
		local newReplion = ReplionServer.new({
			Data = { Array = { 1, 2, 3 } },

			Channel = 'ClearOnArrayClear',
			ReplicateTo = 'All',
			Tags = {},
		})

		local fnMock = jest.fn()

		newReplion:OnChange('Array', fnMock)
		newReplion:Clear('Array')

		expect(fnMock).toHaveBeenCalledWith({}, { 1, 2, 3 })
	end)
end)

describe('ServerReplion:Increase', function()
	it('should increase the value of the Replion', function()
		local newReplion = ReplionServer.new({
			Data = { Foo = 1 },

			Channel = 'Increase',
			ReplicateTo = 'All',
			Tags = {},
		})

		newReplion:Increase('Foo', 2)

		expect(newReplion:Get('Foo')).toBe(3)
	end)

	it('should error if the value is not a number', function()
		local newReplion = ReplionServer.new({
			Data = { Foo = 'Bar' },

			Channel = 'IncreaseError',
			ReplicateTo = 'All',
			Tags = {},
		})

		expect(function()
			newReplion:Increase('Foo', 2)
		end).toThrow()
	end)
end)

describe('ServerReplion:Insert', function()
	it('should insert the value into the array', function()
		local newReplion = ReplionServer.new({
			Data = { Array = { 1, 3 } },

			Channel = 'Insert',
			ReplicateTo = 'All',
			Tags = {},
		})

		newReplion:Insert('Array', 2, 2)

		expect(newReplion:Get('Array')).toEqual({ 1, 2, 3 })
	end)
end)

describe('ServerReplion:Remove', function()
	it('should remove the value from the array', function()
		local newReplion = ReplionServer.new({
			Data = { Array = { 1, 2, 3 } },

			Channel = 'Remove',
			ReplicateTo = 'All',
			Tags = {},
		})

		newReplion:Remove('Array', 2)

		expect(newReplion:Get('Array')).toEqual({ 1, 3 })
	end)
end)

describe('ServerReplion:OnChange', function()
	it('should connect the OnChange signal', function()
		local newReplion = ReplionServer.new({
			Data = {},

			Channel = 'OnChange',
			ReplicateTo = 'All',
			Tags = {},
		})

		local fnMock = jest.fn()

		newReplion:OnChange('Foo', fnMock)
		newReplion:Set('Foo', true)

		expect(fnMock).toHaveBeenCalledWith(true, nil)
	end)

	it('should call the callback if an value inside a table changes', function()
		local newReplion = ReplionServer.new({
			Data = { A = { B = { C = true } } },

			Channel = 'OnChangeNested',
			ReplicateTo = 'All',
			Tags = {},
		})

		local fnMock = jest.fn()

		newReplion:OnChange('A', fnMock)

		newReplion:Set('A.B.C', false)
		newReplion:Set('A.B', { D = true })
		newReplion:Set('A.B.D', false)

		expect(fnMock).toHaveBeenCalledWith({ B = { C = false } }, { B = { C = true } })
		expect(fnMock).toHaveBeenCalledWith({ B = { D = true } }, { B = { C = false } })
		expect(fnMock).toHaveBeenCalledWith({ B = { D = false } }, { B = { D = true } })
	end)
end)

describe('ServerReplion:OnArrayInsert', function()
	it('should call the callback if an value inside a table changes', function()
		local newReplion = ReplionServer.new({
			Data = { Array = { 1, 2, 3 } },

			Channel = 'OnArrayInsert',
			ReplicateTo = 'All',
			Tags = {},
		})

		local fnMock = jest.fn()

		newReplion:OnArrayInsert('Array', fnMock)
		newReplion:Insert('Array', 2, 4)

		expect(fnMock).toHaveBeenCalledWith(4, 2)
	end)
end)

describe('ServerReplion:OnArrayRemove', function()
	it('should call the callback if an value inside a table changes', function()
		local newReplion = ReplionServer.new({
			Data = { Array = { 1, 2, 3 } },

			Channel = 'OnArrayRemove',
			ReplicateTo = 'All',
			Tags = {},
		})

		local fnMock = jest.fn()

		newReplion:OnArrayRemove('Array', fnMock)
		newReplion:Remove('Array', 2)

		expect(fnMock).toHaveBeenCalledWith(2, 2)
	end)
end)

describe('ServerReplion:OnDataChange', function()
	it('should call the callback if the data changes', function()
		local newReplion = ReplionServer.new({
			Data = {},

			Channel = 'OnDataChange',
			ReplicateTo = 'All',
			Tags = {},
		})

		local fnMock = jest.fn()
		newReplion:OnDataChange(fnMock)

		newReplion:Set('Foo', true)
		newReplion:Set('Bar', { Baz = 0 })
		newReplion:Increase('Bar.Baz', 1)

		expect(fnMock).toHaveBeenCalledTimes(3)
	end)
end)

describe('ServerReplion:Update', function()
	it('should update the value of the Replion', function()
		local newReplion = ReplionServer.new({
			Data = { Foo = true, ToRemoved = 0 },

			Channel = 'Update',
			ReplicateTo = 'All',
			Tags = {},
		})

		newReplion:Update({
			Foo = false,
			Bar = {},
			ToRemoved = Replion.None,
		})

		expect(newReplion:Get('Foo')).toBe(false)
		expect(newReplion:Get('Bar')).toEqual({})
	end)

	it('should call the OnChange signal', function()
		local newReplion = ReplionServer.new({
			Data = { Foo = true },

			Channel = 'UpdateOnChange',
			ReplicateTo = 'All',
			Tags = {},
		})

		local fnMock = jest.fn()

		newReplion:OnChange('Foo', fnMock)
		newReplion:Update({ Foo = false })

		expect(fnMock).toHaveBeenCalledWith(false, true)
	end)
end)
