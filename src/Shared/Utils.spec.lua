return function()
	local Utils = require(script.Parent.Utils)
	local Signal = require(script.Parent.Signal)

	describe('Utils.getSignal', function()
		local signals: { [string]: Signal.Signal } = {}

		it('should return a Signal', function()
			local signal = Utils.getSignal(signals, 'Test', true)
			expect(Signal.Is(signal)).to.be.equal(true)
		end)
	end)

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

	describe('Utils.assign', function()
		local baseTable = {
			A = true,
			B = false,
			C = false,
		}

		it('should assign values and return a new table', function()
			local newTable = Utils.assign(baseTable, {
				A = false,
				B = true,
				D = true,
			})

			expect(newTable ~= baseTable).to.be.equal(true)
			expect(newTable.A).to.be.equal(false)
			expect(newTable.B).to.be.equal(true)
			expect(newTable.C).to.be.equal(false)
			expect(newTable.D).to.be.equal(true)
		end)
	end)
end
