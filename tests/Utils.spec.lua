local ReplicatedStorage = game:GetService('ReplicatedStorage')

return function()
	local Packages = ReplicatedStorage:FindFirstChild('Packages')

	local Utils = require(Packages:FindFirstChild('Replion').Shared.Utils)
	local Signal = require(Packages:FindFirstChild('Signal'))

	describe('Utils.convertTablePathToString', function()
		it('should return a string', function()
			expect(Utils.convertTablePathToString({ 'A', 'B', 'C' })).to.be.equal('A.B.C')
		end)
	end)

	describe('Utils.convertPathToTable', function()
		it('should return an array of strings', function()
			local newTable = Utils.convertPathToTable('A.B.C')

			expect(newTable[1]).to.be.equal('A')
			expect(newTable[2]).to.be.equal('B')
			expect(newTable[3]).to.be.equal('C')
		end)
	end)

	describe('Utils.getStringFromPath', function()
		it('should return a string', function()
			local fromTable = Utils.getStringFromPath({ 'A', 'B', 'C' })
			local fromString = Utils.getStringFromPath('A.B.C')

			expect(fromTable).to.be.equal('A.B.C')
			expect(fromString).to.be.equal('A.B.C')
		end)
	end)

	describe('Utils.getFromPath', function()
		it('should return the value in the path', function()
			local data = {
				A = {
					B = {
						C = 'Hello',
					},
				},
			}

			local dataPath, key = Utils.getFromPath('A.B.C', data)

			expect(dataPath).to.be.equal(data.A.B)
			expect(dataPath[key]).to.be.equal('Hello')
			expect(key).to.be.equal('C')
		end)
	end)

	describe('Utils.getSignalFromPath', function()
		local signals: { [string]: any } = {}

		it('should return a Signal', function()
			local signal = Utils.getSignalFromPath('Test', signals, true)
			expect(Signal.Is(signal)).to.be.equal(true)
		end)
	end)
end
