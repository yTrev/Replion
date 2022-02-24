local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Packages = ReplicatedStorage:FindFirstChild('Packages')
local Replion = Packages.Replion

local ReplionService = require(Replion)

return function()
	describe('ReplionService.new', function()
		it('should error if invalid params are passed', function()
			expect(function()
				ReplionService.new({})
			end).to.be.throw()
		end)

		it('should create a new Replion', function()
			local newReplion = ReplionService.new({
				Player = { Name = 'John', UserId = 1 },
				Name = 'new',
				Data = {},
			})

			expect(newReplion).to.be.a('table')

			newReplion:Destroy()
		end)
	end)

	describe('ReplionService:GetReplion', function()
		local newReplion = ReplionService.new({
			Player = { Name = 'John', UserId = 1 },
			Name = 'GetReplion',
			Data = {},
		})

		it('should return the replion', function()
			local replion = ReplionService:GetReplion(newReplion.Player, newReplion.Name)

			expect(replion).to.equal(newReplion)

			newReplion:Destroy()
		end)
	end)

	describe('ReplionService:GetReplions', function()
		local john = {
			Name = 'John',
			UserId = 1,
		}

		for i = 1, 5 do
			ReplionService.new({
				Player = john,
				Name = 'GetReplions' .. i,
				Data = {},
			})
		end

		it('should return the replions', function()
			local replions = ReplionService:GetReplions(john)

			expect(replions).to.be.a('table')
			expect(replions.GetReplions1).to.be.ok()

			for _, replion in pairs(replions) do
				replion:Destroy()
			end
		end)
	end)

	describe('ReplionService:OnReplionAdded', function()
		it('should be fired when a Replion is created', function()
			local replion

			local conn = ReplionService:OnReplionAdded(function(newReplion)
				replion = newReplion
			end)

			local newReplion = ReplionService.new({
				Player = { Name = 'John', UserId = 1 },
				Name = 'OnReplionAdded',
				Data = {},
			})

			expect(replion).to.be.ok()
			expect(replion).to.equal(newReplion)

			newReplion:Destroy()
			conn:Disconnect()
		end)

		it('should filter results by Player', function()
			local newPlayer = { Name = 'Doe', UserId = 1 }
			local replion

			local conn = ReplionService:OnReplionAdded(function(newReplion)
				replion = newReplion
			end, newPlayer)

			local newReplion = ReplionService.new({
				Player = { Name = 'John', UserId = 1 },
				Name = 'OnReplionAddedFilter',
				Data = {},
			})

			expect(replion).never.to.be.ok()

			newReplion:Destroy()
			conn:Disconnect()
		end)
	end)

	describe('ReplionService:OnReplionRemoved', function()
		it('should be fired when a Replion is removed', function()
			local replion

			local conn = ReplionService:OnReplionRemoved(function(newReplion)
				replion = newReplion
			end)

			local newReplion = ReplionService.new({
				Player = { Name = 'John', UserId = 1 },
				Name = 'Test',
				Data = {},
			})

			newReplion:Destroy()

			expect(replion).to.be.ok()
			expect(replion).to.equal(newReplion)

			conn:Disconnect()
		end)

		it('should filter results by Player', function()
			local newPlayer = { Name = 'Doe', UserId = 1 }
			local replion

			local conn = ReplionService:OnReplionRemoved(function(newReplion)
				replion = newReplion
			end, newPlayer)

			local newReplion = ReplionService.new({
				Player = { Name = 'John', UserId = 1 },
				Name = 'OnReplionRemoved',
				Data = {},
			})

			expect(replion).never.to.be.ok()

			newReplion:Destroy()
			conn:Disconnect()
		end)
	end)

	describe('ReplionService:AwaitReplion', function()
		it('should await for a replion to be created', function()
			local newPlayer = { Name = 'Doe', UserId = 1 }
			local replion

			ReplionService:AwaitReplion(newPlayer, 'AwaitReplion'):andThen(function(newReplion)
				replion = newReplion
			end)

			local newReplion = ReplionService.new({
				Player = newPlayer,
				Name = 'AwaitReplion',
				Data = {},
			})

			expect(replion).to.equal(newReplion)

			newReplion:Destroy()
		end)
	end)
end
