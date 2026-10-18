# shellcheck shell=bash
NAME=kernel-pin
DESC="Stay on the 7.0 kernel series (linux-generic instead of HWE) so the speaker driver keeps building"
DEFAULT=y
comp_applicable() {
    is_ubuntu || { echo "Ubuntu only"; return 1; }
    dpkg -l 'linux-generic-hwe-*' 2>/dev/null | grep -c '^ii' >/dev/null || { echo "HWE kernel meta package not installed – nothing to do"; return 1; }
}
comp_install() {
    local hwe; hwe=$(dpkg -l 'linux-*-hwe-*' 2>/dev/null | awk '/^ii/{print $2}' | grep -E '^linux-(generic|image-generic|headers-generic)-hwe-' | tr '\n' ' ')
    run apt-get install -y linux-generic
    # shellcheck disable=SC2086
    [ -n "$hwe" ] && run apt-get remove -y $hwe
    run mkdir -p "$STATE_DIR"; [ "$DRY_RUN" = 1 ] || echo "$hwe" > "$STATE_DIR/kernel-pin.removed"
    ok "kernel meta switched to linux-generic (installed kernels are kept)"
    local newest; newest=$(ls /lib/modules 2>/dev/null | sort -V | tail -n1)
    if [[ $KVER != 7.0.0-* ]] || [[ $newest != 7.0.0-* ]]; then
        warn "a non-7.0 kernel ($newest) is installed and GRUB boots the newest one by default:"
        warn "boot 'Advanced options > Ubuntu, with Linux 7.0.0-*' or remove that kernel, then run: sudo ./install.sh --only audio"
    fi
    need_reboot
}
comp_check() { dpkg -l linux-generic 2>/dev/null | grep -c '^ii' >/dev/null; }
comp_uninstall() {
    local hwe; hwe=$(cat "$STATE_DIR/kernel-pin.removed" 2>/dev/null)
    # shellcheck disable=SC2086
    [ -n "$hwe" ] && run apt-get install -y $hwe
    run rm -f "$STATE_DIR/kernel-pin.removed"
}
