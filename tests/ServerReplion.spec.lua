--!nonstrict
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Replion = require(ReplicatedStorage.Packages.Replion)

local ReplionServer = Replion.Server

return function()
	describe('ServerReplion.new', function()
		it('should create a new ReplionServer', function()
			local newReplion = ReplionServer.new({
				Data = {},
				Channel = 'serverNew',
				ReplicateTo = 'All',
			})

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
	end)

	describe('ServerReplion:_serialize', function()
		local newReplion = ReplionServer.new({
			Data = {},
			Channel = '_serialize',
			ReplicateTo = 'All',
			Tags = { 'Foo' },
		})

		it('should serialize the Replion', function()
			local serialized = newReplion:_serialize()

			expect(serialized).to.be.a('table')
			expect(serialized[1]).to.be.a('string')
			expect(serialized[2]).to.be.equal('_serialize')
			expect(serialized[3]).to.be.a('table')
			expect(serialized[4]).to.be.a('string')
		end)
	end)

	describe('ServerReplion:BeforeDestroy', function()
		it('should fire when the Replion is destroyed', function()
			local newReplion = ReplionServer.new({
				Data = {},
				Channel = 'BeforeDestroy',
				ReplicateTo = 'All',
			})

			local fired = false
			newReplion:BeforeDestroy(function()
				fired = true
			end)

			newReplion:Destroy()

			expect(fired).to.equal(true)
		end)
	end)

	describe('ServerReplion:Destroy', function()
		it('should error when using a destroyed replion', function()
			expect(function()
				local newReplion = ReplionServer.new({
					Data = { Foo = false },
					Channel = 'Destroy',
					ReplicateTo = 'All',
				})

				newReplion:Destroy()

				newReplion:Set('Foo', true)
			end).to.throw("You're trying to use a Replion that has been destroyed")
		end)

		it('should mark the Replion as destroyed', function()
			local newReplion = ReplionServer.new({
				Data = {},
				Channel = 'Destroyed',
				ReplicateTo = 'All',
			})

			newReplion:Destroy()

			expect(newReplion.Destroyed).to.equal(true)
		end)

		it('should disconnect signals', function()
			local newReplion = ReplionServer.new({
				Data = {},
				Channel = 'SignalDisconnect',
				ReplicateTo = 'All',
			})

			local conn = newReplion:OnChange('Foo', print)

			newReplion:Destroy()

			expect(conn.Connected).to.be.equal(false)
		end)
	end)

	describe('ServerReplion:Get', function()
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

	describe('ServerReplion:GetExpect', function()
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

	describe('ServerReplion:Set', function()
		local newReplion = ReplionServer.new({
			Data = { Coins = 20, Other = { Value = {} } },
			Channel = 'Set',
			ReplicateTo = 'All',
		})

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

	describe('ServerReplion:SetReplicateTo', function()
		local newReplion = ReplionServer.new({
			Data = { Coins = 20, Other = { Value = {} } },
			Channel = 'SetReplicateTo',
			ReplicateTo = 'All',
		})

		it('should change the ReplicateTo', function()
			local newReplicateTo = {}

			newReplion:SetReplicateTo(newReplicateTo)

			expect(newReplion.ReplicateTo).to.be.equal(newReplicateTo)
		end)

		it('should error if the ReplicateTo is not valid', function()
			expect(function()
				newReplion:SetReplicateTo('Invalid')
			end).to.throw()
		end)
	end)

	describe('ServerReplion:Clear', function()
		local newReplion = ReplionServer.new({
			Data = { Values = { 1, 2, 3 } },
			Channel = 'Clear',
			ReplicateTo = 'All',
		})

		it('should clear the array', function()
			newReplion:Clear('Values')

			local newValues = newReplion:Get('Values')
			print(newValues)
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

	describe('ServerReplion:Increase', function()
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

	describe('ServerReplion:Insert', function()
		local newReplion = ReplionServer.new({
			Data = { Values = {} },
			Channel = 'Insert',
			ReplicateTo = 'All',
		})

		it('should insert the value in the given array', function()
			newReplion:Insert('Values', 'Foo')
			newReplion:Insert('Values', 'Bar', 1)

			local newValues = newReplion:Get('Values')

			expect(newValues[1]).to.be.equal('Bar')
			expect(newValues[2]).to.be.equal('Foo')
		end)
	end)

	describe('ServerReplion:OnArrayInsert', function()
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

	describe('ServerReplion:Remove', function()
		local newReplion = ReplionServer.new({
			Data = { Values = { 1, 2, 3 } },
			Channel = 'Remove',
			ReplicateTo = 'All',
		})

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

	describe('ServerReplion:OnArrayRemove', function()
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

	describe('ServerReplion:OnChange', function()
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
			newReplion:Set('Value.Test', { Foo = false })
			newReplion:Set('Value.Test.Foo', true)

			expect(called).to.be.equal(3)
		end)
	end)

	describe('ServerReplion:OnDescendantChange', function()
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

			expect(changes[3].newValue).to.be.a('table')
			expect(changes[3].oldValue).to.be.a('table')

			expect(changes[3].newValue.D).to.be.equal(false)
			expect(changes[3].oldValue.D).to.be.equal(true)
		end)
	end)

	describe('ServerReplion:Update', function()
		local newReplion = ReplionServer.new({
			Data = { Values = {}, ToBeRemoved = true, Other = {} },
			Channel = 'Update',
			ReplicateTo = 'All',
		})

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

			newReplion:Update({ Values = { 1, 2, 3 } })
			newReplion:Update('Other', { Bar = false })

			expect(barNew).to.be.equal(false)
			expect(barOld).never.to.be.ok()

			expect(newValues).to.be.a('table')
			expect(#newValues).to.be.equal(3)
			expect(#oldValues).to.be.equal(0)
		end)

		it('should set new values', function()
			newReplion:Update({ Coins = 20, Gems = 100, IsVip = true })

			expect(newReplion:Get('Coins')).to.be.equal(20)
			expect(newReplion:Get('Gems')).to.be.equal(100)
			expect(newReplion:Get('IsVip')).to.be.equal(true)
		end)

		it('should remove values with the None symbol', function()
			newReplion:Update({ ToBeRemoved = Replion.None })

			expect(newReplion:Get('ToBeRemoved')).to.be.never.ok()
		end)
	end)
end
