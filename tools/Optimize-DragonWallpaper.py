"""Generate and compare a smaller copy of the existing dragon video."""
import argparse
import json
import math
import sys
import time
from fractions import Fraction
from pathlib import Path

import cv2
import numpy as np



def ssim(reference, candidate):
    x = cv2.cvtColor(reference, cv2.COLOR_BGR2GRAY).astype(np.float64)
    y = cv2.cvtColor(candidate, cv2.COLOR_BGR2GRAY).astype(np.float64)
    mx = cv2.GaussianBlur(x, (11, 11), 1.5)
    my = cv2.GaussianBlur(y, (11, 11), 1.5)
    vx = cv2.GaussianBlur(x * x, (11, 11), 1.5) - mx * mx
    vy = cv2.GaussianBlur(y * y, (11, 11), 1.5) - my * my
    cov = cv2.GaussianBlur(x * y, (11, 11), 1.5) - mx * my
    return float(np.mean(((2 * mx * my + 6.5025) * (2 * cov + 58.5225)) /
                         ((mx * mx + my * my + 6.5025) * (vx + vy + 58.5225))))


parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--encoder', choices=('av', 'msmf'), default='av')
args = parser.parse_args()
assert not args.output.exists(), 'Keep previous candidates intact'
source = cv2.VideoCapture(str(args.source))
assert source.isOpened()
fps = source.get(cv2.CAP_PROP_FPS)
size = (int(source.get(cv2.CAP_PROP_FRAME_WIDTH)), int(source.get(cv2.CAP_PROP_FRAME_HEIGHT)))
total = int(source.get(cv2.CAP_PROP_FRAME_COUNT))
if args.encoder == 'av':
    import av
    container = av.open(str(args.output), mode='w', options={'movflags': '+faststart'})
    stream = container.add_stream('libx264', rate=Fraction(fps).limit_denominator(1001))
    stream.width, stream.height = size
    stream.pix_fmt = 'yuv420p'
    stream.options = {'crf': '18', 'preset': 'medium', 'tune': 'animation'}
else:
    writer = cv2.VideoWriter(str(args.output), cv2.CAP_MSMF,
                             cv2.VideoWriter_fourcc(*'H264'), fps, size)
    assert writer.isOpened()
started = time.monotonic()
count = 0
while True:
    ok, frame = source.read()
    if not ok:
        break
    if args.encoder == 'av':
        for packet in stream.encode(av.VideoFrame.from_ndarray(frame, format='bgr24')):
            container.mux(packet)
    else:
        writer.write(frame)
    count += 1
    if count % 48 == 0:
        print(json.dumps({'encoded': count, 'total': total,
                          'seconds': round(time.monotonic() - started, 2)}), flush=True)
if args.encoder == 'av':
    for packet in stream.encode():
        container.mux(packet)
    container.close()
else:
    writer.release()
source.release()
assert count == total

reference = cv2.VideoCapture(str(args.source))
candidate = cv2.VideoCapture(str(args.output))
assert candidate.isOpened()
assert int(candidate.get(cv2.CAP_PROP_FRAME_COUNT)) == total
assert abs(candidate.get(cv2.CAP_PROP_FPS) - fps) < 0.01
samples = []
contact = []
for index in range(total):
    ok_ref, ref = reference.read()
    ok_enc, enc = candidate.read()
    assert ok_ref and ok_enc
    if index % 24 != 0:
        continue
    mse = float(np.mean((ref.astype(np.float32) - enc.astype(np.float32)) ** 2))
    samples.append({'frame': index, 'psnr': 10 * math.log10(255 ** 2 / max(mse, 1e-10)),
                    'ssim': ssim(ref, enc)})
    if index in (0, 72, 144, 216):
        contact.append(np.hstack((cv2.resize(ref, (640, 360)), cv2.resize(enc, (640, 360)))))
reference.release()
candidate.release()
report = {'source': str(args.source), 'output': str(args.output), 'frames': count,
          'fps': fps, 'size': size, 'originalBytes': args.source.stat().st_size,
          'optimizedBytes': args.output.stat().st_size,
          'meanPsnr': sum(s['psnr'] for s in samples) / len(samples),
          'meanSsim': sum(s['ssim'] for s in samples) / len(samples), 'samples': samples}
args.output.with_suffix('.quality.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
cv2.imwrite(str(args.output.with_suffix('.compare.jpg')), np.vstack(contact))
print(json.dumps(report), flush=True)
