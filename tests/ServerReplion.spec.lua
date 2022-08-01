--!nonstrict
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Replion = require(ReplicatedStorage.Packages.Replion)

local ReplionServer = Replion.Server

return function()
	describe('ReplionServer.new', function()
		local newReplion = ReplionServer.new({
			Data = {},
			Channel = 'new',
			ReplicateTo = 'All',
		})

		it('should create a new ReplionServer', function()
			expect(newReplion).to.be.ok()
		end)

		it('should error if no Channel is provided', function()
			expect(function()
				ReplionServer.new({
					Data = {},
					ReplicateTo = 'All',
				})
			end).to.throw()
		end)

		it('should have a nice tostring', function()
			expect(tostring(newReplion)).to.be.equal('Replion<new:All>')
		end)

		it('should be serialized', function()
			local serialized = newReplion:_serialize()

			expect(serialized).to.be.ok()
			expect(serialized.Data).to.be.a('table')
			expect(serialized.Channel).to.be.a('string')
		end)
	end)

	describe('ReplionServer:Get', function()
		local newReplion = ReplionServer.new({
			Data = { Coins = 20, Other = { Value = {} } },
			Channel = 'Get',
			ReplicateTo = 'All',
		})

		it('should return the value of the given key', function()
			expect(newReplion:Get('Coins')).to.equal(20)
			expect(newReplion:Get('Other.Value')).to.be.equal(newReplion.Data.Other.Value)
			expect(newReplion:Get('Invalid')).never.to.be.ok()
		end)

		it('should support table paths', function()
			expect(newReplion:Get({ 'Other', 'Value' })).to.be.equal(newReplion.Data.Other.Value)
		end)
	end)

	describe('ReplionServer:GetExpect', function()
		local newReplion = ReplionServer.new({
			Data = { Coins = 20, Other = { Value = {} } },
			Channel = 'GetExpect',
			ReplicateTo = 'All',
		})

		it('should return the value of the given key', function()
			expect(newReplion:GetExpect('Coins')).to.equal(20)
			expect(newReplion:GetExpect('Other.Value')).to.be.equal(newReplion.Data.Other.Value)
		end)

		it('should error if the value does not exist', function()
			expect(function()
				newReplion:GetExpect('Invalid')
			end).to.throw()
		end)

		it('should support table paths', function()
			expect(newReplion:Get({ 'Other', 'Value' })).to.be.equal(newReplion.Data.Other.Value)
		end)
	end)

	describe('ReplionServer:Set', function()
		local newReplion = ReplionServer.new({
			Data = { Coins = 20, Other = { Value = {} } },
			Channel = 'Set',
			ReplicateTo = 'All',
		})

		it('should set the value of the given key', function()
			newReplion:Set('Coins', 30)

			expect(newReplion:Get('Coins')).to.equal(30)
		end)
	end)

	describe('ReplionServer:SetReplicateTo', function()
		local newReplion = ReplionServer.new({
			Data = { Coins = 20, Other = { Value = {} } },
			Channel = 'SetReplicateTo',
			ReplicateTo = 'All',
		})

		it('should change the ReplicateTo', function()
			local newReplicateTo = {}

			newReplion:SetReplicateTo(newReplicateTo)

			expect(newReplion._replicateTo).to.be.equal(newReplicateTo)
		end)

		it('should error if the ReplicateTo is not valid', function()
			expect(function()
				newReplion:SetReplicateTo('Invalid')
			end).to.throw()
		end)
	end)

	describe('ReplionServer:Increase', function()
		local newReplion = ReplionServer.new({
			Data = { Coins = 20 },
			Channel = 'Increase',
			ReplicateTo = 'All',
		})

		it('should increase the value of the given key', function()
			newReplion:Increase('Coins', 10)

			expect(newReplion:Get('Coins')).to.equal(30)
		end)

		it('should error if the value is not a number', function()
			expect(function()
				newReplion:Increase('Coins', 'Invalid')
			end).to.throw()
		end)
	end)

	describe('ReplionServer:Insert', function()
		local newReplion = ReplionServer.new({
			Data = { Values = {} },
			Channel = 'Insert',
			ReplicateTo = 'All',
		})

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

	describe('ReplionServer:OnArrayInsert', function()
		local newReplion = ReplionServer.new({
			Data = { Values = { 1 } },
			Channel = 'OnArrayInsert',
			ReplicateTo = 'All',
		})

		it('should call the callback when a value is added', function()
			local changes = {}
			newReplion:OnArrayInsert('Values', function(index: number, value: any)
				table.insert(changes, { index = index, value = value })
			end)

			newReplion:Insert('Values', 4)

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

	describe('ReplionServer:OnArrayRemove', function()
		local newReplion = ReplionServer.new({
			Data = { Values = { 1, 2, 3, 4 } },
			Channel = 'OnArrayRemove',
			ReplicateTo = 'All',
		})

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

	describe('ReplionServer:OnChange', function()
		it('should call the callback when the value changes', function()
			local newReplion = ReplionServer.new({
				Data = { Value = 0 },
				Channel = 'OnChange',
				ReplicateTo = 'All',
			})

			local new, old

			newReplion:OnChange('Value', function(newValue, oldValue)
				new, old = newValue, oldValue
			end)

			newReplion:Set('Value', 10)

			expect(new).to.be.equal(10)
			expect(old).to.be.equal(0)
		end)

		it('should call the callback if an value inside is changed', function()
			local newReplion = ReplionServer.new({
				Data = { Value = { Test = true } },
				Channel = 'OnChangeTable',
				ReplicateTo = 'All',
			})

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

	describe('ReplionServer:OnDescendantChanged', function()
		local newReplion = ReplionServer.new({
			Data = { Values = { A = true, B = false, C = { D = true } } },
			Channel = 'OnDescendantChanged',
			ReplicateTo = 'All',
		})

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

	describe('ReplionServer:Update', function()
		local newReplion = ReplionServer.new({
			Data = { Values = {}, ToBeRemoved = true },
			Channel = 'Update',
			ReplicateTo = 'All',
		})

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
			local returnedValue = newReplion:Update({ ToBeRemoved = Replion.None })

			expect(returnedValue.ToBeRemoved).to.be.never.ok()
		end)
	end)

	describe('ReplionServer:Execute', function()
		local newReplion = ReplionServer.new({
			Data = { Items = {} },
			Channel = 'Execute',
			ReplicateTo = 'All',
			Extensions = script.Parent.Extensions,
		})

		it('should not call the events', function()
			local wasCalled = false

			newReplion:OnDescendantChange('Items', function()
				wasCalled = true
			end)

			newReplion:Execute('AddItem', 'Sword')

			expect(wasCalled).to.be.equal(false)
		end)

		it('should return the extensions values', function()
			local wasAdded = newReplion:Execute('AddItem', 'Bow')

			expect(wasAdded).to.be.equal(true)
		end)
	end)
end
