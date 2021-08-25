require("apis.hexscreen")
require("apis.bitreader")
local wave = require("apis.wave")

local math = math
local sleep = sleep
local string = string
local screen = term

local data
local frame

local reader

local width
local height
local sleep_ticks

local _width_bits
local _height_bits

local fi

local arg = {...}

local function findPer(pName)
	if (peripheral.getName) then
		local p = peripheral.find(pName)
		local n

		if (p) then
			n = peripheral.getName(p)
		end

		return n, p

	else
		local d = {"top", "bottom", "right", "left", "front", "back"}
		for i=1, #d do
			if (peripheral.getType(d[i]) == pName) then
				local p = peripheral.wrap(d[i])
				local n = d[i]
				return n, p
				
			end
			
		end

	end

end

local function invertQuad(x, y, w, h)
	for i=y, y+h-1 do
		fi = frame[i]
		for j=x, x+w-1 do
			fi[j] = not fi[j]

		end
	end

	return frame

end

local function readQuad(x, y, w, h)
	if (w * h == 0) then
		return
	end


	if (reader:readBit()) then
		-- Splits into 4 more quads.
		
		local cw = math.ceil(w/2)
		local ch = math.ceil(h/2)
		local fw = math.floor(w/2)
		local fh = math.floor(h/2)

		readQuad(x, y, cw, ch)
		readQuad(x+cw, y, fw, ch)
		readQuad(x, y+ch, cw, fh)
		readQuad(x+cw, y+ch, fw, fh)
		
	else
		-- Doesn't split.
		if (reader:readBit()) then
			-- Inverts the region of this quad.
			invertQuad(x, y, w, h)
		
		end

	end

end

local fx
local fy

local w_bits
local h_bits

local frw
local frh

local function readFrame()
	fx = reader:readNumber(_width_bits)
	fy = reader:readNumber(_height_bits)

	w_bits = 0
	h_bits = 0

	while (2^w_bits <= width - fx) do
		w_bits = w_bits + 1
	end
	
	while (2^h_bits <= height - fy) do
		h_bits = h_bits + 1
	end

	frw = reader:readNumber(w_bits)

	if (frw == 0) then
		return
	end
	frh = reader:readNumber(h_bits)
	
	


	readQuad(fx+1, fy+1, frw, frh)

end

local loop = false
for i=1, #arg do
	if (arg[i] == "loop") then
		loop = true
		table.remove(arg, i)
		break

	end

end

print("Reading files...")

local videofile = arg[1]
local audiofile

local dPos = videofile:find("%.")
if (dPos) then
	audiofile = videofile:sub(1, dPos-1) .. ".nbs"
	
else
	audiofile = videofile .. ".nbs"
	videofile = videofile .. ".qtv"

end

-- Read the audio file
local wc
if (audiofile and fs.exists(audiofile)) then
	local dir, speaker = findPer("speaker")
	
	if (speaker ~= nil) then
		wc = wave.createContext()
		wc:addOutput(dir)
		local t = wave.loadTrack(audiofile)
		wc:addInstance(wave.createInstance(t))
		
	end

end


-- Read the video file
if (not fs.exists(videofile)) then
	error("video file '" .. videofile .. "' not found.")

end

local f = fs.open(videofile, "rb")
local fileString = f.readAll()
data = {string.byte(fileString, 1, -1)}

f.close()


reader = BitReader(data)

sleep_ticks = reader:readNumber(5)+1
width = reader:readNumber(10)+1
height = reader:readNumber(9)+1

_width_bits = 0
_height_bits = 0

while (2^_width_bits <= width) do
	_width_bits = _width_bits + 1
end

while (2^_height_bits <= height) do
	_height_bits = _height_bits + 1
end

local mon = peripheral.find("monitor")

if (mon ~= nil) then
	screen = mon
	
	for s=5,0.5,-0.5 do
		screen.setTextScale(s)
		w, h = screen.getSize()
		if (width <= (w+1)*2 or height <= (h+1)*3) then
			break
		end
		
	end

end

local hs = HexScreen(screen)
hs:setSizeBuffer(width, height)

local fri

frame = {}
for i=1, height do
	frame[i] = {}
	fri = frame[i]
	for j=1, width do
		fri[j] = false
	end
end

hs.buffer = frame
local status, err
while true do
	status, err = pcall(readFrame)

	if (not status) then
		if (not loop) then
			break
		end

		reader:reset()
		reader:readNumber(5)
		reader:readNumber(10)
		reader:readNumber(9)

		frame = {}
		for i=1, height do
			frame[i] = {}
			fri = frame[i]
			for j=1, width do
				fri[j] = false
			end
		end

		hs.buffer = frame

		if (wc) then
			for i = 1, #wc.instances do
				wc.instances[i].playing = true
				wc.instances[i].tick = 1
				
			end
		end

	else
		hs:draw()

		if (wc) then
			pcall(wc.update, wc, 0.05)
			
		end
		
	end

	sleep(0.05 * sleep_ticks)
	
end