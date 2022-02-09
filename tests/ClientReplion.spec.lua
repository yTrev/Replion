local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Packages = ReplicatedStorage:FindFirstChild('Packages')
local Replion = Packages.Replion

local ClientReplion = require(Replion.ReplionController.ClientReplion)

return function()
	local newReplion = ClientReplion.new({
		Value = 'Foo',

		ValueA = {
			ValueB = {
				ValueD = 10,
			},

			ValueC = 'Bar',
			OtherValue = true,
		},
	}, { 'Foo' })

	describe('ClientReplion:OnUpdate', function()
		it('should return a connection', function()
			local conn = newReplion:OnUpdate('ValueA.ValueB', function() end)

			expect(conn).to.be.a('table')
			expect(conn.Disconnect).to.be.a('function')

			conn:Disconnect()
		end)
	end)

	describe('ClientReplion:Get', function()
		it('should return the value', function()
			expect(newReplion:Get('Value')).to.be.equal('Foo')
			expect(newReplion:Get('ValueA.ValueB.ValueD')).to.be.equal(10)
		end)
	end)

	describe('ClientReplion:GetCopy', function()
		it('should return a copy of the value', function()
			local valueA = newReplion:GetCopy('ValueA')

			expect(valueA ~= newReplion:Get('ValueA')).to.be.equal(true)
		end)
	end)

	describe('ClientReplion:BeforeDestroy', function()
		local beforeDestroyReplion = ClientReplion.new({})

		it('should fire the BeforeDestroy event', function()
			local called
			local conn = beforeDestroyReplion:BeforeDestroy(function()
				called = true
			end)

			expect(conn.Connected).to.be.equal(true)

			beforeDestroyReplion:Destroy()

			expect(called).to.be.equal(true)
			expect(conn.Connected).to.be.equal(false)
		end)
	end)
end
