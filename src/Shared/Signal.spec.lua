return function()
	local Signal = require(script.Parent.Signal)

	describe('Signal.new', function()
		it('should create a new signal', function()
			local newSignal: Signal.Signal = Signal.new()

			expect(Signal.Is(newSignal)).to.be.equal(true)

			newSignal:Destroy()
		end)
	end)

	describe('Signal:Wait', function()
		it('should wait a signal fire', function()
			local newSignal: Signal.Signal = Signal.new()

			spawn(function()
				newSignal:Fire(1, 2, 3)
			end)

			local a, b, c = newSignal:Wait()

			expect(a).to.equal(1)
			expect(b).to.equal(2)
			expect(c).to.equal(3)

			newSignal:Destroy()
		end)
	end)

	describe('Signal:Destroy', function()
		it('should Disconnect all connections', function()
			local newSignal: Signal.Signal = Signal.new()

			for _i = 1, 5 do
				newSignal:Connect(function() end)
			end

			newSignal:Destroy()

			expect(newSignal._connections).to.be.equal(nil)
		end)
	end)

	describe('Connection:Disconnect', function()
		it('should disconnect the connection', function()
			local newSignal: Signal.Signal = Signal.new()

			local wasFired: boolean = false

			local connection: Signal.Connection = newSignal:Connect(function()
				wasFired = true
			end)

			connection:Disconnect()

			newSignal:Fire()

			expect(wasFired).to.be.equal(false)

			newSignal:Destroy()
		end)
	end)
end
