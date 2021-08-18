local bit = bit

local function readBit_b8(self)
	if (self.current > 8) then
		return false, false
	end

	self.current = self.current + 1
	local v = bit.band(self._value, self._bits[self.current])

	return self.current < 8, v > 0

end

local function new(self, value)
	self.current = 0
	self._value = value

end

function Bits8()
	-- Represents a byte, allows reading a bit at a time.
	local self = {}

	self.current = 0
	self._value = 0
	self._bits = {128, 64, 32, 16, 8, 4, 2, 1}

	self.readBit = readBit_b8
	self.new = new

	return self

end



local function readBit_br(self)
	local s, v = self.cb:readBit()
	if (not s) then
		self.pointer = self.pointer + 1
		self.cb:new(self.data[self.pointer])

	end

	return v

end

local function readBits(self, n)
	local bt = self._bittable
	for i = 1, n do
		bt[i] = self:readBit()
		
	end
	for i = n+1, #bt do
		bt[i] = nil
		
	end

	return bt

end

local function readNumber(self, n)
	local m = 0

	local t = self:readBits(n)
	for i = 1, #t do
		m = m * 2
		if (t[i]) then
			m = m + 1

		end

	end

	return m

end

local function reset(self)
	self.cb = Bits8()
	self.pointer = 1
	self.cb:new(self.data[self.pointer])

end

function BitReader(data)
	-- Class to read bits individually from a table of bytes.
	local self = {}

	self.data = data
	self.cb = Bits8()
	self.pointer = 1
	self.cb:new(self.data[self.pointer])

	self.readBit = readBit_br
	self.readBits = readBits
	self.readNumber = readNumber
	self.reset = reset

	self._bittable = {}

	return self

end