import math
import sys

import numpy as np

def help():
	print("""\nQuadTree (Binary)

Quadtree structure based encoder, recursively splits the screen in 4 parts until only parts that are a solid color are visible.
It doesn't store full images, it would be wasteful to do so especially since the video only has two colors anyways.
It'll store only the pixels that changed color, represented as white pixels.
It also only stores pixels in an area that actually changed, the area itself is recorded at the start of the frame.

Expect a compression ratio of about 30%% of the original size for medium to small files.
The bigger the file, the better this ratio will be.
Bad Apple at the highest resolution CC can play almost reaches 10%.

""")

class Encoder:
	def __init__(self, w, h, out_bytes, lossiness=0):
		self.width = w
		self.height = h

		# To save on storage, we figure out how many bits we need to store the width and height values.
		# This is not super meaningful even for a big file, but we're writing data bit by bit anyways, so might as well.
		self._width_bits = 0
		self._height_bits = 0

		while (2 ** self._width_bits <= self.width):
			self._width_bits += 1

		while (2 ** self._height_bits <= self.height):
			self._height_bits += 1

		# There's a hard limit on how big numbers can be, mostly because there shouldn't be a situation where numbers this big are required ever.
		if (self._width_bits > 16 or self._height_bits > 16):
			print("Video size too big! How long do you think that'd take to encode even if it worked anyways?")
			sys.exit()

		self.out_bytes = out_bytes

		self.diff = None

		self.last = np.zeros((self.height, self.width))

	def getColor(self, x, y, w, h, data=None):
		""" Checks if the region is uniform, and if it is, the color.
		"""

		if (data is None):
			data = self.diff

		# Gets a slice of the data with the correct coordinates.
		s = data[y:y+h, x:x+w]

		# Generates an array of bools where each stores if that index in the slice is equal to the first index, then checks if all of those are True.
		# Simply put, will be true only if all elements are the same.
		u = np.all(s == s[0, 0])

		# If you're wondering why this needs to be a condition, it doesn't.
		# A previous version of the code used it and I left it like that since it doesn't change the result.
		return u, True if not u else s[0, 0]

	def split(self, x, y, w, h):
		""" Splits a region into 4 new regions.
		
			Returns a list of 4 tuples, each with 4 values for position and size.
		"""
		l = []

		cw = math.ceil(w/2)
		ch = math.ceil(h/2)
		fw = math.floor(w/2)
		fh = math.floor(h/2)
		
		# NW
		l.append((x, y, cw, ch))
		# NE
		l.append((x + cw, y, fw, ch))
		
		# SW
		l.append((x, y + ch, cw, fh))
		# SE
		l.append((x + cw, y + ch, fw, fh))

		return l

	def encode_quad(self, x, y, w, h, data=None):
		""" Encodes a region recursively splitting to capture detail.
		"""

		# If the region is empty, the encoder just skips it since the decoder also has this information.
		if (w*h == 0):
			return

		if (data is None):
			data = self.diff
		
		# Check if the region has an uniform color.
		u, c = self.getColor(x, y, w, h)
		if (u):
			# It is uniform, so we write 0 to say it's a leaf node and the next bit is the color of this region.
			self.out_bytes.addBits([False, c])
		else:
			# The color is not uniform, so we need to split into 4 quads.
			self.out_bytes.addBit(True)

			l = self.split(x, y, w, h)

			for q in l:
				q = self.encode_quad(q[0], q[1], q[2], q[3], data)


	def encode_frame(self, next_frame):
		""" Encodes a frame.
		
			Handles data so that it's only two colors, represented as either a 0 or a 1.
		"""

		# Makes all pixels either a 0 or a 1.
		data = np.rint(np.divide(np.average(next_frame, axis=2), 255))

		# Difference between pixels from the previous frame, as a boolean array.
		# This is the image the encoder actually writes to the file.
		self.diff = np.not_equal(data, self.last)

		
		# Figure out the bounding box of all the different (white) pixels.
		rows = np.any(self.diff, axis=1)
		cols = np.any(self.diff, axis=0)
		if (np.any(rows)):
			y, yh = np.nonzero(rows)[0][[0, -1]]
			x, xw = np.nonzero(cols)[0][[0, -1]]
		else:
			# It has to be -1 since we add one later and we want zero to represent the frame not being changed at all.
			y, yh = 0, -1
			x, xw = 0, -1

		# Write the starting position of the box.
		self.out_bytes.addNumber(x, self._width_bits)
		self.out_bytes.addNumber(y, self._height_bits)

		w = xw - x + 1
		h = yh - y + 1

		w_bits = 0
		h_bits = 0

		while (2 ** w_bits <= self.width - x):
			w_bits += 1
		while (2 ** h_bits <= self.height - y):
			h_bits += 1

		# Write the width of the box.
		self.out_bytes.addNumber(w, w_bits)

		# If width is 0 we know the frame didn't change, so there's no reason to write the height or encode anything.
		if (w != 0):
			# Write the height of the box.
			self.out_bytes.addNumber(h, h_bits)

			# Encode the quad, we already know it splits so we tell it.
			self.encode_quad(x, y, w, h, self.diff)


		self.last = data