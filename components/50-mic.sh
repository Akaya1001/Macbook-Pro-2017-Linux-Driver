# shellcheck shell=bash
NAME=mic
DESC="Internal microphone ~20 dB louder + WebRTC noise filter (PipeWire virtual mic, per user)"
DEFAULT=y
SRC_NODE=alsa_input.pci-0000_00_1f.3.analog-stereo
comp_applicable() {
    [ -n "$TARGET_USER" ] || { echo "run via sudo from your desktop user"; return 1; }
    [ -f /usr/lib/x86_64-linux-gnu/spa-0.2/aec/libspa-aec-webrtc.so ] || { echo "PipeWire WebRTC AEC plugin missing"; return 1; }
    grep -q 0x106b3900 /proc/asound/card*/codec#* 2>/dev/null || { echo "only tested on MacBookPro14,3"; return 1; }
}
_wp_id() {  # node.name -> wpctl id (empty if unknown)
    [ "$DRY_RUN" = 1 ] && return 0
    local j; j=$(as_user pw-dump 2>/dev/null) || return 0
    [ -n "$j" ] || return 0
    printf '%s' "$j" | python3 -c '
import json,sys
for o in json.load(sys.stdin):
  p=(o.get("info") or {}).get("props") or {}
  if p.get("node.name")==sys.argv[1]: print(o["id"]); break' "$1" 2>/dev/null
}
comp_install() {
    write_user_file "$NAME" .config/pipewire/pipewire.conf.d/60-mbp-mic-clean.conf < "$REPO/files/user/60-mbp-mic-clean.conf"
    as_user systemctl --user restart pipewire pipewire-pulse wireplumber || true
    [ "$DRY_RUN" = 1 ] && return 0
    sleep 4
    local hw mc; hw=$(_wp_id "$SRC_NODE"); mc=$(_wp_id mic-clean)
    [ -n "$hw" ] && as_user wpctl set-volume -l 3.0 "$hw" 2.5 && ok "internal mic gain +24 dB"
    [ -n "$mc" ] && as_user wpctl set-default "$mc" && ok "default microphone: 'Microphone (boosted + noise filter)'"
    [ -n "$hw" ] && [ -n "$mc" ] || warn "PipeWire nodes not found yet – log out/in and re-run: sudo ./install.sh --only mic"
}
comp_check() { [ -n "$TARGET_HOME" ] && [ -f "$TARGET_HOME/.config/pipewire/pipewire.conf.d/60-mbp-mic-clean.conf" ]; }
comp_uninstall() {
    local hw; hw=$(_wp_id "$SRC_NODE"); [ -n "$hw" ] && as_user wpctl set-volume "$hw" 1.0
    UNINSTALL_RESTART_PIPEWIRE=1
}
