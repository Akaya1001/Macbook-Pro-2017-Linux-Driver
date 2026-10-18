# shellcheck shell=bash
# Shared helpers for install.sh / uninstall.sh and the component scripts.
# Every file a component installs goes through install_file/write_file so it is
# recorded in the manifest (and a pre-existing file is backed up) for uninstall.

STATE_DIR=/var/lib/mbp2017-linux
MANIFEST=$STATE_DIR/manifest          # lines: <component>\t<installed path>\t<backup path or ->
BACKUP_DIR=$STATE_DIR/backup
DRY_RUN=${DRY_RUN:-0}
ASSUME_YES=${ASSUME_YES:-0}

c_red=$'\e[31m'; c_grn=$'\e[32m'; c_yel=$'\e[33m'; c_blu=$'\e[34m'; c_off=$'\e[0m'
[ -t 1 ] || { c_red=; c_grn=; c_yel=; c_blu=; c_off=; }

info() { printf '%s==>%s %s\n' "$c_blu" "$c_off" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$c_grn" "$c_off" "$*"; }
warn() { printf '%s warn%s %s\n' "$c_yel" "$c_off" "$*" >&2; }
die()  { printf '%serror%s %s\n' "$c_red" "$c_off" "$*" >&2; exit 1; }

# run a command, or only print it in --dry-run mode
run() {
    if [ "$DRY_RUN" = 1 ]; then printf '     [dry-run] %s\n' "$*"; return 0; fi
    "$@"
}

ask() {  # ask "question" [default y|n] -> 0 = yes
    local q=$1 def=${2:-y} a
    [ "$ASSUME_YES" = 1 ] && [ "$def" = y ] && return 0
    [ "$ASSUME_YES" = 1 ] && return 1
    [ -t 0 ] || { [ "$def" = y ]; return; }
    read -r -p "$q [$( [ "$def" = y ] && echo Y/n || echo y/N )] " a
    a=${a:-$def}; [[ $a =~ ^[YyJj] ]]
}

require_root() { [ "$DRY_RUN" = 1 ] && return 0; [ "$(id -u)" -eq 0 ] || die "please run with sudo: sudo $0 $*"; }

# --- hardware / system detection --------------------------------------------
MODEL=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)
KVER=$(uname -r)
TARGET_USER=${SUDO_USER:-${USER:-}}
[ "$TARGET_USER" = root ] && TARGET_USER=
TARGET_HOME=$( [ -n "$TARGET_USER" ] && getent passwd "$TARGET_USER" | cut -d: -f6 )

is_model() { local m; for m in "$@"; do [ "$MODEL" = "$m" ] && return 0; done; return 1; }
has_t1()   { lsusb -d 05ac:8600 >/dev/null 2>&1 || [ -n "$(grep -l '^8600$' /sys/bus/usb/devices/*/idProduct 2>/dev/null)" ]; }
has_gmux() { [ -d /sys/class/backlight/gmux_backlight ] || grep -q apple_gmux /proc/modules 2>/dev/null; }
is_ubuntu() { grep -qx 'ID=ubuntu' /etc/os-release 2>/dev/null; }
pkg_installed() { dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | grep -q '^.i'; }
uses_dracut() { pkg_installed dracut && [ -d /usr/lib/dracut/modules.d ]; }

# --- manifest-tracked file operations ---------------------------------------
_record() {  # component path backup
    run mkdir -p "$STATE_DIR"
    [ "$DRY_RUN" = 1 ] && return 0
    # drop an older entry for the same path, then append
    if [ -f "$MANIFEST" ]; then grep -v -P "^[^\t]*\t\Q$2\E\t" "$MANIFEST" > "$MANIFEST.tmp" || true; mv "$MANIFEST.tmp" "$MANIFEST"; fi
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$MANIFEST"
}

_backup_once() {  # path -> prints backup path or "-"
    local p=$1 b
    if [ -e "$p" ] && ! grep -q -P "\t\Q$p\E\t" "$MANIFEST" 2>/dev/null; then
        b=$BACKUP_DIR$p
        run mkdir -p "$(dirname "$b")" >&2; run cp -a "$p" "$b" >&2; echo "$b"
    elif [ -f "$MANIFEST" ] && grep -q -P "\t\Q$p\E\t" "$MANIFEST"; then
        grep -P "\t\Q$p\E\t" "$MANIFEST" | tail -1 | cut -f3
    else
        echo -
    fi
}

# install_file <component> <src> <dst> [mode]
install_file() {
    local comp=$1 src=$2 dst=$3 mode=${4:-644} b
    b=$(_backup_once "$dst")
    run install -D -m "$mode" "$src" "$dst"
    _record "$comp" "$dst" "$b"
    ok "installed $dst"
}

# write_file <component> <dst> <mode>  (content from stdin)
write_file() {
    local comp=$1 dst=$2 mode=${3:-644} tmp b
    tmp=$(mktemp); cat > "$tmp"
    b=$(_backup_once "$dst")
    if [ "$DRY_RUN" = 1 ]; then printf '     [dry-run] write %s:\n' "$dst"; sed 's/^/       | /' "$tmp"; rm -f "$tmp"; return 0; fi
    install -D -m "$mode" "$tmp" "$dst"; rm -f "$tmp"
    _record "$comp" "$dst" "$b"
    ok "wrote $dst"
}

# record a directory tree (e.g. /usr/src/<dkms pkg>) for removal on uninstall
record_path() { _record "$1" "$2" -; }

# run a command as the desktop user (for gsettings / wpctl / user config)
as_user() {
    [ -n "$TARGET_USER" ] || { warn "no desktop user found (run via sudo from your user account)"; return 1; }
    local uid; uid=$(id -u "$TARGET_USER")
    run sudo -u "$TARGET_USER" env XDG_RUNTIME_DIR=/run/user/$uid \
        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus HOME="$TARGET_HOME" "$@"
}

# user-owned file (pipewire/wireplumber config) – recorded like system files
write_user_file() {  # component relpath-under-home mode
    [ -n "$TARGET_HOME" ] || { warn "no desktop user – skipping ~/$2"; cat >/dev/null; return 0; }
    as_user mkdir -p "$TARGET_HOME/$(dirname "$2")" || return 1
    write_file "$1" "$TARGET_HOME/$2" "${3:-644}"
    run chown "$TARGET_USER:" "$TARGET_HOME/$2"
}

apt_install() {
    local missing=() p
    for p in "$@"; do pkg_installed "$p" || missing+=("$p"); done
    [ ${#missing[@]} -eq 0 ] && return 0
    info "installing packages: ${missing[*]}"
    run apt-get install -y "${missing[@]}" || die "apt-get install ${missing[*]} failed"
}

rebuild_initramfs() {
    info "rebuilding initramfs for all installed kernels"
    run update-initramfs -u -k all || warn "initramfs rebuild failed for at least one kernel"
}

NEEDS_REBOOT=0
need_reboot() { NEEDS_REBOOT=1; }

# --- DKMS helpers -------------------------------------------------------------
# remove every registered version of a DKMS package (also half-broken ones)
_dkms_purge_all() {
    local pkg=$1 d v
    for d in /var/lib/dkms/"$pkg"/*/; do
        [ -d "$d" ] || continue
        v=$(basename "$d"); [ "$v" = original_module ] && continue
        [ -L "${d%/}" ] && continue          # kernel-<kver>-<arch> symlinks
        run dkms remove "$pkg/$v" --all >/dev/null 2>&1 || run rm -rf "/var/lib/dkms/$pkg/$v"
        run rm -rf "/usr/src/$pkg-$v"
    done
}

# dkms_install_pkg <component> <pkg> <version> <srcdir> all|running+newest
dkms_install_pkg() {
    local comp=$1 pkg=$2 ver=$3 src=$4 scope=$5 dst=/usr/src/$2-$3 k kernels newest
    if [ -n "$(ls /var/lib/dkms/"$pkg" 2>/dev/null)" ] && ! grep -q -P "\t\Q$dst\E\t" "$MANIFEST" 2>/dev/null; then
        warn "an existing DKMS install of $pkg (not made by this tool) will be replaced"
    fi
    _dkms_purge_all "$pkg"
    run cp -a "$src" "$dst"; run chown -R root:root "$dst"
    record_path "$comp" "$dst"
    run dkms add "$pkg/$ver"
    if [ "$scope" = all ]; then
        kernels=$(for k in /lib/modules/*; do [ -e "$k/build" ] && basename "$k"; done)
    else
        newest=$(for k in /lib/modules/*; do [ -e "$k/build" ] && basename "$k"; done | sort -V | tail -n1)
        kernels=$(printf '%s\n' "$KVER" $newest | sort -u)
    fi
    for k in $kernels; do
        info "building $pkg/$ver for $k"
        if run dkms install "$pkg/$ver" -k "$k"; then ok "$pkg built for $k"
        else
            [ "$k" = "$KVER" ] && die "building $pkg for the running kernel failed – see /var/lib/dkms/$pkg/$ver/build/make.log"
            warn "building $pkg for $k failed (not the running kernel – continuing)"
        fi
    done
}
dkms_remove_pkg() { _dkms_purge_all "$1"; }
