--!nocheck
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)

local expect = JestGlobals.expect
local describe = JestGlobals.describe
local it = JestGlobals.it
local beforeEach = JestGlobals.beforeEach
local jest = JestGlobals.jest

local ReplionServer

beforeEach(function()
	jest.resetModules()

	ReplionServer = require(script.Parent)
end)

describe('ReplionServer.new', function()
	it('should create a new ReplionServer with the correct configuration', function()
		local replicateTo = 'All'
		local channel = 'New'

		local server = ReplionServer.new({
			ReplicateTo = replicateTo :: 'All',
			Data = {},
			Channel = channel,
		})

		expect(type(server)).toBe('table')
		expect(server.ReplicateTo).toBe(replicateTo)
		expect(server.Channel).toBe(channel)
	end)

	it('should throw an error if the same channel and ReplicateTo already exists', function()
		local replicateTo = 'All'
		local channel = 'Duplicated'

		ReplionServer.new({
			ReplicateTo = replicateTo :: 'All',
			Data = {},
			Channel = channel,
		})

		expect(function()
			ReplionServer.new({
				ReplicateTo = replicateTo :: 'All',
				Data = {},
				Channel = channel,
			})
		end).toThrow()
	end)

	it('should throw an error if Channel is not provided', function()
		expect(function()
			ReplionServer.new({
				ReplicateTo = 'All',
				Data = {},
			})
		end).toThrow()
	end)

	it('should throw an error if ReplicateTo is not provided', function()
		expect(function()
			ReplionServer.new({
				Channel = 'New',
				Data = {},
			})
		end).toThrow()
	end)

	it("shouldn't throw an error if the same channel is used with different ReplicateTo", function()
		local channel = 'SameChannel'

		ReplionServer.new({
			ReplicateTo = 'All',
			Data = {},
			Channel = channel,
		})

		expect(function()
			ReplionServer.new({
				ReplicateTo = {} :: any,
				Data = {},
				Channel = channel,
			})
		end).never.toThrow()
	end)
end)

describe('ReplionServer:GetReplion', function()
	it('should return the Replion', function()
		local channel = 'GetReplion'

		local replion = ReplionServer.new({
			ReplicateTo = 'All',
			Data = {},
			Channel = channel,
		})

		expect(ReplionServer:GetReplion(channel)).toBe(replion)
	end)

	it('should return nil if the Replion does not exist', function()
		expect(ReplionServer:GetReplion('NonExistent')).toBeNil()
	end)

	it('should throw an error if there are multiple Replions with the same channel', function()
		local channel = 'MultipleReplions'

		ReplionServer.new({
			ReplicateTo = 'All',
			Data = {},
			Channel = channel,
		})

		ReplionServer.new({
			ReplicateTo = {} :: any,
			Data = {},
			Channel = channel,
		})

		expect(function()
			ReplionServer:GetReplion(channel)
		end).toThrow()
	end)
end)

describe('ReplionServer:WaitReplion', function()
	it('should wait for the Replion to be created', function()
		local channel = 'WaitReplion'

		task.defer(function()
			ReplionServer.new({
				Channel = channel,
				Data = {},
				ReplicateTo = 'All',
			})
		end)

		expect(ReplionServer:GetReplion(channel)).toBeNil()

		local replion = ReplionServer:WaitReplion(channel)

		expect(replion).never.toBeNil()
	end)

	it('should wait for the Replion to be created with a timeout', function()
		local channel = 'WaitReplionTimeout'

		local now = os.clock()

		task.delay(0.05, function()
			ReplionServer.new({
				Channel = channel,
				Data = {},
				ReplicateTo = 'All',
			})
		end)

		expect(ReplionServer:GetReplion(channel)).toBeNil()

		local replion = ReplionServer:WaitReplion(channel, 0.1)

		expect(os.clock() - now).toBeGreaterThan(0.05)
		expect(replion).never.toBeNil()
	end)

	it('should return nil if the Replion is not created before the timeout', function()
		local channel = 'WaitReplionTimeout'

		local now = os.clock()

		expect(ReplionServer:GetReplion(channel)).toBeNil()

		local replion = ReplionServer:WaitReplion(channel, 0.05)

		expect(os.clock() - now).toBeGreaterThan(0.05)
		expect(replion).toBeNil()
	end)

	it('should return the Replion if it already exists', function()
		local channel = 'WaitReplionExists'

		local replion = ReplionServer.new({
			Channel = channel,
			Data = {},
			ReplicateTo = 'All',
		})

		local tookMoreThanOneFrame = false

		task.defer(function()
			tookMoreThanOneFrame = true
		end)

		local newReplion = ReplionServer:WaitReplion(channel)

		expect(tookMoreThanOneFrame).toBe(false)
		expect(newReplion).toBe(replion)
	end)
end)

describe('ReplionServer:AwaitReplion', function()
	it('should be called', function()
		local fnMock = jest.fn()
		local function callback(...)
			fnMock(...)
		end

		ReplionServer:AwaitReplion('AwaitReplion', callback)

		expect(fnMock).toHaveBeenCalledTimes(0)

		ReplionServer.new({
			Channel = 'AwaitReplion',
			Data = {},
			ReplicateTo = 'All',
		})

		expect(fnMock).toHaveBeenCalledTimes(1)
	end)

	it('should be called if the Replion exists', function()
		local fnMock = jest.fn()
		local function callback(...)
			fnMock(...)
		end

		ReplionServer.new({
			Channel = 'AwaitReplionCreated',
			Data = {},
			ReplicateTo = 'All',
		})

		ReplionServer:AwaitReplion('AwaitReplionCreated', callback)

		expect(fnMock).toHaveBeenCalledTimes(1)
	end)

	it('should never be called after timeout', function()
		local fnMock = jest.fn()
		local function callback(...)
			fnMock(...)
		end

		ReplionServer:AwaitReplion('Timeout', callback, 0)

		task.wait()

		expect(fnMock).toHaveBeenCalledTimes(0)
	end)

	it('should be called before timeout', function()
		local fnMock = jest.fn()
		local function callback(...)
			fnMock(...)
		end

		ReplionServer:AwaitReplion('Timeout', callback, 0.1)

		task.wait(0.05)

		ReplionServer.new({
			Channel = 'Timeout',
			Data = {},
			ReplicateTo = 'All',
		})

		expect(fnMock).toHaveBeenCalledTimes(1)
	end)

	it('should never be called if cancelled', function()
		local fnMock = jest.fn()
		local function callback(...)
			fnMock(...)
		end

		local cancel = ReplionServer:AwaitReplion('Cancelled', callback)

		expect(type(cancel)).toBe('function')
		assert(cancel, 'cancel is not a function')

		cancel()

		ReplionServer.new({
			Channel = 'Cancelled',
			Data = {},
			ReplicateTo = 'All',
		})

		expect(fnMock).toHaveBeenCalledTimes(0)
	end)
end)

describe('ReplionServer:GetReplionsFor', function()
	local fakePlayer: any = newproxy()

	it('should return the Replions for the given player', function()
		local channel = 'GetReplionsFor'

		local replion = ReplionServer.new({
			Channel = channel,
			Data = {},
			ReplicateTo = fakePlayer,
		})

		local otherReplion = ReplionServer.new({
			Channel = 'OtherChannel',
			Data = {},
			ReplicateTo = fakePlayer,
		})

		local replions = ReplionServer:GetReplionsFor(fakePlayer)

		expect(#replions).toBe(2)
		expect(table.find(replions, replion)).never.toBeNil()
		expect(table.find(replions, otherReplion)).never.toBeNil()
	end)

	it('should return an empty table if the player has no Replions', function()
		local replions = ReplionServer:GetReplionsFor(fakePlayer)

		expect(#replions).toBe(0)
	end)
end)

describe('ReplionServer:GetReplionFor', function()
	local fakePlayer: any = newproxy()

	it('should return the Replion for the given player', function()
		local channel = 'GetReplionFor'

		local replion = ReplionServer.new({
			Channel = channel,
			Data = {},
			ReplicateTo = fakePlayer,
		})

		expect(ReplionServer:GetReplionFor(fakePlayer, channel)).toBe(replion)
	end)

	it('should return nil if the player has no Replion for the given channel', function()
		expect(ReplionServer:GetReplionFor(fakePlayer, 'NonExistent')).toBeNil()
	end)
end)

describe('ReplionServer:WaitReplionFor', function()
	local fakePlayer: any = newproxy()

	it('should wait for the Replion to be created', function()
		local channel = 'WaitReplionFor'

		task.defer(function()
			ReplionServer.new({
				Channel = channel,
				Data = {},
				ReplicateTo = fakePlayer,
			})
		end)

		expect(ReplionServer:GetReplionFor(fakePlayer, channel)).toBeNil()

		local replion = ReplionServer:WaitReplionFor(fakePlayer, channel)

		expect(replion).never.toBeNil()
	end)

	it('should wait for the Replion to be created with a timeout', function()
		local channel = 'WaitReplionForTimeout'

		local now = os.clock()

		task.delay(0.05, function()
			ReplionServer.new({
				Channel = channel,
				Data = {},
				ReplicateTo = fakePlayer,
			})
		end)

		expect(ReplionServer:GetReplionFor(fakePlayer, channel)).toBeNil()

		local replion = ReplionServer:WaitReplionFor(fakePlayer, channel, 0.1)

		expect(os.clock() - now).toBeGreaterThan(0.05)
		expect(replion).never.toBeNil()
	end)

	it('should return nil if the Replion is not created before the timeout', function()
		local channel = 'WaitReplionForTimeout'

		local now = os.clock()

		expect(ReplionServer:GetReplionFor(fakePlayer, channel)).toBeNil()

		local replion = ReplionServer:WaitReplionFor(fakePlayer, channel, 0.05)

		expect(os.clock() - now).toBeGreaterThan(0.05)
		expect(replion).toBeNil()
	end)

	it('should return the Replion if it already exists', function()
		local channel = 'WaitReplionForExists'

		local replion = ReplionServer.new({
			Channel = channel,
			Data = {},
			ReplicateTo = fakePlayer,
		})

		local tookMoreThanOneFrame = false

		task.defer(function()
			tookMoreThanOneFrame = true
		end)

		local newReplion = ReplionServer:WaitReplionFor(fakePlayer, channel)

		expect(tookMoreThanOneFrame).toBe(false)
		expect(newReplion).toBe(replion)
	end)
end)

describe('ReplionServer:AwaitReplionFor', function()
	local fakePlayer: any = newproxy()

	it('should be called', function()
		local fnMock = jest.fn()
		local function callback(...)
			fnMock(...)
		end

		ReplionServer:AwaitReplionFor(fakePlayer, 'AwaitReplionFor', callback)

		expect(fnMock).toHaveBeenCalledTimes(0)

		ReplionServer.new({
			Channel = 'AwaitReplionFor',
			Data = {},
			ReplicateTo = fakePlayer,
		})

		expect(fnMock).toHaveBeenCalledTimes(1)
	end)

	it('should never be called after timeout', function()
		local fnMock = jest.fn()
		local function callback(...)
			fnMock(...)
		end

		ReplionServer:AwaitReplionFor(fakePlayer, 'TimeoutFor', callback, 0)

		task.wait()

		expect(fnMock).toHaveBeenCalledTimes(0)
	end)

	it('should be called before timeout', function()
		local fnMock = jest.fn()
		local function callback(...)
			fnMock(...)
		end

		ReplionServer:AwaitReplionFor(fakePlayer, 'TimeoutFor', callback, 0.1)

		task.wait(0.05)

		ReplionServer.new({
			Channel = 'TimeoutFor',
			Data = {},
			ReplicateTo = fakePlayer,
		})

		expect(fnMock).toHaveBeenCalledTimes(1)
	end)

	it('should return the Replion', function()
		local fooReplion

		ReplionServer:AwaitReplionFor(fakePlayer, 'AwaitReplionFor', function(newReplion)
			fooReplion = newReplion
		end)

		expect(fooReplion).never.toBeTruthy()

		ReplionServer.new({
			Channel = 'AwaitReplionFor',
			Data = {},
			ReplicateTo = fakePlayer,
		})

		task.wait()

		expect(fooReplion).toBeTruthy()
	end)

	it('should never be called if cancelled', function()
		local fnMock = jest.fn()
		local function callback(...)
			fnMock(...)
		end

		local cancel = ReplionServer:AwaitReplionFor(fakePlayer, 'CancelledFor', callback)

		expect(type(cancel)).toBe('function')
		assert(cancel, 'cancel is not a function')

		cancel()

		ReplionServer.new({
			Channel = 'CancelledFor',
			Data = {},
			ReplicateTo = fakePlayer,
		})

		task.wait()

		expect(fnMock).toHaveBeenCalledTimes(0)
	end)
end)

describe('ReplionServer:OnReplionAdded', function()
	it('should return a Connection', function()
		local channel = 'OnReplionAdded'

		local connection = ReplionServer:OnReplionAdded(function(replionChannel)
			expect(replionChannel).toBe(channel)
		end)

		expect(type(connection)).toBe('table')
		expect(type(connection.Disconnect)).toBe('function')
	end)

	it('should fire the event when a Replion is added', function()
		local channel = 'OnReplionAdded'
		local fired = false

		local addedReplion

		ReplionServer:OnReplionAdded(function(replionChannel, newReplion)
			expect(replionChannel).toBe(channel)

			fired = true
			addedReplion = newReplion
		end)

		local replion = ReplionServer.new({
			ReplicateTo = 'All',
			Data = {},
			Channel = channel,
		})

		expect(fired).toBe(true)
		expect(addedReplion).toBe(replion)
	end)
end)

describe('ReplionServer:OnReplionRemoved', function()
	it('should return a Connection', function()
		local channel = 'OnReplionRemoved'

		local connection = ReplionServer:OnReplionRemoved(function(replionChannel)
			expect(replionChannel).toBe(channel)
		end)

		expect(type(connection)).toBe('table')
		expect(type(connection.Disconnect)).toBe('function')
	end)

	it('should fire the event when a Replion is removed', function()
		local channel = 'OnReplionRemoved'
		local fired = false

		local removedReplion

		ReplionServer:OnReplionRemoved(function(replionChannel, replion)
			expect(replionChannel).toBe(channel)

			fired = true
			removedReplion = replion
		end)

		local replion = ReplionServer.new({
			ReplicateTo = 'All',
			Data = {},
			Channel = channel,
		})

		replion:Destroy()

		expect(fired).toBe(true)
		expect(removedReplion).toBe(replion)
	end)
end)
