# shellcheck shell=bash
NAME=boot-splash
DESC="Clean boot screen: early amdgpu + hide the unavoidable amdgpu takeover flicker (backlight off for ~7 s)"
DEFAULT=y
comp_applicable() {
    is_model MacBookPro14,3 || { echo "only for the 15\" dual-GPU MacBookPro14,3"; return 1; }
    has_gmux || { echo "no apple_gmux backlight"; return 1; }
    uses_dracut || { echo "needs dracut (Ubuntu 26.04 default)"; return 1; }
}
comp_install() {
    write_file "$NAME" /etc/dracut.conf.d/20-mbp-early-kms.conf <<'X'
# MacBookPro14,3: the internal panel is driven by the Radeon (amdgpu) – load it early.
add_drivers+=" apple_gmux amdgpu "
X
    write_file "$NAME" /etc/dracut.conf.d/21-mbp-gmux-dark.conf <<'X'
add_dracutmodules+=" gmuxdark "
X
    local m=/usr/lib/dracut/modules.d/95gmuxdark
    install_file "$NAME" "$REPO/files/dracut/95gmuxdark/module-setup.sh"    $m/module-setup.sh 755
    install_file "$NAME" "$REPO/files/dracut/95gmuxdark/gmux-dark.sh"       $m/gmux-dark.sh 755
    install_file "$NAME" "$REPO/files/dracut/95gmuxdark/91-gmux-dark.rules" $m/91-gmux-dark.rules
    install_file "$NAME" "$REPO/files/dracut/95gmuxdark/gmux-dark.sh"       /usr/local/sbin/mbp-gmux-dark 755
    install_file "$NAME" "$REPO/files/systemd/mbp-gmux-restore-brightness.service" /etc/systemd/system/mbp-gmux-restore-brightness.service
    # merge UseSimpledrm=0 into plymouthd.conf (keep other admin settings; the original is backed up)
    local pc=/etc/plymouth/plymouthd.conf cur
    cur=$(cat "$pc" 2>/dev/null || printf '# Administrator customizations go in this file\n')
    if grep -qE '^[[:space:]]*UseSimpledrm[[:space:]]*=' <<<"$cur"; then
        cur=$(sed -E 's/^[[:space:]]*UseSimpledrm[[:space:]]*=.*/UseSimpledrm=0/' <<<"$cur")
    elif grep -qE '^[[:space:]]*\[Daemon\]' <<<"$cur"; then
        cur=$(sed -E '0,/^[[:space:]]*\[Daemon\]/s//[Daemon]\nUseSimpledrm=0/' <<<"$cur")
    else
        cur+=$'\n# MacBookPro14,3: wait for amdgpu instead of starting on simpledrm\n[Daemon]\nUseSimpledrm=0'
    fi
    printf '%s\n' "$cur" | write_file "$NAME" "$pc"
    run systemctl daemon-reload
    run systemctl enable mbp-gmux-restore-brightness.service
    rebuild_initramfs
    info "if the screen ever stays dark after boot: press the brightness-up key"
    need_reboot
}
comp_check() { [ -f /etc/dracut.conf.d/21-mbp-gmux-dark.conf ] && [ -f /usr/lib/dracut/modules.d/95gmuxdark/module-setup.sh ]; }
comp_uninstall() {
    run systemctl disable mbp-gmux-restore-brightness.service 2>/dev/null || true
    UNINSTALL_REBUILD_INITRAMFS=1; need_reboot
}
