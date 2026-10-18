"""Build a moving continuation from the original pre-transition dragon scene."""
from fractions import Fraction
from pathlib import Path
import json
import math
import sys

import cv2

root = Path(__file__).resolve().parents[1]
import av

(root / 'qa').mkdir(exist_ok=True)

source = cv2.VideoCapture(str(root / 'media/startup.mp4'))
assert source.isOpened()
fps = int(source.get(cv2.CAP_PROP_FPS))
first, last = 11.5, 12.125
frames = {}
source.set(cv2.CAP_PROP_POS_FRAMES, int(first * fps))
for index in range(int(first * fps), math.ceil(last * fps) + 2):
    ok, frame = source.read()
    assert ok
    frames[index] = frame
source.release()
output = root / 'qa/continuity-cycle.mp4'
container = av.open(str(output), 'w', options={'movflags': '+faststart'})
stream = container.add_stream('libx264', rate=Fraction(fps))
stream.width, stream.height = frames[min(frames)].shape[1], frames[min(frames)].shape[0]
stream.pix_fmt = 'yuv420p'
stream.options = {'crf': '18', 'preset': 'fast', 'tune': 'animation'}
count = fps * 2
for index in range(count):
    seconds = (first + last) / 2 + (last - first) / 2 * math.cos(2 * math.pi * index / count)
    position = seconds * fps
    lower = math.floor(position)
    amount = position - lower
    frame = cv2.addWeighted(frames[lower], 1 - amount, frames[lower + 1], amount, 0)
    for packet in stream.encode(av.VideoFrame.from_ndarray(frame, format='bgr24')):
        container.mux(packet)
for packet in stream.encode():
    container.mux(packet)
container.close()
# Repeat compressed cycles on a single continuous media timeline. The decoder
# does not need to stop, seek and restart every two seconds on slow startup.
input_container = av.open(str(output))
input_stream = input_container.streams.video[0]
packets = [(bytes(packet), packet.pts, packet.dts, packet.duration, packet.is_keyframe)
           for packet in input_container.demux(input_stream) if packet.dts is not None]
assert packets and packets[0][4]
destination = root / 'qa/continuity-continuous.mp4'
long_container = av.open(str(destination), 'w', options={'movflags': '+faststart'})
long_stream = long_container.add_stream_from_template(input_stream)
cycle_ticks = int(Fraction(count, fps) / input_stream.time_base)
cycles = 45
for cycle in range(cycles):
    for data, pts, dts, duration, keyframe in packets:
        packet = av.Packet(data)
        packet.pts = pts + cycle * cycle_ticks
        packet.dts = dts + cycle * cycle_ticks
        packet.duration = duration
        packet.time_base = input_stream.time_base
        packet.stream = long_stream
        packet.is_keyframe = keyframe
        long_container.mux(packet)
long_container.close()
input_container.close()
decoded = cv2.VideoCapture(str(destination))
assert decoded.isOpened()
assert int(decoded.get(cv2.CAP_PROP_FRAME_COUNT)) == count * cycles
boundary_motion = []
decoded.set(cv2.CAP_PROP_POS_FRAMES, count - 3)
previous = None
for index in range(6):
    ok, frame = decoded.read()
    assert ok
    if previous is not None:
        boundary_motion.append(float(cv2.absdiff(frame, previous).mean()))
    previous = frame
decoded.release()
assert all(amount > .01 for amount in boundary_motion), 'The loop boundary must contain motion'
report = {'output': str(destination), 'frames': count * cycles, 'fps': fps,
          'sourceInterval': [first, last], 'seconds': count * cycles / fps,
          'bytes': destination.stat().st_size, 'boundaryMotion': boundary_motion}
print(json.dumps(report))
(root / 'qa/continuity-video.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
