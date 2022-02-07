local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Packages = ReplicatedStorage:FindFirstChild('Packages')
local Replion = Packages.Replion

local ReplionService = require(Replion)
local Network = require(Replion.ReplionService.Network)
Network.Testing = true

return function()
	describe('Replion.new', function()
		it('should error if invalid params are passed', function()
			expect(function()
				ReplionService.new({})
			end).to.be.throw()
		end)

		it('should create a new Replion', function()
			local newReplion = ReplionService.new({
				Player = { Name = 'John', UserId = 1 },
				Name = 'Test',
				Data = {
					test = 'test',
					test2 = 'test2',
				},
			})

			expect(newReplion).to.be.ok()

			newReplion:Destroy()
		end)
	end)

	local basePlayer = {
		Name = 'John',
		UserId = 1,
	}

	local baseReplion = ReplionService.new({
		Player = basePlayer,
		Name = 'Base',
		Data = {
			Coins = 0,
		},

		Extensions = {
			AddCoins = function(replion, amount: number)
				replion:Increase('Coins', amount)
			end,
		},
	})

	describe('Replion:Execute', function()
		it('should error if the replion does not have extensions', function()
			local replionWithoutExtensions = ReplionService.new({
				Player = basePlayer,
				Name = 'NoExtensions',
				Data = {},
			})

			expect(function()
				replionWithoutExtensions:Execute('AddCoins', 100)
			end).to.be.throw('has no extensions')

			replionWithoutExtensions:Destroy()
		end)

		it('should error if the replion does not have an extension', function()
			expect(function()
				baseReplion:Execute('RemoveCoins', 100)
			end).to.be.throw('has no extension named "RemoveCoins"')
		end)

		it('should execute the extension', function()
			local coins = baseReplion:Get('Coins')

			baseReplion:Execute('AddCoins', 100)

			expect(baseReplion:Get('Coins')).to.be.equal(coins + 100)
		end)

		it('Replion:Write should be valid', function()
			expect(baseReplion.Write).to.be.an('function')
		end)
	end)

	describe('Replion:OnUpdate', function()
		local newReplion = ReplionService.new({
			Player = basePlayer,
			Name = 'OnUpdate',
			Data = {
				A = 20,
				Array = {},
			},
		})

		it('should error if the path is not valid', function()
			expect(function()
				baseReplion:OnUpdate(1)
			end).to.be.throw('bad type for union')
		end)

		it('should error if the callback is not a function', function()
			expect(function()
				baseReplion:OnUpdate('foo')
			end).to.be.throw('function expected')
		end)

		it('should be called when the replion is updated', function()
			local isUpdated
			newReplion:OnUpdate('A', function()
				isUpdated = true
			end)

			newReplion:Set('A', 30)

			expect(isUpdated).to.be.ok()
		end)

		it('when a array is updated it whould pass the index and the value', function()
			local index, value
			newReplion:OnUpdate('Array', function(_action, i, v)
				index = i
				value = v
			end)

			newReplion:Insert('Array', 'foo')

			expect(index).to.be.equal(1)
			expect(value).to.be.equal('foo')
		end)
	end)

	describe('Replion:BeforeDestroy', function()
		it('should error if the callback is not a function', function()
			expect(function()
				baseReplion:BeforeDestroy('foo')
			end).to.be.throw('function expected')
		end)

		it('should be called before the replion is destroyed', function()
			local newReplion = ReplionService.new({
				Player = basePlayer,
				Name = 'BeforeDestroy',
				Data = {},
			})

			local isDestroyed

			newReplion:BeforeDestroy(function()
				isDestroyed = newReplion.Destroyed
			end)

			newReplion:Destroy()

			expect(isDestroyed).never.to.be.ok()
		end)
	end)

	describe('Replion:Set', function()
		it('should error if the path is not valid', function()
			expect(function()
				baseReplion:Set(1, 'foo')
			end).to.be.throw('bad type for union')
		end)

		it('should set the value', function()
			local newReplion = ReplionService.new({
				Player = basePlayer,
				Name = 'Set',
				Data = {
					A = 20,
				},
			})

			newReplion:Set('A', 30)

			expect(newReplion:Get('A')).to.be.equal(30)
		end)
	end)

	describe('Replion:Update', function()
		it('should error if the path is not valid', function()
			expect(function()
				baseReplion:Update(1, 'foo')
			end).to.be.throw('bad type for union')
		end)

		it('should update the values', function()
			local newReplion = ReplionService.new({
				Player = basePlayer,
				Name = 'Update',
				Data = {
					Foo = {
						Bar = true,
					},
				},
			})

			newReplion:Update('Foo', {
				Bar = false,
				Value = 20,
			})

			expect(newReplion:Get('Foo.Bar')).to.be.equal(false)
			expect(newReplion:Get('Foo.Value')).to.be.equal(20)
		end)
	end)

	describe('Replion:Get', function()
		it('should error if the path is not valid', function()
			expect(function()
				baseReplion:Get(1)
			end).to.be.throw('bad type for union')
		end)

		it('should get the value', function()
			local newReplion = ReplionService.new({
				Player = basePlayer,
				Name = 'Get',
				Data = {
					A = 20,
				},
			})

			expect(newReplion:Get('A')).to.be.equal(20)
		end)
	end)

	describe('Replion:GetExpect', function()
		local newReplion = ReplionService.new({
			Player = basePlayer,
			Name = 'GetExpect',
			Data = {
				A = 20,
			},
		})

		it('should error if the path is not valid', function()
			expect(function()
				newReplion:GetExpect(1)
			end).to.be.throw('bad type for union')
		end)

		it('should get the value', function()
			expect(newReplion:GetExpect('A')).to.be.equal(20)
		end)

		it('should error if the value does not exist', function()
			expect(function()
				newReplion:GetExpect('B')
			end).to.throw("isn't a valid path!")
		end)

		it('should support custom errors', function()
			expect(function()
				newReplion:GetExpect('B', 'B does not exist')
			end).to.throw('B does not exist')
		end)
	end)

	describe('Replion:Increase', function()
		it('should error if the path is not valid', function()
			expect(function()
				baseReplion:Increase(1, 10)
			end).to.be.throw('bad type for union')
		end)

		it('should increase the value', function()
			local newReplion = ReplionService.new({
				Player = basePlayer,
				Name = 'Increase',
				Data = {
					A = 20,
				},
			})

			newReplion:Increase('A', 10)

			expect(newReplion:Get('A')).to.be.equal(30)
		end)
	end)

	describe('Replion:Decrease', function()
		it('should error if the path is not valid', function()
			expect(function()
				baseReplion:Decrease(1, 10)
			end).to.be.throw('bad type for union')
		end)

		it('should decrease the value', function()
			local newReplion = ReplionService.new({
				Player = basePlayer,
				Name = 'Decrease',
				Data = {
					A = 20,
				},
			})

			newReplion:Decrease('A', 10)

			expect(newReplion:Get('A')).to.be.equal(10)
		end)
	end)

	describe('Replion:Insert', function()
		it('should error if the path is not valid', function()
			expect(function()
				baseReplion:Insert(1, 'foo')
			end).to.be.throw('bad type for union')
		end)

		it('should insert the value', function()
			local newReplion = ReplionService.new({
				Player = basePlayer,
				Name = 'Insert',
				Data = {
					Array = {},
				},
			})

			newReplion:Insert('Array', 'foo')

			local array = newReplion:Get('Array')

			expect(array[1]).to.be.equal('foo')
		end)
	end)

	describe('Replion:Remove', function()
		it('should error if the path is not valid', function()
			expect(function()
				baseReplion:Remove(1, 'foo')
			end).to.be.throw('bad type for union')
		end)

		it('should remove the value', function()
			local newReplion = ReplionService.new({
				Player = basePlayer,
				Name = 'Remove',
				Data = {
					Array = { 'foo', 'bar' },
				},
			})

			local v = newReplion:Remove('Array', 1)

			expect(v).to.be.equal('foo')
		end)
	end)

	describe('Replion:Clear', function()
		it('should error if the path is not valid', function()
			expect(function()
				baseReplion:Clear(1)
			end).to.be.throw('bad type for union')
		end)

		it('should clear the value', function()
			local newReplion = ReplionService.new({
				Player = basePlayer,
				Name = 'Clear',
				Data = {
					Array = { 'foo', 'bar' },
				},
			})

			newReplion:Clear('Array')

			local array = newReplion:Get('Array')

			expect(#array).to.be.equal(0)
		end)
	end)

	describe('Replion:Destroy', function()
		it('should destroy the replion', function()
			local newReplion = ReplionService.new({
				Player = basePlayer,
				Name = 'Destroy',
				Data = {},
			})

			newReplion:Destroy()

			expect(newReplion.Destroyed).to.be.ok()
		end)

		it('should be garbage collected', function()
			local ref = setmetatable({}, { __mode = 'v' })

			do
				ref[1] = ReplionService.new({
					Player = basePlayer,
					Name = 'Destroy',
					Data = {},
				})

				ref[1]:Destroy()
			end

			local start: number = os.clock()

			repeat
				task.wait()
			until ref[1] == nil or os.clock() > start + 5

			expect(ref[1]).to.equal(nil)
		end)
	end)
end
