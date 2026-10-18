#!/bin/bash
# Remove everything installed by install.sh (restores backed-up files).
#   sudo ./uninstall.sh                 remove all components
#   sudo ./uninstall.sh --only audio    remove selected components
#   sudo ./uninstall.sh --dry-run       show what would be removed
exec "$(dirname "$(readlink -f "$0")")/install.sh" --uninstall "$@"
