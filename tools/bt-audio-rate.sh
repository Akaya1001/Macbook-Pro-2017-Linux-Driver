#!/bin/bash
# Measure the Bluetooth A2DP send rate for 60 s while music is playing.
# Healthy SBC playback: a steady ~44-47 kB/s. Big swings or values near 0 = stuttering.
pgrep -x gnome-control-c >/dev/null && echo "WARNING: GNOME Settings is open – its Bluetooth scan makes audio stutter, close it"
bluetoothctl show | grep Discovering
echo ">>> play some music now – measuring for 60 s"
since=$(date '+%H:%M:%S'); p=
for s in $(seq 61); do
    n=$(hciconfig hci0 | awk '/TX bytes/{sub("bytes:","",$2); print $2}')
    if [ -n "$p" ]; then printf "%3d kB/s " $(( (n-p)/1000 )); [ $((s%10)) -eq 0 ] && echo; fi
    p=$n; sleep 1
done
echo; echo "WirePlumber 'missing completion' warnings since $since: $(journalctl --user -u wireplumber --since "$since" --no-pager | grep -ci completion)"
