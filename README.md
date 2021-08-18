# QuadTree Compression for ComputerCraft Videos

## Problem
Videos are big, like really big. ComputerCraft only has 1 MB of space by default. I want to play Bad Apple!! on them at a decent resolution. I used a QuadTree structure to achieve that.

## Requirements
### For decoding
It's already included, I just wanted to link it.
 - [wave](https://github.com/CrazedProgrammer/wave)

### For encoding
You can install those with pip.
 - numpy
 - moviepy

## How to use
Use `py encoder.py -c quadtree -i <video file> -o <output file>` to convert a file, then get that file on a computer with the video player and run `videoplayer <qtv file>`. The file must have a .qtv extension, and the name given to the Lua program must not include it. It's done this way because to play audio it simply reads a .nbs file with the same name. Not optimal, but I wanted to have something that worked quickly, so some sacrifices had to be made.

## License
Do whatever, use, copy, redistribute, just make sure you're not taking credit for my work.

Also, you know the deal, I'm not responsible if you computer blows up.