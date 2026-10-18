# shellcheck shell=bash
NAME=suspend
DESC="Lid close = sleep that actually wakes up again (s2idle instead of the hanging S3 'deep', PCI power pinning)"
DEFAULT=y
comp_applicable() { is_model MacBookPro14,1 MacBookPro14,2 MacBookPro14,3 || { echo "only for MacBookPro14,x"; return 1; }; }
comp_install() {
    write_file "$NAME" /etc/systemd/sleep.conf.d/10-mbp-s2idle.conf <<'X'
# MacBook Pro 2017: S3 "deep" never resumes -> use s2idle
[Sleep]
MemorySleepMode=s2idle
X
    install_file "$NAME" "$REPO/files/udev/90-mbp-pm.rules" /etc/udev/rules.d/90-mbp-pm.rules
    write_file "$NAME" /etc/systemd/logind.conf.d/10-mbp-lid.conf <<'X'
# MacBook Pro 2017: close the lid -> suspend (s2idle, see /etc/systemd/sleep.conf.d/10-mbp-s2idle.conf)
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
X
    run udevadm control --reload
    need_reboot
}
comp_check() { [ -f /etc/systemd/sleep.conf.d/10-mbp-s2idle.conf ] && [ -f /etc/udev/rules.d/90-mbp-pm.rules ]; }
comp_uninstall() { run udevadm control --reload; need_reboot; }
