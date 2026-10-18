#!/bin/sh
# dark: remember brightness and switch the backlight off | restore [sec]: restore after a delay
B=/sys/class/backlight/gmux_backlight/brightness
F=/run/gmux-boot-brightness
log() { echo "gmux-dark: $*" > /dev/kmsg 2>/dev/null; }
case "$1" in
  dark)    [ -e "$F" ] || cat "$B" > "$F"; echo 0 > "$B"; log "dark (saved $(cat "$F"), now $(cat "$B"))" ;;
  restore) [ -e "$F" ] || { log "restore: nothing saved"; exit 0; }
           log "restore in ${2:-0}s"
           sleep "${2:-0}"
           v=$(cat "$F" 2>/dev/null); [ "${v:-0}" -gt 0 ] 2>/dev/null || v=500
           echo "$v" > "$B" && rm -f "$F"; log "restored $v" ;;
esac
exit 0
