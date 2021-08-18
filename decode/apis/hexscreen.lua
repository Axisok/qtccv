local table = table
local string = string
local term = term

local function draw(self)
	-- Draws the entire visible buffer.
	local te = self.term
	for y=1, self.height do
		te.setCursorPos(1, y)
		c0, c1, c2 = self:getLine(y)

		te.blit(c0, c1, c2)
		
	end

end

local n
local b

local function getCharAt(self, x, y)
	n = 0
	b = self.buffer
	for i=y*3,y*3-2,-1 do
		for j=x*2,x*2-1,-1 do
			n = n * 2
			if (b[i][j]) then
				n = n + 1
			end
			
		end

	end

	return n

end

local _t
local _c
local _bg
local _cl
local cs

local c

local function getLine(self, y)
	_t = self._text
	_c = self._color
	_bg = self._bgcolor
	_cl = self._charList

	cs = self.colors

	for x=1,self.width do
		c = self:getCharAt(x, y)
		_t[x] = _cl[c]

		if (c >= 32) then
			_c[x] = cs[2]
			_bg[x] = cs[1]
		else
			_c[x] = cs[1]
			_bg[x] = cs[2]

		end

	end

	return table.concat(_t), table.concat(_c), table.concat(_bg)

end

local tb
local function setSize(self, w, h)
	self.width, self.height = w, h
	self.b_width = self.height * 2
	self.b_height = self.height * 3

	self.buffer = {}

	for i=1, self.b_height do
		tb = {}
		for j=1, self.b_height do
			tb[j] = false
		end
		self.buffer[i] = tb
	end

end

local function setSizeBuffer(self, w, h)
	self:setSize(math.floor(w/2), math.floor(h/3))

end

function HexScreen(customTerm)
	local self = {}

	self.term = customTerm or term
	
	self.width, self.height = self.term.getSize()
	self.b_width = self.width * 2
	self.b_height = self.height * 3

	self.buffer = {}

	for i=1, self.b_height do
		local t = {}
		for j=1, self.b_height do
			table.insert(t, false)
		end
		table.insert(self.buffer, t)
	end

	self._text = {}
	self._color = {}
	self._bgcolor = {}

	self.colors = {"0", "f"}

	self._charList = {}
	for i=0,63 do
		if (i < 32) then
			c = string.char(128 + i)

		else
			c = string.char(191 - i)

		end

		self._charList[i] = c

	end

	self.draw = draw
	self.getCharAt = getCharAt
	self.getLine = getLine
	self.setSize = setSize
	self.setSizeBuffer = setSizeBuffer

	return self

end
