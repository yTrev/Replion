local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Packages = ReplicatedStorage:FindFirstChild('Packages')
local Replion = Packages.Replion

local ClientReplion = require(Replion.ReplionController.ClientReplion)
local ClientMethods = require(Replion.ReplionController.ClientMethods)

return function()
	describe('update', function()
		local newReplion = ClientReplion.new({
			Value = 'Foo',

			ValueA = {
				ValueB = {
					ValueD = 10,
				},

				ValueC = 'Bar',
				OtherValue = true,
			},
		})

		it('should update only the values passed', function()
			ClientMethods.update(newReplion, 'ValueA', {
				ValueC = 'Foo',
				ValueE = 100,
			})

			expect(newReplion:Get('ValueA.ValueC')).to.be.equal('Foo')
			expect(newReplion:Get('ValueA.ValueE')).to.be.equal(100)
			expect(newReplion:Get('ValueA.ValueB.ValueD')).to.be.equal(10)
			expect(newReplion:Get('ValueA.OtherValue')).to.be.equal(true)
		end)

		it('values should be immutable', function()
			local oldValue = newReplion:Get('ValueA.ValueB')

			ClientMethods.update(newReplion, 'ValueA.ValueB', {
				ValueD = 'Foo',
			})

			expect(newReplion:Get('ValueA.ValueB') ~= oldValue).to.be.equal(true)
		end)

		it('should fire the OnUpdate event', function()
			local eventAction, valueE, valueEOld

			local conn = newReplion:OnUpdate('ValueA.ValueB', function(action, newValue, oldValue, path: { string })
				eventAction = action

				valueE = newValue.ValueE
				valueEOld = oldValue.ValueE
				valuePath = path
			end)

			ClientMethods.update(newReplion, 'ValueA.ValueB', {
				ValueE = 'Foo',
			})

			expect(eventAction).to.be.a('table')
			expect(valueE).to.be.equal('Foo')
			expect(valueEOld).to.be.equal(nil)

			conn:Disconnect()
		end)
	end)

	describe('set', function()
		local newReplion = ClientReplion.new({
			Value = 'Foo',

			ValueA = {
				OtherValue = true,
			},
		})

		it('should set the value', function()
			local oldValue = newReplion:Get('Value')

			ClientMethods.set(newReplion, 'Value', 'Bar')

			expect(oldValue).to.be.equal('Foo')
			expect(newReplion:Get('Value')).to.be.equal('Bar')
		end)

		it('values should be immutable', function()
			local oldValue = newReplion:Get('ValueA')

			ClientMethods.set(newReplion, 'ValueA.OtherValue', false)

			expect(oldValue ~= newReplion:Get('ValueA')).to.be.equal(true)
		end)

		it('should fire the OnUpdate event', function()
			local eventAction, valueB, valueBOld

			local conn = newReplion:OnUpdate('ValueA.ValueB', function(action, newValue, oldValue)
				eventAction = action

				valueB = newValue
				valueBOld = oldValue
			end)

			ClientMethods.set(newReplion, 'ValueA.ValueB', {
				ValueE = 'Foo',
			})

			expect(eventAction).to.be.a('table')
			expect(valueB).to.be.a('table')
			expect(valueB.ValueE).to.be.equal('Foo')
			expect(valueBOld).to.be.equal(nil)

			conn:Disconnect()
		end)
	end)

	describe('insert', function()
		local newReplion = ClientReplion.new({
			Values = {},
		})

		it('should insert the value', function()
			ClientMethods.insert(newReplion, 'Values', 1, 'Foo')

			local newValue = newReplion:Get('Values')

			expect(newValue).to.be.a('table')
			expect(newValue[1]).to.be.equal('Foo')
		end)

		it('values should be immutable', function()
			local oldValue = newReplion:Get('Values')

			ClientMethods.insert(newReplion, 'Values', 2, 'Bar')

			expect(oldValue ~= newReplion:Get('Values')).to.be.equal(true)
		end)

		it('should fire the OnUpdate event', function()
			local eventAction, valueIndex, newValue

			local conn = newReplion:OnUpdate('Values', function(action, index, value)
				eventAction = action

				valueIndex = index
				newValue = value
			end)

			ClientMethods.insert(newReplion, 'Values', 3, 'Bar')

			expect(eventAction).to.be.a('table')
			expect(eventAction.Name).to.be.equal('Added')

			expect(valueIndex).to.be.equal(3)
			expect(newValue).to.be.equal('Bar')

			conn:Disconnect()
		end)
	end)

	describe('remove', function()
		local newReplion = ClientReplion.new({
			Values = {
				'Foo',
				'Bar',
				'Baz',
			},

			OtherValues = {
				'Foo',
				'Bar',
			},
		})

		it('should remove the value', function()
			ClientMethods.remove(newReplion, 'Values', 1)

			local newValue = newReplion:Get('Values')

			expect(newValue).to.be.a('table')
			expect(newValue[1]).to.be.equal('Bar')
			expect(newValue[2]).to.be.equal('Baz')
		end)

		it('values should be immutable', function()
			local oldValue = newReplion:Get('Values')

			ClientMethods.remove(newReplion, 'Values', 1)

			expect(oldValue ~= newReplion:Get('Values')).to.be.equal(true)
		end)

		it('should fire the OnUpdate event', function()
			local eventAction, valueIndex, newValue

			local conn = newReplion:OnUpdate('OtherValues', function(action, index, value)
				eventAction = action

				valueIndex = index
				newValue = value
			end)

			ClientMethods.remove(newReplion, 'OtherValues', 1)

			expect(eventAction).to.be.a('table')
			expect(eventAction.Name).to.be.equal('Removed')

			expect(valueIndex).to.be.equal(1)
			expect(newValue).to.be.equal('Foo')

			conn:Disconnect()
		end)
	end)

	describe('clear', function()
		local newReplion = ClientReplion.new({
			Values = {
				'Foo',
				'Bar',
				'Baz',
			},

			OtherValues = {
				'Foo',
				'Bar',
			},
		})

		it('should clear the array', function()
			ClientMethods.clear(newReplion, 'Values')

			local newValue = newReplion:Get('Values')

			expect(newValue).to.be.a('table')
			expect(#newValue).to.be.equal(0)
		end)

		it('values should be immutable', function()
			local oldValue = newReplion:Get('Values')

			ClientMethods.clear(newReplion, 'Values')

			expect(oldValue ~= newReplion:Get('Values')).to.be.equal(true)
		end)

		it('should fire the OnUpdate event', function()
			local eventAction, eventOld

			local conn = newReplion:OnUpdate('OtherValues', function(action, oldValue)
				eventAction = action

				eventOld = oldValue
			end)

			ClientMethods.clear(newReplion, 'OtherValues')

			expect(eventAction).to.be.a('table')
			expect(eventAction.Name).to.be.equal('Cleared')

			expect(eventOld).to.be.a('table')
			expect(eventOld[1]).to.be.equal('Foo')
			expect(eventOld[2]).to.be.equal('Bar')

			conn:Disconnect()
		end)
	end)
end
