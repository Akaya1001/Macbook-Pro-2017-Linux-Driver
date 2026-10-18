#!/bin/bash
# MacBook Pro 2017 (MacBookPro14,3) Linux driver & fix installer.
# https://github.com/Akaya1001/Macbook-Pro-2017-Linux-Driver
#
#   sudo ./install.sh                 interactive: asks for every component
#   sudo ./install.sh --yes           install all recommended components without asking
#   sudo ./install.sh --all           install every applicable component without asking
#                                     (keyboard-iso only together with --iso-keyboard)
#   sudo ./install.sh --only touchbar,audio   (required components such as ibridge are added)
#   sudo ./install.sh --skip boot-splash
#   sudo ./install.sh --dry-run       show what would be done, change nothing
#        ./install.sh --list          list components and whether they apply to this Mac
#        ./install.sh --check         show what is installed
#   sudo ./install.sh --uninstall [--only x,y]   remove (and restore backed-up files)
#
# Options: --country XX (Wi-Fi regulatory domain), --iso-keyboard, --force (unsupported model)
set -uo pipefail
REPO=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
# shellcheck source=lib/common.sh
. "$REPO/lib/common.sh"

MODE=install ONLY= SKIP= ALL=0 FORCE=0 ISO=0
while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y) ASSUME_YES=1 ;;
        --all) ALL=1 ;;
        --only|--skip|--country) [ $# -ge 2 ] && [[ $2 != -* ]] || die "$1 needs a value (see --help)" ;;&
        --only) ONLY=$2; shift ;;
        --only=*) ONLY=${1#*=} ;;
        --skip) SKIP=$2; shift ;;
        --skip=*) SKIP=${1#*=} ;;
        --dry-run|-n) DRY_RUN=1 ;;
        --list) MODE=list ;;
        --check) MODE=check ;;
        --uninstall) MODE=uninstall ;;
        --country) WIFI_COUNTRY=$2; shift ;;
        --country=*) WIFI_COUNTRY=${1#*=} ;;
        --iso-keyboard) ISO=1 ;;
        --force) FORCE=1 ;;
        -h|--help) awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/,""); print}' "$0"; exit 0 ;;
        *) die "unknown option: $1 (see --help)" ;;
    esac
    shift
done
export DRY_RUN ASSUME_YES WIFI_COUNTRY

in_list() { [[ ",$2," == *",$1,"* ]]; }

load_component() {  # file -> defines NAME DESC DEFAULT REQUIRES comp_*
    unset -f comp_applicable comp_install comp_check comp_uninstall 2>/dev/null
    NAME= DESC= DEFAULT=n REQUIRES=
    # shellcheck source=/dev/null
    . "$1"
}

banner() {
    local codec t1=no gm=no
    codec=$(grep -h 'Subsystem Id' /proc/asound/card*/codec#* 2>/dev/null | awk '{print $3}' | head -1)
    has_t1 && t1=yes; has_gmux && gm=yes
    local distro; distro=$(sed -n 's/^PRETTY_NAME="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' /etc/os-release 2>/dev/null)
    info "MacBook Pro 2017 Linux driver installer"
    printf '     model: %s | %s | kernel %s | T1: %s | gmux: %s | audio codec: %s\n' \
        "$MODEL" "${distro:-?}" "$KVER" "$t1" "$gm" "${codec:-?}"
    [ "$DRY_RUN" = 1 ] && warn "dry-run: nothing will be changed"
}

model_gate() {
    is_model MacBookPro14,3 && return 0
    if is_model MacBookPro14,1 MacBookPro14,2; then
        warn "$MODEL is UNTESTED – only components that detect matching hardware will be offered"
        return 0
    fi
    [ "$FORCE" = 1 ] && { warn "$MODEL is not a MacBook Pro 2017 – continuing because of --force"; return 0; }
    die "this is a '$MODEL', not a MacBook Pro 2017 (MacBookPro14,x). Use --force at your own risk."
}

# ------------------------------------------------------------------------------
do_list() {
    local f why
    printf '%-20s %-12s %-8s %s\n' COMPONENT DEFAULT APPLIES DESCRIPTION
    for f in "$REPO"/components/*.sh; do
        load_component "$f"
        if why=$(comp_applicable 2>&1); then a=yes; else a="no"; fi
        printf '%-20s %-12s %-8s %s\n' "$NAME" "$([ "$DEFAULT" = y ] && echo recommended || echo optional)" "$a" "$DESC"
        if [ "$a" = no ] && [ -n "$why" ]; then printf '%-42s (%s)\n' "" "$why"; fi
    done
    true
}

do_check() {
    local f
    for f in "$REPO"/components/*.sh; do
        load_component "$f"
        comp_applicable >/dev/null 2>&1 || { printf '  %-20s n/a\n' "$NAME"; continue; }
        if comp_check 2>/dev/null; then printf '  %s%-20s installed%s\n' "$c_grn" "$NAME" "$c_off"
        else printf '  %-20s not installed\n' "$NAME"; fi
    done
    true
}

# files from a manual setup (earlier versions of these fixes, other guides) that would clash
LEGACY=(
    /etc/modprobe.d/t1-touchbar.conf /etc/modprobe.d/t1-ibridge-no-sensorhub.conf /etc/modprobe.d/cfg80211-regdom.conf
    /etc/udev/rules.d/99-ibridge.rules /etc/udev/rules.d/90-mbp143-pm.rules
    /usr/lib/systemd/system-sleep/tb-s2idle /usr/lib/systemd/system-sleep/t1-touchbar
    /usr/local/sbin/t1-touchbar-bind /usr/local/sbin/gmux-dark
    /etc/systemd/system/t1-touchbar-bind.service /etc/systemd/system/gmux-restore-brightness.service
    /etc/systemd/sleep.conf.d/10-s2idle.conf /etc/systemd/logind.conf.d/10-lid.conf
    /etc/dracut.conf.d/20-early-kms.conf /etc/dracut.conf.d/21-gmux-dark.conf /etc/default/grub.d/91-applespi-iso.cfg
)
legacy_check() {
    local f found=()
    for f in "${LEGACY[@]}"; do [ -e "$f" ] && found+=("$f"); done
    [ -n "$TARGET_HOME" ] && for f in .config/pipewire/pipewire.conf.d/60-mic-clean.conf .config/wireplumber/wireplumber.conf.d/51-bluez-no-msbc.conf; do
        [ -e "$TARGET_HOME/$f" ] && found+=("$TARGET_HOME/$f"); done
    [ -d /usr/lib/dracut/modules.d/95gmuxdark ] && ! grep -q 95gmuxdark "$MANIFEST" 2>/dev/null && found+=(/usr/lib/dracut/modules.d/95gmuxdark)
    [ ${#found[@]} -eq 0 ] && return 0
    warn "found files from an earlier manual setup that would clash with this installer:"
    printf '       %s\n' "${found[@]}" >&2
    warn "move them away first (e.g. sudo mkdir -p /root/mbp-legacy && sudo mv <files> /root/mbp-legacy/), or use --force to continue anyway"
    [ "$FORCE" = 1 ] || [ "$DRY_RUN" = 1 ] || exit 1
}

do_install() {
    require_root
    model_gate
    local t; for t in apt-get dpkg-query update-initramfs update-grub; do
        command -v "$t" >/dev/null || { [ "$FORCE" = 1 ] && warn "$t missing" || die "this installer needs Ubuntu (missing $t) – use --force to try anyway"; }
    done
    is_ubuntu || warn "only tested on Ubuntu 26.04 – other distributions may not work"
    legacy_check
    # --only: add required components automatically
    if [ -n "$ONLY" ]; then
        for f in "$REPO"/components/*.sh; do
            load_component "$f"
            if in_list "$NAME" "$ONLY" && [ -n "$REQUIRES" ] && ! in_list "$REQUIRES" "$ONLY"; then
                ONLY+=",$REQUIRES"; info "adding required component '$REQUIRES' (needed by $NAME)"
            fi
        done
    fi
    [ "$DRY_RUN" = 1 ] || { apt-get update -qq || warn "apt-get update failed"; }
    local f why done_list=" " sel
    for f in "$REPO"/components/*.sh; do
        load_component "$f"
        [ -n "$ONLY" ] && ! in_list "$NAME" "$ONLY" && continue
        [ -n "$SKIP" ] && in_list "$NAME" "$SKIP" && continue
        if ! why=$(comp_applicable 2>&1); then
            [ -n "$ONLY" ] && warn "$NAME: not applicable – $why" || info "skip $NAME ($why)"
            continue
        fi
        [ "$NAME" = keyboard-iso ] && [ "$ISO" = 1 ] && DEFAULT=y
        if [ -n "$REQUIRES" ] && [[ $done_list != *" $REQUIRES "* ]] && ! (load_component "$REPO"/components/*-"$REQUIRES".sh; comp_check) ; then
            warn "$NAME needs '$REQUIRES' – installing it is recommended"
        fi
        sel=n
        if [ -n "$ONLY" ]; then sel=y
        elif [ "$ALL" = 1 ] && { [ "$NAME" != keyboard-iso ] || [ "$ISO" = 1 ]; }; then sel=y
        elif ask "Install $NAME – $DESC?" "$DEFAULT"; then sel=y; fi
        [ "$sel" = y ] || { info "skipped $NAME"; continue; }
        info "installing $NAME"
        comp_install || die "$NAME failed"
        done_list+="$NAME "
        [ "$DRY_RUN" = 1 ] || { mkdir -p "$STATE_DIR"; grep -qx "$NAME" "$STATE_DIR/installed" 2>/dev/null || echo "$NAME" >> "$STATE_DIR/installed"; }
    done
    echo
    ok "done:${done_list}"
    [ "$NEEDS_REBOOT" = 1 ] && warn "please REBOOT now to activate the changes"
    true
}

do_uninstall() {
    require_root
    [ -f "$MANIFEST" ] || [ -f "$STATE_DIR/installed" ] || die "nothing installed by this tool"
    local files comp line path backup
    mapfile -t files < <(ls -r "$REPO"/components/*.sh)
    UNINSTALL_REBUILD_INITRAMFS=0 UNINSTALL_UPDATE_GRUB=0 UNINSTALL_RESTART_PIPEWIRE=0
    for f in "${files[@]}"; do
        load_component "$f"
        [ -n "$ONLY" ] && ! in_list "$NAME" "$ONLY" && continue
        grep -qx "$NAME" "$STATE_DIR/installed" 2>/dev/null || grep -q "^$NAME	" "$MANIFEST" 2>/dev/null || continue
        info "removing $NAME"
        comp_uninstall || warn "$NAME: uninstall step reported a problem"
        # remove recorded files (newest first), restore backups
        if [ -f "$MANIFEST" ]; then
            tac "$MANIFEST" | while IFS=$'\t' read -r comp path backup; do
                [ "$comp" = "$NAME" ] || continue
                if [ "$backup" != - ] && [ -e "$backup" ]; then run cp -a "$backup" "$path"; ok "restored $path"
                else run rm -rf "$path"; ok "removed $path"; fi
            done
            [ "$DRY_RUN" = 1 ] || { grep -v "^$NAME	" "$MANIFEST" > "$MANIFEST.tmp" || true; mv "$MANIFEST.tmp" "$MANIFEST"; }
        fi
        [ "$DRY_RUN" = 1 ] || sed -i "/^$NAME\$/d" "$STATE_DIR/installed" 2>/dev/null
    done
    run systemctl daemon-reload
    run udevadm control --reload
    [ "$UNINSTALL_UPDATE_GRUB" = 1 ] && run update-grub
    [ "$UNINSTALL_REBUILD_INITRAMFS" = 1 ] && rebuild_initramfs
    [ "$UNINSTALL_RESTART_PIPEWIRE" = 1 ] && { as_user systemctl --user restart pipewire pipewire-pulse wireplumber || true; }
    ok "uninstall finished"
    [ "$NEEDS_REBOOT" = 1 ] && warn "please REBOOT now"
    true
}

banner
case $MODE in
    list) do_list ;;
    check) do_check ;;
    install) do_install ;;
    uninstall) do_uninstall ;;
esac
