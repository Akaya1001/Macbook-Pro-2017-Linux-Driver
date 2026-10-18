#!/bin/bash
# dracut module: hide the amdgpu takeover flicker by turning the gmux backlight off
# until amdgpu has initialised the panel. Only included when requested explicitly.
check() { return 255; }
depends() { echo udev-rules; return 0; }
install() {
    inst_simple "$moddir/gmux-dark.sh" /usr/lib/gmux-dark.sh
    inst_simple "$moddir/91-gmux-dark.rules" /etc/udev/rules.d/91-gmux-dark.rules
    inst_multiple cat sleep rm
}
