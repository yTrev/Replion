--!nonstrict
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Replion = require(ReplicatedStorage.Packages.Replion)

local ReplionServer = Replion.Server

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

		it('should return nil if the replion does not exist', function()
			local replion = ReplionServer:GetReplion('doesNotExist')

			expect(replion).to.be.equal(nil)
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

	describe('ReplionServer:OnReplionAdded', function()
		it('should fire when a Replion is added', function()
			local addedChannel, addedReplion

			ReplionServer:OnReplionAdded(function(channel: string, replion)
				addedChannel, addedReplion = channel, replion
			end)

			local newReplion = ReplionServer.new({
				Channel = 'onReplionAddedTest',
				Data = { Coins = 20 },
				ReplicateTo = 'All',
			})

			expect(addedChannel).to.be.equal(newReplion.Channel)
			expect(addedReplion).to.be.equal(newReplion)
		end)
	end)

	describe('ReplionServer:OnReplionRemoved', function()
		it('should fire when a Replion is removed', function()
			local removedChannel, removedReplion
			local newReplion = ReplionServer.new({
				Channel = 'onReplionRemovedTest',
				Data = { Coins = 20 },
				ReplicateTo = 'All',
			})

			ReplionServer:OnReplionRemoved(function(channel: string, replion)
				removedChannel, removedReplion = channel, replion
			end)

			newReplion:Destroy()

			expect(removedChannel).to.be.equal(newReplion.Channel)
			expect(removedReplion).to.be.equal(newReplion)
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
end
