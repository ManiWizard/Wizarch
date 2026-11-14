#!/usr/bin/env python3
"""Play a short, volume-limited notification chime through PipeWire."""
import math
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

pattern = sys.argv[1] if len(sys.argv) > 1 else "single"
volume = max(0, min(100, int(sys.argv[2]))) / 100 if len(sys.argv) > 2 else .55
count = {"single": 1, "double": 2, "triple": 3}.get(pattern, 1)
rate = 22050
data = bytearray()
for n in range(count):
    for i in range(int(rate * .15)):
        envelope = min(1, i / 350) * min(1, (rate * .15 - i) / 1100)
        sample = int(9000 * volume * envelope * math.sin(2 * math.pi * (660 + 110 * n) * i / rate))
        data.extend(sample.to_bytes(2, "little", signed=True))
    data.extend(b"\0\0" * int(rate * .09))
with tempfile.NamedTemporaryFile(suffix=".wav") as file:
    with wave.open(file.name, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(data)
    subprocess.run(["pw-play", file.name], timeout=5, check=False)
