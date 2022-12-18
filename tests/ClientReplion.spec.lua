--!nonstrict
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Utils = require(ReplicatedStorage.Packages.Replion.Internal.Utils)
local ClientReplion = require(ReplicatedStorage.Packages.Replion.Client.ClientReplion)

return function()
	describe('ClientReplion.new', function()
		local newReplion = ClientReplion.new({ nil, 'new', { Coins = 20 } })

		it('should return a Replion', function()
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
			newReplion:Set('Coins', 30)

			expect(newReplion:Get('Coins')).to.equal(30)
		end)

		it('should call the OnChange signal', function()
			local called = false

			newReplion:OnChange('Coins', function()
				called = true
			end)

			newReplion:Set('Coins', 50)

			expect(called).to.equal(true)
		end)

		it('should call the OnDescendatChange signal', function()
			local called = false

			newReplion:OnDescendantChange('Other', function()
				called = true
			end)

			newReplion:Set('Other.Value', { Foo = true })

			expect(called).to.equal(true)
		end)
	end)

	describe('ClientReplion:Increase', function()
		local newReplion = ClientReplion.new({ nil, 'Increase', { Coins = 20 } })

		it('should increase the value of the given key', function()
			newReplion:Increase('Coins', 10)

			expect(newReplion:Get('Coins')).to.equal(30)
		end)
	end)

	describe('ClientReplion:Clear', function()
		local newReplion = ClientReplion.new({ nil, 'Clear', { Values = { 1, 2, 3 } } })

		it('should clear the array', function()
			newReplion:Clear('Values')

			local newValues = newReplion:Get('Values')
			expect(#newValues).to.equal(0)
		end)

		it('should call the OnChange signal', function()
			local called = false

			newReplion:Set('Values', { 1, 2, 3 })

			newReplion:OnChange('Values', function()
				called = true
			end)

			newReplion:Clear('Values')

			expect(called).to.equal(true)
		end)
	end)

	describe('ClientReplion:Insert', function()
		local newReplion = ClientReplion.new({ nil, 'Insert', { Values = {} } })

		it('should insert the value in the given array', function()
			local fooIndex, fooValue = newReplion:Insert('Values', 'Foo')
			local barIndex, barValue = newReplion:Insert('Values', 'Bar', 1)

			local newValues = newReplion:Get('Values')

			expect(fooIndex).to.be.equal(1)
			expect(fooValue).to.be.equal('Foo')

			expect(barIndex).to.be.equal(1)
			expect(barValue).to.be.equal('Bar')

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

			newReplion:Insert('Values', 4, 2)

			expect(changes[1].index).to.be.equal(2)
			expect(changes[1].value).to.be.equal(4)

			newReplion:Insert('Values', 6, 1)

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
			local oneValue = newReplion:Remove('Values', 1)
			local threeValue = newReplion:Remove('Values')

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

			local fourIndex = newReplion:Remove('Values', 4)

			expect(changes[1].index).to.be.equal(4)
			expect(changes[1].value).to.be.equal(fourIndex)

			local firstIndex = newReplion:Remove('Values', 1)

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

			newReplion:Set('Value', 10)

			expect(new).to.be.equal(10)
			expect(old).to.be.equal(0)
		end)

		it('should call the callback if an value inside is changed', function()
			local newReplion = ClientReplion.new({ nil, 'OnChangeTable', { Value = { Test = true } } })

			local called: number = 0

			newReplion:OnChange('Value', function()
				called += 1
			end)

			newReplion:Set('Value.Test', false)

			expect(called).to.be.equal(1)

			newReplion:Set('Value.Test', { Foo = false })

			expect(called).to.be.equal(2)

			newReplion:Set('Value.Test.Foo', true)

			expect(called).to.be.equal(2)
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

			newReplion:Set('Values.A', false)
			newReplion:Set('Values.B', true)
			newReplion:Set('Values.C.D', false)

			expect(changes[1].newValue).to.be.equal(false)
			expect(changes[1].oldValue).to.be.equal(true)
			expect(table.concat(changes[1].path, '.')).to.be.equal('Values.A')

			expect(changes[2].newValue).to.be.equal(true)
			expect(changes[2].oldValue).to.be.equal(false)
			expect(table.concat(changes[2].path, '.')).to.be.equal('Values.B')

			expect(changes[3].newValue).to.be.equal(false)
			expect(changes[3].oldValue).to.be.equal(true)
			expect(table.concat(changes[3].path, '.')).to.be.equal('Values.C.D')
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

			local returnedValue = newReplion:Update({ Values = { 1, 2, 3 } })

			expect(newValues[1]).to.be.equal(returnedValue.Values[1])
			expect(newValues[2]).to.be.equal(returnedValue.Values[2])
			expect(newValues[3]).to.be.equal(returnedValue.Values[3])

			expect(oldValues[1]).to.be.equal(nil)
			expect(oldValues[2]).to.be.equal(nil)
			expect(oldValues[3]).to.be.equal(nil)
		end)

		it('should set new values', function()
			local returnedValue = newReplion:Update({ Coins = 20, Gems = 100, IsVip = true })

			expect(returnedValue.Coins).to.be.equal(20)
			expect(returnedValue.Gems).to.be.equal(100)
			expect(returnedValue.IsVip).to.be.equal(true)

			expect(newReplion.Data.Coins).to.be.equal(returnedValue.Coins)
			expect(newReplion.Data.Gems).to.be.equal(returnedValue.Gems)
			expect(newReplion.Data.IsVip).to.be.equal(returnedValue.IsVip)
		end)

		it('should remove values with the None symbol', function()
			local returnedValue = newReplion:Update({ ToBeRemoved = Utils.SerializedNone })

			expect(returnedValue.ToBeRemoved).to.be.never.ok()
		end)
	end)
end
