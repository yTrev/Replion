--!nocheck
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)

local expect = JestGlobals.expect
local describe = JestGlobals.describe
local it = JestGlobals.it
local beforeEach = JestGlobals.beforeEach
local jest = JestGlobals.jest

local ClientReplion

beforeEach(function()
	jest.resetModules()

	ClientReplion = require(script.Parent.ClientReplion)
end)

describe('ClientReplion.new', function()
	it('should return a Replion', function()
		local newReplion = ClientReplion.new({ nil, 'new', { Coins = 20 } })

		expect(type(newReplion)).toBe('table')
	end)
end)

describe('ClientReplion:BeforeDestroy', function()
	it('should be called when the replion is destroyed', function()
		local newReplion = ClientReplion.new({
			Data = { Coins = 20 },
			Channel = 'BeforeDestroy',
			Id = '',
		})

		local fnMock = jest.fn()

		newReplion:BeforeDestroy(fnMock)
		newReplion:Destroy()

		expect(fnMock).toHaveBeenCalledTimes(1)
		expect(newReplion.Destroyed).toBe(true)
	end)
end)

describe('ClientReplion:Get', function()
	it('should return the value of the given key', function()
		local newReplion = ClientReplion.new({
			nil,
			'Get',
			{
				Foo = true,

				A = {
					B = {
						[1] = 'Bar',
					},
				},
			},
		})

		expect(newReplion:Get('Foo')).toBe(true)
		expect(newReplion:Get({ 'A', 'B', 1 })).toBe('Bar')
	end)
end)

describe('ServerReplion:GetExpect', function()
	it('should get the value of the Replion', function()
		local newReplion = ClientReplion.new({
			nil,
			'Get',
			{
				Foo = true,

				A = {
					B = {
						[1] = 'Bar',
					},
				},
			},
		})

		expect(newReplion:GetExpect('Foo')).toBe(true)
		expect(newReplion:GetExpect({ 'A', 'B', 1 })).toBe('Bar')
	end)

	it('should error when the value does not exist', function()
		local newReplion = ClientReplion.new({ nil, 'Get', {} })

		expect(function()
			newReplion:GetExpect('Foo')
		end).toThrow()
	end)

	it('should error with a custom message', function()
		local newReplion = ClientReplion.new({ nil, 'Get', {} })

		expect(function()
			newReplion:GetExpect('Foo', 'Custom message')
		end).toThrow('Custom message')
	end)
end)

describe('ClientReplion:_set', function()
	it('should set the value of the given key', function()
		local newReplion = ClientReplion.new({ nil, 'Set', {} })

		newReplion:_set('Foo', true)

		expect(newReplion:Get('Foo')).toBe(true)
	end)

	it('should call the OnChange signal', function()
		local newReplion = ClientReplion.new({ nil, 'Set', {} })

		local fnMock = jest.fn()

		newReplion:OnChange('Foo', fnMock)
		newReplion:_set('Foo', true)

		expect(fnMock).toHaveBeenCalledWith(true, nil)
	end)
end)

describe('ClientReplion:_clear', function()
	it('should clear the array', function()
		local newReplion = ClientReplion.new({ nil, 'Clear', { Array = { 1, 2, 3 } } })

		newReplion:_clear('Array')

		expect(newReplion:Get('Array')).toEqual({})
	end)

	it('should call the OnChange signal', function()
		local newReplion = ClientReplion.new({ nil, 'Clear', { Array = { 1, 2, 3 } } })

		local fnMock = jest.fn()

		newReplion:OnChange('Array', fnMock)
		newReplion:_clear('Array')

		expect(fnMock).toHaveBeenCalledWith({}, { 1, 2, 3 })
	end)
end)

describe('ClientReplion:_increase', function()
	it('should increase the value of the given key', function()
		local newReplion = ClientReplion.new({ nil, 'Increase', { Foo = 1 } })

		newReplion:_increase('Foo', 2)

		expect(newReplion:Get('Foo')).toBe(3)
	end)
end)

describe('ClientReplion:_insert', function()
	it('should insert the value into the array', function()
		local newReplion = ClientReplion.new({ nil, 'Insert', { Array = { 1, 3 } } })

		newReplion:_insert('Array', 2, 2)

		expect(newReplion:Get('Array')).toEqual({ 1, 2, 3 })
	end)
end)

describe('ClientReplion:_remove', function()
	it('should remove the value from the array', function()
		local newReplion = ClientReplion.new({ nil, 'Remove', { Array = { 1, 2, 3 } } })

		newReplion:_remove('Array', 2)

		expect(newReplion:Get('Array')).toEqual({ 1, 3 })
	end)
end)

describe('ClientReplion:OnChange', function()
	it('should connect the OnChange signal', function()
		local newReplion = ClientReplion.new({ nil, 'OnChange', {} })
		local fnMock = jest.fn()

		newReplion:OnChange('Foo', fnMock)
		newReplion:_set('Foo', true)

		expect(fnMock).toHaveBeenCalledWith(true, nil)
	end)

	it('should call the callback if an value inside a table changes', function()
		local newReplion = ClientReplion.new({ nil, 'OnChange', { A = { B = { C = true } } } })

		local fnMock = jest.fn()

		newReplion:OnChange('A', fnMock)

		newReplion:_set('A.B.C', false)
		newReplion:_set('A.B', { D = true })
		newReplion:_set('A.B.D', false)

		expect(fnMock).toHaveBeenCalledWith({ B = { C = false } }, { B = { C = true } })
		expect(fnMock).toHaveBeenCalledWith({ B = { D = true } }, { B = { C = false } })
		expect(fnMock).toHaveBeenCalledWith({ B = { D = false } }, { B = { D = true } })
	end)
end)

describe('ClientReplion:OnArrayInsert', function()
	it('should call the callback when a value is inserted', function()
		local newReplion = ClientReplion.new({ nil, 'OnArrayInsert', { Array = { 1, 2, 3 } } })

		local fnMock = jest.fn()

		newReplion:OnArrayInsert('Array', fnMock)
		newReplion:_insert('Array', 2, 4)

		expect(fnMock).toHaveBeenCalledWith(4, 2)
	end)
end)

describe('ClientReplion:OnArrayRemove', function()
	it('should call the callback when a value is removed', function()
		local newReplion = ClientReplion.new({ nil, 'OnArrayRemove', { Array = { 1, 2, 3 } } })

		local fnMock = jest.fn()

		newReplion:OnArrayRemove('Array', fnMock)
		newReplion:_remove('Array', 2)

		expect(fnMock).toHaveBeenCalledWith(2, 2)
	end)
end)

describe('ClientReplion:Destroy', function()
	it('should destroy the replion', function()
		local newReplion = ClientReplion.new({ nil, 'Destroy', { Coins = 20 } })

		newReplion:Destroy()

		expect(newReplion.Destroyed).toBe(true)
	end)
end)
