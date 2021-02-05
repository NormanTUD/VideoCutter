#!/usr/bin/python

from __future__ import print_function
import sys
from PIL import Image
import numpy as np
from pprint import pprint
from pathlib import Path

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def avhash(im):
    if not isinstance(im, Image.Image):
        im = Image.open(im)
    im = im.resize((8, 8), Image.ANTIALIAS).convert('1').convert('L')
    avg = reduce(lambda x, y: x + y, im.getdata()) / 64.
    return reduce(lambda x, (y, z): x | (z << y),
                  enumerate(map(lambda i: 0 if i < avg else 1, im.getdata())),
                  0)

def hamming(h1, h2):
    h, d = 0, h1 ^ h2
    while d:
        h += 1
        d &= d - 1
    return h

def phash_simmilarity(img1,img2):
    hash1 = avhash(img1)
    hash2 = avhash(img2)
    dist = hamming(hash1, hash2)
    simm = (64 - dist) * 100 / 64
    return simm

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("Usage: %s threshold folder img2" % sys.argv[0])
    else:
        threshold = sys.argv[1]
        baseimg = sys.argv[2]
        folder = sys.argv[3]

        pathlist = sorted(Path(folder).rglob('*.jpg'))
        i = 1

        max_sim_percent = 0
        max_sim_frame = 0

        for cutframe in pathlist:
            percentage = phash_simmilarity(baseimg, cutframe)
            if max_sim_percent < percentage:
                max_sim_percent = percentage
                max_sim_frame = i
            eprint("%d: %s <-> %s -> %d%%" % (i, baseimg, cutframe, percentage))
            if int(percentage) >= int(threshold):
                print("%d" % (i))
                sys.exit(0)
            i = i + 1

        print("%d" % (max_sim_frame))
        sys.exit(1)
