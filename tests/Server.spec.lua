--!strict
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Replion = require(ReplicatedStorage.Packages.Replion)

local ReplionServer = Replion.Server

--[[
	Tests TO-DO
	new //
	GetReplion //
	OnReplionAdded
	OnReplionRemoved
	WaitReplion //
	AwaitReplion //

	GetReplionsFor // 
	GetReplionFor //
	WaitReplionFor
	AwaitReplionFor //
]]

return function()
	local fakePlayer = {
		Name = 'fakePlayer',
		UserId = 'fakeUserId',
	}

	describe('ReplionServer.new', function()
		local newReplion = ReplionServer.new({
			Channel = 'newTest',
			Data = { Coins = 20 },
			ReplicateTo = 'All',
		})

		it('should return a Replion', function()
			expect(newReplion).to.be.a('table')
		end)

		it('should error if a Channel is not provided', function()
			expect(function()
				ReplionServer.new({
					Data = { Coins = 20 },
					ReplicateTo = 'All',
				})
			end).to.throw('[Replion] - Channel is required!')
		end)

		it('should error if a ReplicateTo is not provided', function()
			expect(function()
				ReplionServer.new({
					Channel = 'replicateToRequired',
					Data = { Coins = 20 },
				})
			end).to.throw('[Replion] - ReplicateTo is required!')
		end)

		it('should error if trying to create a Replion with the same channel and ReplicateTo', function()
			expect(function()
				ReplionServer.new({
					Channel = 'newTest',
					Data = { Coins = 20 },
					ReplicateTo = 'All',
				})
			end).to.throw('[Replion] - Channel "newTest" already exists! for "All"')
		end)
	end)

	describe('ReplionServer:GetReplion', function()
		local newReplion = ReplionServer.new({
			Channel = 'getReplionTest',
			Data = { Coins = 20 },
			ReplicateTo = 'All',
		})

		it('should return the Replion', function()
			expect(newReplion).to.be.equal(ReplionServer:GetReplion(newReplion.Channel))
		end)

		it('should error if there are multiple Replions with the same Channel', function()
			ReplionServer.new({
				Channel = newReplion.Channel,
				Data = { Coins = 20 },
				ReplicateTo = {},
			})

			expect(function()
				ReplionServer:GetReplion(newReplion.Channel)
			end).to.throw('There are multiple replions')
		end)
	end)

	describe('ReplionServer:GetReplionsFor', function()
		ReplionServer.new({
			Channel = 'getReplionsForTest',
			Data = { Coins = 20 },
			ReplicateTo = fakePlayer,
		})

		it('should return the Replions', function()
			expect(ReplionServer:GetReplionsFor(fakePlayer :: any)).to.be.a('table')
		end)
	end)

	describe('ReplionServer:GetReplionFor', function()
		local newReplion = ReplionServer.new({
			Channel = 'getReplionForTest',
			Data = { Coins = 20 },
			ReplicateTo = fakePlayer,
		})

		it('should return the Replion', function()
			expect(newReplion).to.be.equal(ReplionServer:GetReplionFor(fakePlayer :: any, newReplion.Channel))
		end)
	end)

	describe('ReplionServer:AwaitReplionFor', function()
		it('should be called', function()
			local fooReplion
			ReplionServer:AwaitReplion('AwaitFor', function(newReplion)
				fooReplion = newReplion
			end)

			expect(fooReplion).to.never.be.ok()

			ReplionServer.new({
				Channel = 'AwaitFor',
				Data = {},
				ReplicateTo = fakePlayer,
			})

			task.wait()

			expect(fooReplion).to.be.ok()
		end)

		it('should never be called after timeout', function()
			local fooReplion
			ReplionServer:AwaitReplion('TimeoutFor', function(newReplion)
				fooReplion = newReplion
			end, 0.1)

			expect(fooReplion).to.never.be.ok()

			task.wait(0.15)

			ReplionServer.new({
				Channel = 'TimeoutFor',
				Data = {},
				ReplicateTo = fakePlayer,
			})

			expect(fooReplion).to.never.be.ok()
		end)
	end)

	describe('ReplionServer:AwaitReplion', function()
		it('should be called', function()
			local fooReplion
			ReplionServer:AwaitReplion('Foo', function(newReplion)
				fooReplion = newReplion
			end)

			expect(fooReplion).to.never.be.ok()

			ReplionServer.new({
				Channel = 'Foo',
				Data = {},
				ReplicateTo = 'All',
			})

			task.wait()

			expect(fooReplion).to.be.ok()
		end)

		it('should never be called after timeout', function()
			local fooReplion
			ReplionServer:AwaitReplion('Timeout', function(newReplion)
				fooReplion = newReplion
			end, 0.1)

			expect(fooReplion).to.never.be.ok()

			task.wait(0.15)

			ReplionServer.new({
				Channel = 'Timeout',
				Data = {},
				ReplicateTo = 'All',
			})

			expect(fooReplion).to.never.be.ok()
		end)
	end)

	describe('ReplionServer:WaitReplion', function()
		it('should be called', function()
			local fooReplion

			task.defer(function()
				fooReplion = ReplionServer:WaitReplion('WaitReplion')
			end)

			expect(fooReplion).to.never.be.ok()

			ReplionServer.new({
				Channel = 'WaitReplion',
				Data = {},
				ReplicateTo = 'All',
			})

			task.wait()

			expect(fooReplion).to.be.ok()
		end)
	end)
end
