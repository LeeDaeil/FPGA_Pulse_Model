import numpy as np
import matplotlib.pyplot as plt

def lfsr(seed, taps, n_bits):
    sr = seed
    out = []
    for _ in range(n_bits):
        xor = 0
        for t in taps:
            xor ^= (sr >> t) & 1
        sr = ((sr << 1) | xor) & 0xFFFF
        out.append(sr / 0xFFFF)
    return out

vals = lfsr(seed=0xACE1, taps=[0, 2, 3, 5], n_bits=20000)
plt.hist(vals, bins=50)
plt.title("LFSR-based Random Distribution")
plt.show()
