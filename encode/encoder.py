import sys
import getopt
import time
import importlib
import math

import numpy as np

from moviepy.video.io.VideoFileClip import VideoFileClip
from PIL import Image


def usage():
	print("""Usage: encoder <options>
Options available:
-c/--codec <codec name>: The specific codec to use, required.
-i/--input <path>: Video file to be encoded.
-o/--output <path>: The output file.
-d/--duration <seconds>: The amount of time of the video to encode.
-t/--time <seconds>: The time to start encoding the video from.
-s/--sleepticks <ticks>: The amount of time to sleep in between frames, must be a positive integer.
-?/--help: A small guide and explanation.""")

def help():
	usage()
	print("""\nCall using "-c <codec name> -i <path>" to encode a file using the given codec.

You can specify the output file with -o <path>.

The method used to encode the final file depends on the codec used.
Details about each encoder can be obtained by calling "encoder -c <codec name>" without any other option.
""")

class Bits8:
	""" Class to control writing bits individually to a file, equivalent to a byte.
	"""

	def __init__(self):
		self._bits = 0
		self._value = 0
		
	def addBit(self, bit):
		""" Adds a single bit to the byte, unless it's already complete.

			Returns true if the byte is still incomplete.
		"""

		if (self._bits >= 8):
			return False

		self._bits += 1
		self._value *= 2
		if (bit):
			self._value += 1

		return self._bits < 8

	def reset(self):
		""" Clears the bits and returns a byte number representing it's past value.
		"""
		
		r = self._value

		self._bits = 0
		self._value = 0

		return r

	def complete(self):
		""" Adds new bits with value 0 until the group is complete.
		"""

		while (self.addBit(False)):
			pass

class OutBytes:
	""" List of bytes to be written to a file.
	"""

	output = []
	currentB = Bits8()
	debug = False

	_bits = (1 << np.arange(16))[::-1]

	def addBit(self, bit):
		""" Adds a single bit.
		"""
		
		if (self.debug):
			print(1 if bit else 0, end='')

		if (not self.currentB.addBit(bit)):
			self.output.append(self.currentB.reset())

	def addBits(self, bits):
		""" Adds a sequence of bits.
		"""
	
		for b in bits:
			self.addBit(b)

	def addNumber(self, number, n):
		""" Converts a number into a sequence of N bits, then adds it to the file.

		More than 16 bits per number will not be accepted, it's a hard limit.

		If the number contains more bits, they will be ignored.
		"""
		if (n > 0 and n <= 16):
			self.addBits((self._bits[16-n:] & number) != 0)

	def close(self):
		""" Completes current byte and adds it to the output.
		"""

		self.currentB.complete()
		self.output.append(self.currentB.reset())


if __name__ == "__main__":
	codec = ""
	video_input = ""
	image_input = ""
	video_output = "converted_file.qtv"
	duration = 100000
	initial_time = 0
	sleep_ticks = 1
	lossiness = 0

	try:
		opts, args = getopt.getopt(sys.argv[1:], "c:i:o:d:t:s:l:?", ["codec=", "input=", "image=", "output=", "duration=", "time=", "sleepticks=", "lossiness=", "help"])
	except getopt.GetoptError:
		usage()
		sys.exit(2)

	try:
		for opt, arg in opts:
			if opt in ("-?", "--help"):
				help()
				sys.exit()
			elif opt in ("-c", "--codec"):
				codec = arg
			elif opt in ("-i", "--input"):
				video_input = arg
			elif opt == "--image":
				image_input = arg
			elif opt in ("-o", "--output"):
				video_output = arg
			elif opt in ("-d", "--duration"):
				duration = float(arg)
			elif opt in ("-t", "--time"):
				initial_time = float(arg)
			elif opt in ("-s", "--sleepticks"):
				sleep_ticks = int(arg)
			elif opt in ("-l", "--lossiness"):
				lossiness = float(arg)
			else:
				usage()
				sys.exit(2)
	except:
		usage()
		sys.exit(2)
	
	# Input validation
	if (codec == ""):
		print("You must specify a codec.")
		usage()
		sys.exit(2)

	codec = importlib.import_module(codec)

	if (video_input == "" and image_input == ""):
		codec.help()
		sys.exit(2)

	if (sleep_ticks < 1):
		sleep_ticks = 1
	elif (sleep_ticks > 16):
		sleep_ticks = 16

	if (initial_time < 0):
		initial_time = 0
	
	if (duration < 0):
		duration = 0

	if (lossiness < 0):
		lossiness = 0


	out_bytes = OutBytes()


	
	# For debugging purposes, encodes a single image, also prints all bits as 1's and 0's on the console/terminal.
	# Could break at any second with changes to other parts of the code, don't recommend relying on it for anything ever.
	# That's also why it's not documented anywhere else.
	# Also doesn't work well for .jpg so use .png instead.
	if (image_input != ""):
		print("Compressing image...")
		out_bytes.debug = True
		start_time = time.time()

		im = Image.open(image_input)
		w, h = im.size

		frame = []

		raw_data = list(im.getdata())
		for y in range(h):
			frame.append(raw_data[w*y:w*(y+1)])

		encoder = codec.Encoder(w, h, out_bytes)
		repeats = 1
		for i in range(repeats):
			encoder.encode_frame(frame)

		out_bytes.close()

		tot = len(out_bytes.output)
		ori = math.ceil(w*h/8) * repeats

		print(f"\nEncoded image {repeats} times.")
		print(f"Total bytes used: {tot}\nAprox. uncompressed size: {ori}")
		print("Compression ratio: %.2f%%" % (tot / ori * 100))
		print("Time elapsed: %.2fs\n" % (time.time() - start_time))

		sys.exit(2)




	# Preparing to encode.

	clip = VideoFileClip(video_input)

	t = initial_time

	w, h = clip.size
	out_bytes.addNumber(sleep_ticks-1, 5)
	out_bytes.addNumber(w-1, 10)
	out_bytes.addNumber(h-1, 9)


	print(f"\nStarting encoding for '{video_input}' with the following settings:\nSleep ticks: {sleep_ticks}")
	print(f"Video duration: {min(duration, clip.duration)}s\nInitial time: {t}s\n")

	# Encoding loop.

	encoder = codec.Encoder(w, h, out_bytes)

	start_time = time.time()
	g = 0
	while (clip.is_playing(t) and t < initial_time + duration):
		frame = clip.get_frame(t)

		encoder.encode_frame(frame)
		
		if (g % 20 == 0):
			tot = len(out_bytes.output)
			ori = max(math.ceil(w*h/8 * (t-initial_time)*20/sleep_ticks), 1)
			print("Encoding progress: %.2f%% Aprox. time remaining: %.2fs Current size: %.2fkB Compression ratio: %.2f%%    " % ((t - initial_time) / min(duration, clip.duration) * 100, (time.time() - start_time) / max((t - initial_time) / min(duration, clip.duration), 0.00001) - (time.time() - start_time), len(out_bytes.output) / 1000, tot / ori * 100), end="\r")
		
		t += sleep_ticks/20
		g += 1


	tot = len(out_bytes.output)
	ori = math.ceil(w*h/8 * min(duration, clip.duration)*20/sleep_ticks)
	print("\nTotal bytes used: %.2fkB\nAprox. uncompressed size: %.2fkB" % (tot / 1000, ori / 1000))
	print("Compression ratio: %.2f%%" % (tot / ori * 100))
	print("Time elapsed: %.2fs\n" % (time.time() - start_time))


	out_bytes.close()
	with open(video_output, "wb") as f:
		f.write(bytes(out_bytes.output))