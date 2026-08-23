#!/bin/bash
# vm-boot.sh - boot the HYCAC ISO headless and prepare SSH access
set -u
ISO="${1:-$(ls -t out/hycac/*.iso 2>/dev/null | head -1)}"
LOG=/tmp/opencode/serial.log
CTL=/tmp/opencode/serial-ctl

pkill -9 -f '[q]emu-system-x86_64' 2>/dev/null; sleep 1
rm -f "$LOG" "$CTL" /tmp/opencode/qemu-mon

ISO_UUID=$(blkid -s UUID -o value "$ISO")
echo "iso uuid: $ISO_UUID"

setsid qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 4 -m 3G \
  -kernel /tmp/opencode/vmlinuz-linux-cachyos \
  -initrd /tmp/opencode/initramfs-linux-cachyos.img \
  -append "archisobasedir=arch archisosearchuuid=$ISO_UUID cow_spacesize=10G module_blacklist=pcspkr i915.modeset=1 amdgpu.modeset=1 nvme_load=yes console=ttyS0" \
  -cdrom "$ISO" \
  -display none -vga std \
  -monitor unix:/tmp/opencode/qemu-mon,server,nowait \
  -chardev socket,id=ser0,path=$CTL,server=on,wait=off,logfile=$LOG \
  -serial chardev:ser0 \
  -netdev user,id=n0,hostfwd=tcp::2223-:22 -device virtio-net-pci,netdev=n0 \
  </dev/null >>/tmp/opencode/qemu.log 2>&1 &
echo "VM launched"

# wait for login prompt on serial (max 240s)
for i in $(seq 1 48); do
    sleep 5
    grep -aq 'CachyOS login:' "$LOG" && break
done
grep -aq 'CachyOS login:' "$LOG" || { echo "FAIL: no login prompt after 240s"; exit 1; }
echo "login prompt reached after ~$((i*5))s"

send() { printf '%s\n' "$1" | socat - "unix-connect:$CTL" >/dev/null 2>&1; sleep 1; }

sleep 2
send "hycac"          # username
sleep 3
send ""               # empty password
sleep 3
send "true"           # confirm shell is live
sleep 2

# inject test pubkey for SSH (fish syntax)
PUB=$(cat /tmp/opencode/vmtest-key.pub)
send "mkdir -p ~/.ssh"
send "echo '$PUB' > ~/.ssh/authorized_keys"
send "chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys"
send "systemctl start sshd.service 2>/dev/null; or true"
sleep 4

# wait for sshd to answer on forwarded port
for i in $(seq 1 12); do
    if ssh -p 2223 -i /tmp/opencode/vmtest-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4 hycac@localhost true 2>/dev/null; then
        echo "SSH channel open"
        exit 0
    fi
    sleep 5
done
echo "FAIL: ssh never came up"
exit 1
