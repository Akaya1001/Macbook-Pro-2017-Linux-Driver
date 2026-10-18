# shellcheck shell=bash
NAME=firmware-backup
DESC="Back up the T1 firmware (EFI/APPLE on the EFI partition) – without it the Touch Bar is gone for good"
DEFAULT=y
comp_applicable() { [ -d /boot/efi/EFI/APPLE ] || { echo "no /boot/efi/EFI/APPLE"; return 1; }; }
comp_install() {
    local dst=/var/backups/mbp2017-linux f tmp
    f=$dst/EFI-APPLE-$(date +%F).tgz
    if [ "$DRY_RUN" = 1 ]; then run tar -C /boot/efi/EFI -czf "$f" APPLE; return 0; fi
    mkdir -p "$dst" && chmod 700 "$dst" || return 1
    tmp=$(mktemp "$dst/.EFI-APPLE.XXXXXX") || return 1
    if ! tar -C /boot/efi/EFI -czf "$tmp" APPLE || ! tar -tzf "$tmp" >/dev/null; then
        rm -f "$tmp"; warn "T1 firmware backup FAILED"; return 1
    fi
    mv -f "$tmp" "$f" && (cd "$dst" && sha256sum "$(basename "$f")" > "$(basename "$f").sha256")
    ok "T1 firmware backed up to $f"
    warn "copy $dst to a USB stick or cloud storage – it is unique to THIS Mac (never use another Mac's FDRData)"
}
comp_check() { ls /var/backups/mbp2017-linux/EFI-APPLE-*.tgz >/dev/null 2>&1; }
comp_uninstall() { :; }   # backups are kept on purpose
