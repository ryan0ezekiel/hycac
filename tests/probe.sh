#!/bin/bash
# probe.sh - thorough HYCAC live-ISO interrogation over SSH
# usage: probe.sh   -> prints PASS/FAIL table, exit code = number of failures
SSH="ssh -p 2223 -i /tmp/opencode/vmtest-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 hycac@localhost"

pass=0; fail=0; failed_names=""

check() { # name, command, expect_regex, mode(normal|empty|count_max:N)
    local name="$1" cmd="$2" want="$3" mode="${4:-normal}" out rc
    out=$($SSH "$cmd" 2>/dev/null); rc=$?
    local ok=0
    case "$mode" in
        normal) [[ $rc -eq 0 && "$out" =~ $want ]] && ok=1 ;;
        empty)  [[ -z "$(echo "$out" | tr -d '[:space:]')" ]] && ok=1 ;;
        count_max:*) local lim="${mode#count_max:}" n
                    n=$(echo "$out" | grep -c . ); [ "$n" -le "$lim" ] && ok=1 ;;
    esac
    if [ $ok -eq 1 ]; then
        echo "PASS  $name"; pass=$((pass+1))
    else
        echo "FAIL  $name   (got: $(echo "$out" | head -2 | tr '\n' '|'))"
        fail=$((fail+1)); failed_names="$failed_names $name"
    fi
}

echo "== HYCAC live ISO probe battery =="
check "hycac-home.service active"   "systemctl is-active hycac-home.service" "^active$"
check "override script exec bit"    "test -x /usr/local/bin/hycac-apply-overrides && echo yes" "yes"
check "os-release is HYCAC"         "grep ^NAME /etc/os-release"             "HYCAC"
check "wallpaper path in settings"  "grep -c 'backgrounds/hycac/hycac-wallpaper.png' ~/.local/state/noctalia/settings.toml" "^3$"
check "niri keybinds present"       "test -s ~/.config/niri/cfg/keybinds.kdl && echo yes" "yes"
check "niri user session running"   "systemctl --user is-active niri.service" "active"
check "noctalia process alive"      "pgrep -x noctalia >/dev/null && echo yes || ps aux | grep -c '[n]octalia-resilient'" "yes"
check "greetd active"               "systemctl is-active greetd.service"     "^active$"
check "fish is the shell"           "echo \$SHELL"                           "/bin/fish"
check "evince installed"            "pacman -Q evince"                       "^evince"
check "opencode installed"          "pacman -Q opencode"                     "^opencode"
check "rapidraw installed"          "pacman -Q rapidraw-bin"                 "^rapidraw-bin"
check "helium removed"              "pacman -Q helium-browser-bin >/dev/null 2>&1 || echo absent" "absent"
check "telegram removed"            "pacman -Q telegram-desktop >/dev/null 2>&1 || echo absent" "absent"
check "okular removed"              "pacman -Q okular >/dev/null 2>&1 || echo absent" "absent"
check "meslo removed"               "pacman -Q ttf-meslo-nerd >/dev/null 2>&1 || echo absent" "absent"
check "opencode config shipped"     "ls ~/.config/opencode/opencode.jsonc"   "opencode.jsonc"
check "zram swap active"            "swapon --show --noheadings"             "zram0"
check "NetworkManager active"       "systemctl is-active NetworkManager"     "^active$"
check "internet reachable"          "curl -sm8 -o /dev/null -w '%{http_code}' https://archlinux.org" "200"
check "ufw firewall active"         "sudo -n ufw status | head -1"           "Status: active"
check "fastfetch runs"              "fastfetch | wc -l"                      "[1-9]"
check "pipewire user service"       "systemctl --user is-active pipewire.service" "^active$"
check "pdf handler is evince"       "grep Evince ~/.config/mimeapps.list"    "Evince"
check "no failed system units"      "systemctl --failed --no-legend --plain" "" empty
check "no failed user units"        "systemctl --user --failed --no-legend --plain" "" empty
check "kernel errors <= 5"          "sudo -n dmesg -l err,crit,alert,emerg --notime | sort -u" "" count_max:5
check "plymouth theme default"      "readlink /usr/share/plymouth/themes/default.plymouth" "hycac/hycac.plymouth"
check "plymouth theme in initramfs" "sudo -n lsinitcpio -l /run/archiso/bootmnt/arch/boot/x86_64/initramfs-linux-cachyos.img | grep -c themes/hycac" "[1-9]"
check "splash on kernel cmdline"    "grep -o 'quiet splash' /proc/cmdline" "quiet splash"
check "hostname is hycac"           "cat /etc/hostname" "^hycac"
check "issue is HYCAC-branded"      "grep -c '^HYCAC' /etc/issue" "^1\$"
check "fastfetch shows HYCAC"       "grep -c 'hycac-ascii.txt' ~/.config/fastfetch/config.jsonc" "^1\$"
check "keyring seed present"        "ls ~/.local/share/keyrings/default >/dev/null && cat ~/.local/share/keyrings/default" "Default_keyring"
check "gparted wrapper live"        "test -x /usr/local/bin/gparted && pacman -Q gparted >/dev/null && echo ready" "ready"
check "polkit nopasswd for wheel"   "sudo -n sh -c 'grep -l wheel /etc/polkit-1/rules.d/*.rules'" "nopasswd_global"

echo "== verdict =="
echo "passed: $pass   failed: $fail"
[ -n "$failed_names" ] && echo "failures:$failed_names"
exit $fail
