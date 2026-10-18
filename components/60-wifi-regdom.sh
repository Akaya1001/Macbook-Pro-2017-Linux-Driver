# shellcheck shell=bash
NAME=wifi-regdom
DESC="Wi-Fi: fixed regulatory country, so 5 GHz no longer drops to 2.4 GHz ~60 s after connecting"
DEFAULT=y
OWN_CONF=/etc/modprobe.d/mbp-cfg80211-regdom.conf
comp_applicable() { lspci -nn 2>/dev/null | grep -c '14e4:43ba' >/dev/null || { echo "no BCM43602 Wi-Fi"; return 1; }; }

_configured_regdom() {  # an ieee80211_regdom set by another modprobe.d file
    grep -rhoP '^\s*options\s+cfg80211\s.*ieee80211_regdom=\K[A-Za-z]{2}' /etc/modprobe.d/ 2>/dev/null \
        --exclude="$(basename "$OWN_CONF")" | tr a-z A-Z | grep -v '^00$' | tail -1
}
_suggest_country() {
    local c tz
    c=$(_configured_regdom)
    [ -z "$c" ] && c=$(iw reg get 2>/dev/null | sed -n 's/^country \([A-Z][A-Z]\):.*/\1/p' | grep -v '^00$' | head -1)
    if [ -z "$c" ] && [ -f /usr/share/zoneinfo/zone.tab ]; then
        tz=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null)
        [ -n "$tz" ] && c=$(awk -v z="$tz" '$3==z{print $1; exit}' /usr/share/zoneinfo/zone.tab)
    fi
    echo "$c"
}
_country() {  # prints the country to use, or nothing (= skip)
    local c=${WIFI_COUNTRY:-} s a
    if [ -n "$c" ]; then echo "$c" | tr a-z A-Z; return; fi
    s=$(_suggest_country)
    if [ -t 0 ] && [ "$ASSUME_YES" != 1 ]; then
        while :; do
            read -r -p "Wi-Fi country code where you use this Mac (ISO 3166, e.g. DE, AT, CH, US)${s:+ [$s]}: " a
            a=${a:-$s}; a=$(echo "$a" | tr a-z A-Z)
            [[ $a =~ ^[A-Z]{2}$ ]] && { echo "$a"; return; }
            echo "please enter a two-letter country code" >&2
        done
    fi
    # non-interactive: only use a country the system itself already reports/configures
    c=$(_configured_regdom)
    [ -z "$c" ] && c=$(iw reg get 2>/dev/null | sed -n 's/^country \([A-Z][A-Z]\):.*/\1/p' | grep -v '^00$' | head -1)
    echo "$c"
}
comp_install() {
    local c other; c=$(_country)
    if [ -z "$c" ]; then
        warn "wifi-regdom skipped: no country known – re-run with --country XX (e.g. --country DE)"
        return 0
    fi
    [[ $c =~ ^[A-Z]{2}$ ]] || die "invalid country code '$c'"
    other=$(_configured_regdom)
    [ -n "$other" ] && [ "$other" != "$c" ] && warn "another file in /etc/modprobe.d sets ieee80211_regdom=$other – remove it, the last file read wins"
    echo "options cfg80211 ieee80211_regdom=$c" | write_file "$NAME" "$OWN_CONF"
    need_reboot
}
comp_check() { [ -f "$OWN_CONF" ]; }
comp_uninstall() { need_reboot; }
