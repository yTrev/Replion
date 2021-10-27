local ReplicatedStorage = game:GetService('ReplicatedStorage')

return function()
	local Replion = require(ReplicatedStorage:FindFirstChild('Replion'))
	Replion.TESTING = true

	local testWriteLib = {
		AddCoins = function(replion: any, amount: number)
			replion:Increase('Coins', amount)
		end,
	}

	local newReplion = Replion.new({
		Player = {
			Name = 'JohnDoe',
		},

		WriteLib = testWriteLib,

		Data = {
			Test = true,
			OtherValue = true,
			Values = {
				A = false,
				B = true,
				C = false,
			},

			Others = {
				A = true,
				B = true,
			},

			Coins = 0,
		},
	})

	describe('Replion.new', function()
		it('should error if no player is passed', function()
			expect(function()
				Replion.new(nil, {})
			end).to.throw()
		end)

		it('should error if no data is passed', function()
			local otherPlayer = {
				Name = 'Player1',
			}

			expect(function()
				Replion.new(otherPlayer, nil)
			end).to.throw()
		end)
	end)

	describe('Replion:Set', function()
		it("should error if the value doesn't change", function()
			expect(function()
				newReplion:Set('Test', true)
			end).to.throw()
		end)

		it('should change values', function()
			newReplion:Set('OtherValue', false)
			expect(newReplion.Data.OtherValue).to.be.equal(false)
		end)

		it('should return valid actions', function()
			local actions: { string } = {}
			local connection = newReplion:OnUpdate('Others', function(action: string)
				table.insert(actions, action)
			end)

			newReplion:Set('Others.A', nil)
			newReplion:Set('Others.B', false)
			newReplion:Set('Others.C', true)

			expect(actions[1]).to.be.equal('Removed')
			expect(actions[2]).to.be.equal('Changed')
			expect(actions[3]).to.be.equal('Added')

			connection:Disconnect()
		end)
	end)

	describe('Replion:OnUpdate', function()
		it("should error if path isn't a string", function()
			expect(function()
				newReplion:OnUpdate(1, function() end)
			end).to.throw()
		end)

		it("should error if callback isn't a function", function()
			expect(function()
				newReplion:OnUpdate('Test')
			end).to.throw()
		end)

		it('should return a Connection', function()
			local connectionA = newReplion:OnUpdate('Test', function() end)
			local connectionB = newReplion:OnUpdate({ 'Test' }, function() end)

			expect(connectionA).to.be.a('table')
			expect(connectionA).to.be.a('table')

			connectionA:Disconnect()
			connectionB:Disconnect()
		end)

		it('should be fired', function()
			local value

			local connection = newReplion:OnUpdate('Test', function(_action, newValue: boolean)
				value = newValue
			end)

			newReplion:Set('Test', false)

			expect(value).to.be.equal(false)

			connection:Disconnect()
		end)
	end)

	describe('Replion:Update', function()
		it('should update the keys', function()
			newReplion:Update('Values', {
				A = true,
				B = false,
			})

			expect(newReplion.Data.Values.A).to.be.equal(true)
			expect(newReplion.Data.Values.B).to.be.equal(false)
			expect(newReplion.Data.Values.C).to.be.equal(false)
		end)
	end)

	describe('Replion:Get', function()
		it('should return the value', function()
			expect(newReplion:Get('Values.A')).to.be.equal(newReplion.Data.Values.A)
			expect(newReplion:Get('Values')).to.be.equal(newReplion.Data.Values)
		end)
	end)

	describe('Replion:Increase', function()
		it('should increase the value', function()
			local targetValue: number = newReplion.Data.Coins + 10
			newReplion:Increase('Coins', 10)

			expect(newReplion.Data.Coins).to.be.equal(targetValue)
		end)

		it('should return the result', function()
			local newValue: number = newReplion:Increase('Coins', 10)
			expect(newReplion.Data.Coins).to.be.equal(newValue)
		end)

		it("should error when the values isn't a number", function()
			expect(function()
				newReplion:Increase('Test', 10)
			end).to.throw()
		end)
	end)

	describe('Replion:Decrease', function()
		it('should decrease the value', function()
			local targetValue: number = newReplion.Data.Coins - 10
			newReplion:Decrease('Coins', 10)

			expect(newReplion.Data.Coins).to.be.equal(targetValue)
		end)
	end)

	it('should have a tostring', function()
		expect(string.match(tostring(newReplion), 'Replion<.+>')).to.be.ok()
	end)

	describe('Replion:Write', function()
		it("should error if the write function doesn't exist", function()
			expect(function()
				newReplion:Write('RandomStuff', 20)
			end).to.throw()
		end)

		it('should update the values', function()
			local oldCoins = newReplion:Get('Coins')

			newReplion:Write('AddCoins', 20)

			expect(newReplion:Get('Coins')).to.be.equal(oldCoins + 20)
		end)
	end)
end
