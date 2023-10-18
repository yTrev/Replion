--!nonstrict
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Utils = require(ReplicatedStorage.Packages.Replion.Internal.Utils)
local ClientReplion = require(ReplicatedStorage.Packages.Replion.Client.ClientReplion)

return function()
	describe('ClientReplion.new', function()
		it('should return a Replion', function()
			local newReplion = ClientReplion.new({ nil, 'new', { Coins = 20 } })
			expect(newReplion).to.be.a('table')
		end)
	end)

	describe('ClientReplion:BeforeDestroy', function()
		it('should be called when the replion is destroyed', function()
			local newReplion = ClientReplion.new({
				Data = { Coins = 20 },
				Channel = 'BeforeDestroy',
				Id = '',
			})

			local called = false

			newReplion:BeforeDestroy(function()
				called = true
			end)

			newReplion:Destroy()

			expect(called).to.equal(true)
		end)
	end)

	describe('ClientReplion:Get', function()
		local newReplion = ClientReplion.new({ nil, 'Get', { Coins = 20, Other = { Value = {} } } })

		it('should return the value of the given key', function()
			expect(newReplion:Get('Coins')).to.equal(20)
			expect(newReplion:Get('Other.Value')).to.be.equal(newReplion.Data.Other.Value)
			expect(newReplion:Get('Invalid')).never.to.be.ok()
		end)

		it('should support table paths', function()
			expect(newReplion:Get({ 'Other', 'Value' })).to.be.equal(newReplion.Data.Other.Value)
		end)
	end)

	describe('ClientReplion:Set', function()
		local newReplion = ClientReplion.new({ nil, 'Set', { Coins = 20, Other = { Value = {} } } })

		it('should set the value of the given key', function()
			newReplion:_set('Coins', 30)

			expect(newReplion:Get('Coins')).to.equal(30)
		end)

		it('should call the OnChange signal', function()
			local called = false

			newReplion:OnChange('Coins', function()
				called = true
			end)

			newReplion:_set('Coins', 50)

			expect(called).to.equal(true)
		end)

		it('should call the OnDescendatChange signal', function()
			local called = false

			newReplion:OnDescendantChange('Other', function()
				called = true
			end)

			newReplion:_set('Other.Value', { Foo = true })

			expect(called).to.equal(true)
		end)
	end)

	describe('ClientReplion:Increase', function()
		local newReplion = ClientReplion.new({ nil, 'Increase', { Coins = 20 } })

		it('should increase the value of the given key', function()
			newReplion:_increase('Coins', 10)

			expect(newReplion:Get('Coins')).to.equal(30)
		end)
	end)

	describe('ClientReplion:Clear', function()
		local newReplion = ClientReplion.new({ nil, 'Clear', { Values = { 1, 2, 3 } } })

		it('should clear the array', function()
			newReplion:_clear('Values')

			local newValues = newReplion:Get('Values')
			expect(#newValues).to.equal(0)
		end)

		it('should call the OnChange signal', function()
			local called = false

			newReplion:_set('Values', { 1, 2, 3 })

			newReplion:OnChange('Values', function()
				called = true
			end)

			newReplion:_clear('Values')

			expect(called).to.equal(true)
		end)
	end)

	describe('ClientReplion:Insert', function()
		local newReplion = ClientReplion.new({ nil, 'Insert', { Values = {} } })

		it('should insert the value in the given array', function()
			newReplion:_insert('Values', 'Foo')
			newReplion:_insert('Values', 'Bar', 1)

			local newValues = newReplion:Get('Values')

			expect(newValues[1]).to.be.equal('Bar')
			expect(newValues[2]).to.be.equal('Foo')
		end)
	end)

	describe('ClientReplion:OnArrayInsert', function()
		local newReplion = ClientReplion.new({ nil, 'OnArrayInsert', { Values = { 1 } } })

		it('should call the callback when a value is added', function()
			local changes = {}
			newReplion:OnArrayInsert('Values', function(index: number, value: any)
				table.insert(changes, { index = index, value = value })
			end)

			newReplion:_insert('Values', 4, 2)

			expect(changes[1].index).to.be.equal(2)
			expect(changes[1].value).to.be.equal(4)

			newReplion:_insert('Values', 6, 1)

			expect(changes[2].index).to.be.equal(1)
			expect(changes[2].value).to.be.equal(6)

			expect(newReplion.Data.Values[1]).to.be.equal(6)
			expect(newReplion.Data.Values[2]).to.be.equal(1)
			expect(newReplion.Data.Values[3]).to.be.equal(4)
		end)
	end)

	describe('ClientReplion:Remove', function()
		local newReplion = ClientReplion.new({ nil, 'Remove', { Values = { 1, 2, 3 } } })

		it('should remove the value in the given array', function()
			local oneValue = newReplion:_remove('Values', 1)
			local threeValue = newReplion:_remove('Values')

			local newValues = newReplion:Get('Values')

			expect(oneValue).to.be.equal(1)
			expect(threeValue).to.be.equal(3)

			expect(#newValues).to.be.equal(1)
			expect(newValues[1]).to.be.equal(2)
		end)
	end)

	describe('ClientReplion:OnArrayRemove', function()
		local newReplion = ClientReplion.new({ nil, 'OnArrayRemove', { Values = { 1, 2, 3, 4 } } })

		it('should call the callback when a value is removed', function()
			local changes = {}
			newReplion:OnArrayRemove('Values', function(index: number, value: any)
				table.insert(changes, { index = index, value = value })
			end)

			local fourIndex = newReplion:_remove('Values', 4)

			expect(changes[1].index).to.be.equal(4)
			expect(changes[1].value).to.be.equal(fourIndex)

			local firstIndex = newReplion:_remove('Values', 1)

			expect(changes[2].index).to.be.equal(1)
			expect(changes[2].value).to.be.equal(firstIndex)

			expect(newReplion.Data.Values[1]).to.be.equal(2)
			expect(newReplion.Data.Values[2]).to.be.equal(3)
		end)
	end)

	describe('ClientReplion:OnChange', function()
		it('should call the callback when the value changes', function()
			local newReplion = ClientReplion.new({ nil, 'OnChange', { Value = 0 } })

			local new, old

			newReplion:OnChange('Value', function(newValue, oldValue)
				new, old = newValue, oldValue
			end)

			newReplion:_set('Value', 10)

			expect(new).to.be.equal(10)
			expect(old).to.be.equal(0)
		end)

		it('should call the callback if an value inside is changed', function()
			local newReplion = ClientReplion.new({ nil, 'OnChangeTable', { Value = { Test = true } } })

			local called: number = 0
			newReplion:OnChange('Value', function()
				called += 1
			end)

			newReplion:_set('Value.Test', false)
			newReplion:_set('Value.Test', { Foo = false })
			newReplion:_set('Value.Test.Foo', true)

			expect(called).to.be.equal(3)
		end)
	end)

	describe('ClientReplion:OnDescendantChanged', function()
		local newReplion =
			ClientReplion.new({ nil, 'OnDescendantChanged', { Values = { A = true, B = false, C = { D = true } } } })

		it('should call the callback when the value changes', function()
			local changes = {}

			newReplion:OnDescendantChange('Values', function(path, newValue, oldValue)
				table.insert(changes, { path = path, newValue = newValue, oldValue = oldValue })
			end)

			newReplion:_set('Values.A', false)
			newReplion:_set('Values.B', true)
			newReplion:_set('Values.C.D', false)

			expect(changes[1].newValue).to.be.equal(false)
			expect(changes[1].oldValue).to.be.equal(true)
			expect(table.concat(changes[1].path, '.')).to.be.equal('Values.A')

			expect(changes[2].newValue).to.be.equal(true)
			expect(changes[2].oldValue).to.be.equal(false)
			expect(table.concat(changes[2].path, '.')).to.be.equal('Values.B')

			expect(changes[3].newValue).to.be.a('table')
			expect(changes[3].oldValue).to.be.a('table')

			expect(changes[3].newValue.D).to.be.equal(false)
			expect(changes[3].oldValue.D).to.be.equal(true)
		end)
	end)

	describe('ClientReplion:Update', function()
		local newReplion = ClientReplion.new({ nil, 'Update', { Values = {}, ToBeRemoved = true } })

		it('should call the OnChange event', function()
			local newValues, oldValues
			newReplion:OnChange('Values', function(newValue, oldValue)
				newValues = newValue
				oldValues = oldValue
			end)

			local barNew, barOld
			newReplion:OnChange('Other.Bar', function(newValue, oldValue)
				barNew = newValue
				barOld = oldValue
			end)

			newReplion:_update({ Values = { 1, 2, 3 } })
			newReplion:_update('Other', { Bar = false })

			expect(barNew).to.be.equal(false)
			expect(barOld).never.to.be.ok()

			expect(newValues).to.be.a('table')
			expect(#newValues).to.be.equal(3)
			expect(#oldValues).to.be.equal(0)
		end)

		it('should set new values', function()
			newReplion:_update({ Coins = 20, Gems = 100, IsVip = true })

			expect(newReplion:Get('Coins')).to.be.equal(20)
			expect(newReplion:Get('Gems')).to.be.equal(100)
			expect(newReplion:Get('IsVip')).to.be.equal(true)
		end)

		it('should remove values with the None symbol', function()
			newReplion:_update({ ToBeRemoved = Utils.SerializedNone })

			expect(newReplion:Get('ToBeRemoved')).to.be.never.ok()
		end)
	end)
end
