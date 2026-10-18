# shellcheck shell=bash
NAME=power-profile
DESC="Power profile 'balanced' (the 'performance' profile keeps the Radeon clocked up, ~12 W)"
DEFAULT=n
comp_applicable() { command -v powerprofilesctl >/dev/null || { echo "power-profiles-daemon not installed"; return 1; }; }
comp_install() { run powerprofilesctl set balanced; }
comp_check() { [ "$(powerprofilesctl get 2>/dev/null)" = balanced ]; }
comp_uninstall() { :; }
