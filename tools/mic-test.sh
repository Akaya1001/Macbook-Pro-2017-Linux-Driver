#!/bin/bash
# Record 6 s from the default microphone (first 0.5 s ignored) and print speech/noise levels in dBFS.
F=$(mktemp --tmpdir mic-test.XXXXXX.wav) || exit 1
trap 'rm -f "$F"' EXIT
echo ">>> NOW speak normally for 5 seconds ..."
timeout 6 pw-record --rate 48000 --channels 2 --format s16 "$F" 2>/dev/null
python3 - "$F" <<'PY'
import sys, wave, struct, math
w = wave.open(sys.argv[1]); n = w.getnframes(); ch = w.getnchannels(); sr = w.getframerate()
d = struct.unpack('<%dh' % (n*ch), w.readframes(n)); s = d[0::ch][sr//2:]
win = sr//20
r = sorted(math.sqrt(sum(x*x for x in s[i:i+win])/win) or 1 for i in range(0, len(s)-win, win))
db = lambda v: 20*math.log10(v/32768)
pk = max(abs(x) for x in s) or 1
print(f"Noise  (quietest 10%): {db(r[len(r)//10]):.1f} dBFS")
print(f"Speech (loudest 25%) : {db(r[3*len(r)//4]):.1f} dBFS   (target for calls: about -25 to -18)")
print(f"Peak: {db(pk):.1f} dBFS")
PY
echo done
