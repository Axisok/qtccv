--[[
wave version 0.1.5

The MIT License (MIT)
Copyright (c) 2020 CrazedProgrammer

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

-- I'm so happy I don't have to write or understand this code, thanks! - ax.


local wave = { }
wave.version = "0.1.5"

wave._oldSoundMap = {"harp", "bassattack", "bd", "snare", "hat"}
wave._newSoundMap = {"harp", "bass", "basedrum", "snare", "hat"}
wave._defaultThrottle = 99
wave._defaultClipMode = 1
wave._maxInterval = 1
wave._isNewSystem = false
if _HOST then
	-- Redoing this, the correct and boring way, otherwise it doesn't work with versions above 1.100 until 1.800. - axisok
	-- Likely to break only if CC:Tweaked changes how it writes versions.
	local _matches = {}
	for s in string.gmatch(_HOST, "%S+") do
		_matches[#_matches + 1] = s
	end

	local _v = _matches[2]
	_matches = {}
	for s in string.gmatch(_v, "%P+") do
		_matches[#_matches + 1] = s
	end

	local _new = {1, 80}
	wave._isNewSystem = true
	for i=1, #_new, 1 do
		if (i <= #_matches and _new[i] < tonumber(_matches[i])) then
			break

		elseif (i <= #_matches and _new[i] > tonumber(_matches[i])) then
			wave._isNewSystem = false
			break
		end

	end


end

wave.context = { }
wave.output = { }
wave.track = { }
wave.instance = { }

function wave.createContext(clock, volume)
	clock = clock or os.clock()
	volume = volume or 1.0

	local context = setmetatable({ }, {__index = wave.context})
	context.outputs = { }
	context.instances = { }
	context.vs = {0, 0, 0, 0, 0}
	context.prevClock = clock
	context.volume = volume
	return context
end

function wave.context:addOutput(...)
	local output = wave.createOutput(...)
	self.outputs[#self.outputs + 1] = output
	return output
end

function wave.context:addOutputs(...)
	local outs = {...}
	if #outs == 1 then
		if not getmetatable(outs) then
			outs = outs[1]
		else
			if getmetatable(outs).__index ~= wave.outputs then
				outs = outs[1]
			end
		end
	end
	for i = 1, #outs do
		self:addOutput(outs[i])
	end
end

function wave.context:removeOutput(out)
	if type(out) == "number" then
		table.remove(self.outputs, out)
		return
	elseif type(out) == "table" then
		if getmetatable(out).__index == wave.output then
			for i = 1, #self.outputs do
				if out == self.outputs[i] then
					table.remove(self.outputs, i)
					return
				end
			end
			return
		end
	end
	for i = 1, #self.outputs do
		if out == self.outputs[i].native then
			table.remove(self.outputs, i)
			return
		end
	end
end

function wave.context:addInstance(...)
	local instance = wave.createInstance(...)
	self.instances[#self.instances + 1] = instance
	return instance
end

function wave.context:removeInstance(instance)
	if type(instance) == "number" then
		table.remove(self.instances, instance)
	else
		for i = 1, #self.instances do
			if self.instances == instance then
				table.remove(self.instances, i)
				return
			end
		end
	end
end

function wave.context:playNote(note, pitch, volume)
	volume = volume or 1.0

	self.vs[note] = self.vs[note] + volume
	for i = 1, #self.outputs do
		self.outputs[i]:playNote(note, pitch, volume * self.volume)
	end
end

function wave.context:update(interval)
	local clock = os.clock()
	interval = interval or (clock - self.prevClock)

	self.prevClock = clock
	if interval > wave._maxInterval then
		interval = wave._maxInterval
	end
	for i = 1, #self.outputs do
		self.outputs[i].notes = 0
	end
	for i = 1, 5 do
		self.vs[i] = 0
	end
	if interval > 0 then
		for i = 1, #self.instances do
			local notes = self.instances[i]:update(interval)
			for j = 1, #notes / 3 do
				self:playNote(notes[j * 3 - 2], notes[j * 3 - 1], notes[j * 3])
			end
		end
	end
end



function wave.createOutput(out, volume, filter, throttle, clipMode)
	volume = volume or 1.0
	filter = filter or {true, true, true, true, true}
	throttle = throttle or wave._defaultThrottle
	clipMode = clipMode or wave._defaultClipMode

	local output = setmetatable({ }, {__index = wave.output})
	output.native = out
	output.volume = volume
	output.filter = filter
	output.notes = 0
	output.throttle = throttle
	output.clipMode = clipMode
	if type(out) == "function" then
		output.nativePlayNote = out
		output.type = "custom"
		return output
	elseif type(out) == "string" then
		if peripheral.getType(out) == "iron_noteblock" then
			if wave._isNewSystem then
				local nb = peripheral.wrap(out)
				output.type = "iron_noteblock"
				function output.nativePlayNote(note, pitch, vol)
					if output.volume * vol > 0 then
						nb.playSound("minecraft:block.note."..wave._newSoundMap[note], vol, math.pow(2, (pitch - 12) / 12))
					end
				end
				return output
			end
		elseif peripheral.getType(out) == "speaker" then
			if wave._isNewSystem then
				local nb = peripheral.wrap(out)
				output.type = "speaker"
				function output.nativePlayNote(note, pitch, vol)
					if output.volume * vol > 0 then
						nb.playNote(wave._newSoundMap[note], vol, pitch)
					end
				end
				return output
			end
		end
	elseif type(out) == "table" then
		if out.execAsync then
			output.type = "commands"
			if wave._isNewSystem then
				function output.nativePlayNote(note, pitch, vol)
					out.execAsync("playsound minecraft:block.note."..wave._newSoundMap[note].." record @a ~ ~ ~ "..tostring(vol).." "..tostring(math.pow(2, (pitch - 12) / 12)))
				end
			else
				function output.nativePlayNote(note, pitch, vol)
					out.execAsync("playsound note."..wave._oldSoundMap[note].." @a ~ ~ ~ "..tostring(vol).." "..tostring(math.pow(2, (pitch - 12) / 12)))
				end
			end
			return output
		elseif getmetatable(out) then
			if getmetatable(out).__index == wave.output then
				return out
			end
		end
	end
end

function wave.scanOutputs()
	local outs = { }
	if commands then
		outs[#outs + 1] = wave.createOutput(commands)
	end
	local sides = peripheral.getNames()
	for i = 1, #sides do
		if peripheral.getType(sides[i]) == "iron_noteblock" then
			outs[#outs + 1] = wave.createOutput(sides[i])
		elseif peripheral.getType(sides[i]) == "speaker" then
			outs[#outs + 1] = wave.createOutput(sides[i])
		end
	end
	return outs
end

function wave.output:playNote(note, pitch, volume)
	volume = volume or 1.0

	if self.clipMode == 1 then
		if pitch < 0 then
			pitch = 0
		elseif pitch > 24 then
			pitch = 24
		end
	elseif self.clipMode == 2 then
		if pitch < 0 then
			while pitch < 0 do
				pitch = pitch + 12
			end
		elseif pitch > 24 then
			while pitch > 24 do
				pitch = pitch - 12
			end
		end
	end
	if self.filter[note] and self.notes < self.throttle then
		self.nativePlayNote(note, pitch, volume * self.volume)
		self.notes = self.notes + 1
	end
end



function wave.loadTrack(path)
	local track = setmetatable({ }, {__index = wave.track})
	local handle = fs.open(path, "rb")
	if not handle then return end

	local function readInt(size)
		local num = 0
		for i = 0, size - 1 do
			local byte = handle.read()
			if not byte then -- dont leave open file handles no matter what
				handle.close()
				return
			end
			num = num + byte * (256 ^ i)
		end
		return num
	end
	local function readStr()
		local length = readInt(4)
		if not length then return end
		local data = { }
		for i = 1, length do
			data[i] = string.char(handle.read())
		end
		return table.concat(data)
	end

	-- Part #1: Metadata
	track.length = readInt(2) -- song length (ticks)
	track.height = readInt(2) -- song height
	track.name = readStr() -- song name
	track.author = readStr() -- song author
	track.originalAuthor = readStr() -- original song author
	track.description = readStr() -- song description
	track.tempo = readInt(2) / 100 -- tempo (ticks per second)
	track.autoSaving = readInt(1) == 0 and true or false -- auto-saving
	track.autoSavingDuration = readInt(1) -- auto-saving duration
	track.timeSignature = readInt(1) -- time signature (3 = 3/4)
	track.minutesSpent = readInt(4) -- minutes spent
	track.leftClicks = readInt(4) -- left clicks
	track.rightClicks = readInt(4) -- right clicks
	track.blocksAdded = readInt(4) -- blocks added
	track.blocksRemoved = readInt(4) -- blocks removed
	track.schematicFileName = readStr() -- midi/schematic file name

	-- Part #2: Notes
	track.layers = { }
	for i = 1, track.height do
		track.layers[i] = {name = "Layer "..i, volume = 1.0}
		track.layers[i].notes = { }
	end

	local tick = 0
	while true do
		local tickJumps = readInt(2)
		if tickJumps == 0 then break end
		tick = tick + tickJumps
		local layer = 0
		while true do
			local layerJumps = readInt(2)
			if layerJumps == 0 then break end
			layer = layer + layerJumps
			if layer > track.height then -- nbs can be buggy
				for i = track.height + 1, layer do
					track.layers[i] = {name = "Layer "..i, volume = 1.0}
					track.layers[i].notes = { }
				end
				track.height = layer
			end
			local instrument = readInt(1)
			local key = readInt(1)
			if instrument <= 4 then -- nbs can be buggy
				track.layers[layer].notes[tick * 2 - 1] = instrument + 1
				track.layers[layer].notes[tick * 2] = key - 33
			end
		end
	end

	-- Part #3: Layers
	for i = 1, track.height do
		local name = readStr()
		if not name then break end -- if layer data doesnt exist, abort
		track.layers[i].name = name
		track.layers[i].volume = readInt(1) / 100
	end

	handle.close()
	return track
end



function wave.createInstance(track, volume, playing, loop)
	volume = volume or 1.0
	playing = (playing == nil) or playing
	loop = (loop ~=  nil) and loop

	if getmetatable(track).__index == wave.instance then
		return track
	end
	local instance = setmetatable({ }, {__index = wave.instance})
	instance.track = track
	instance.volume = volume or 1.0
	instance.playing = playing
	instance.loop = loop
	instance.tick = 1
	return instance
end 

function wave.instance:update(interval)
	local notes = { }
	if self.playing then
		local dticks = interval * self.track.tempo
		local starttick = self.tick
		local endtick = starttick + dticks
		local istarttick = math.ceil(starttick)
		local iendtick = math.ceil(endtick) - 1
		for i = istarttick, iendtick do
			for j = 1, self.track.height do
				if self.track.layers[j].notes[i * 2 - 1] then
					notes[#notes + 1] = self.track.layers[j].notes[i * 2 - 1]
					notes[#notes + 1] = self.track.layers[j].notes[i * 2]
					notes[#notes + 1] = self.track.layers[j].volume
				end
			end
		end
		self.tick = self.tick + dticks

		if endtick > self.track.length then
			self.tick = 1
			self.playing = self.loop
		end
	end
	return notes
end



return wave
