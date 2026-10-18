#!/bin/bash
# Test a Bluetooth headset microphone (HFP/HSP): switch to the headset profile, record 5 s,
# print levels, play the recording back, switch back to A2DP.
#   tools/bt-headset-mic-test.sh <MAC> [cvsd|msbc]
set -u
MAC=${1:?usage: $0 <MAC> [cvsd|msbc]   (MAC from: bluetoothctl devices)}; CODEC=${2:-cvsd}
bluetoothctl info "$MAC" | grep -q 'Connected: yes' || bluetoothctl --timeout 10 connect "$MAC" >/dev/null 2>&1
dump() { pw-dump 2>/dev/null; }
D=$(dump | python3 -c "
import json,sys
for o in json.load(sys.stdin):
  p=(o.get('info') or {}).get('props') or {}
  if o['type'].endswith('Device') and p.get('device.api')=='bluez5' and '$MAC'.lower() in str(p.get('api.bluez5.address','')).lower(): print(o['id'])")
[ -n "$D" ] || { echo "headset not connected"; exit 1; }
prof() { pw-dump "$D" 2>/dev/null | python3 -c "
import json,sys
for p in json.load(sys.stdin)[0]['info']['params'].get('EnumProfile',[]):
  if '$1' in p.get('description','') or p.get('name')=='$1': print(p['index']); break"; }
P=$(prof "codec ${CODEC^^}"); [ -n "$P" ] || P=$(prof headset-head-unit)
[ -n "$P" ] || { echo "no headset profile available"; exit 1; }
F=$(mktemp --tmpdir bt-mic.XXXXXX.wav) || exit 1
cleanup() { rm -f "$F"; A=$(prof a2dp-sink); [ -n "$A" ] && wpctl set-profile "$D" "$A"; }
trap cleanup EXIT INT TERM
wpctl set-profile "$D" "$P"; sleep 3
SRC=$(dump | python3 -c "
import json,sys
for o in json.load(sys.stdin):
  p=(o.get('info') or {}).get('props') or {}
  if p.get('media.class')=='Audio/Source' and str(p.get('node.name','')).startswith('bluez_input'): print(p['node.name']); break")
echo "headset mic: ${SRC:-NOT FOUND}"
if [ -n "${SRC:-}" ]; then
    echo ">>> speak for 5 seconds ..."
    timeout 6 pw-record --target "$SRC" --rate 16000 --channels 1 --format s16 "$F" 2>/dev/null
    python3 - "$F" <<'PY'
import sys, wave, struct, math
w = wave.open(sys.argv[1]); n = w.getnframes(); sr = w.getframerate()
s = struct.unpack('<%dh' % n, w.readframes(n))[sr//2:]
if len(s) < sr: print("  no data – the SCO link delivers nothing"); sys.exit()
win = sr//20
r = sorted(math.sqrt(sum(x*x for x in s[i:i+win])/win) or 1 for i in range(0, len(s)-win, win))
db = lambda v: 20*math.log10(v/32768)
print(f"  noise {db(r[len(r)//10]):.1f} dBFS, speech {db(r[3*len(r)//4]):.1f} dBFS (>15 dB apart = good; both ~-90 = silence)")
PY
    pw-play "$F" 2>/dev/null
fi
