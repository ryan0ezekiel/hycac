# Audit Report — "Helheim ISO"
### Goal: a light, personal live ISO that mirrors sir's current system, setup, and applications
*Audit performed 2026-08-22 · working fork: `~/Projects/ISO/CachyOS-Live-ISO`*

---

## 1. What we have today

**Proof-of-concept build:** `cachyos-desktop-linux-260822.iso` — **3.7 GB**, 1,173 packages,
built from the stock CachyOS *desktop* profile + our 31 added packages.
It boots, but it ships **CachyOS's KDE desktop**, not sir's system. It is CachyOS with sir's apps bolted on.
The goal now is the opposite: **sir's niri+Noctalia system as the star, CachyOS bits trimmed to fit.**

---

## 2. Audit of sir's current system

| Aspect | Finding |
|---|---|
| User / shell | `helheim`, fish (`cachyos-fish-config`) |
| Session | **greetd → autologin straight into `niri-session`** (no greeter menu!) |
| Desktop stack | `cachyos-niri-noctalia` 1.4.0 meta-pkg → niri, noctalia, xwayland-satellite, portals (gnome/gtk), gnome-keyring, adw-gtk-theme, capitaine-cursors |
| Kernel | `linux-cachyos` 7.2.0 running; `linux-cachyos-lts` kept as fallback |
| Boot | Limine + snapper-sync on btrfs subvolumes, Plymouth theme |
| GPU | Hybrid: Intel UHD 620 (**intel-media-driver, vulkan-intel**) + MX150 Pascal (**nvidia-580xx-dkms/utils/settings**, ~1.4 GB incl. lib32) |
| Explicit packages | **222** (of 1234 total) |
| Flatpaks | Flatseal, RapidRAW, Warehouse, Baobab, Telegram |
| Services enabled | NetworkManager (+dispatcher), sshd, ufw, ananicy-cpp, avahi, bluetooth, cups(+socket/path), snapper-cleanup, limine-snapper-sync, systemd-resolved, fstrim, cpupower |
| User services | pipewire/pulse sockets, wireplumber, shelly-notifications, gnome-keyring socket |

### Configs worth carrying into the ISO (~/.config)
Small and precious: `niri/` (48K), `noctalia/`, `fish/` (28K), `alacritty/`, `foot/`, `shelly/`,
`micro/`, `mpv/`, `gtk-3.0/`, `gtk-4.0/`, `starship.toml`, `mimeapps.list`,
`user-dirs.dirs/locale`, `autostart/`, `systemd/user/`.

**Must NOT be baked in:** `mozilla/` (124 MB app data), `net.imput.helium/` (72 MB),
`opencode/` (62 MB — contains auth tokens!), browser caches, `gh/` tokens.

### Biggest installed packages (size context)
nvidia-580xx-utils 903M · helium-browser-bin 460M · zed 341M · noto-fonts-cjk 299M ·
firefox 294M · qt6-webengine 282M · lib32-nvidia-580xx 277M · ttf-meslo-nerd 202M

---

## 3. Why the current ISO weighs 3.7 GB

The stock profile was built for a rescue/install DVD for everyone. Sir needs none of:

| Bloat block | Installed-size estimate | Notes |
|---|---|---|
| **KDE Plasma stack** (plasma-desktop, -workspace, -nm, -pa, kinfocenter, kscreen, bluedevil, breeze, spectacle, dolphin, konsole, kate, kcalc, partitionmanager…) | ~1.2–1.5 GB | sir runs niri; all of it unused |
| **4 extra kernels**: linux-cachyos-lts, both `-zfs`, both `-nvidia-open` (+zfs-utils ×2) | ~800 MB–1 GB | each kernel ≈ 149 MiB + modules; nvidia-open doesn't even support MX150 |
| **VM/cloud guest agents**: open-vm-tools, qemu-guest-agent, virtualbox-guest-utils, hyperv, spice-vdagent, cloud-init, open-iscsi | ~250 MB | useless from a personal USB stick |
| **Filesystem zoo**: jfsutils, f2fs-tools, nilfs-utils, bcachefs-tools, dmraid, mdadm?, lvm2? | ~50 MB | sir uses btrfs only (keep btrfs-progs, dosfstools, exfatprogs, e2fsprogs, ntfs-3g, xfsprogs) |
| **Heavy rescue tools**: clonezilla, partimage, partclone, fsarchiver chain | ~300 MB w/deps | keep gparted + testdisk instead |
| Printing monsters (if we mirror his cups+foomatic+gutenprint+hplip set) | up to ~500 MB | recommend dropping printing entirely from live, or minimal `cups` only |
| misc: irssi, lynx, mc, nano, netctl, wvdial, rp-pppoe, xl2tpd, vpnc, brltty, memtest86+ ×2, gcc toolchain in ISO | ~400 MB | mostly legacy/duplicates of what sir actually uses |

**Estimated removable: ~3.5–4.5 GB installed ≈ half the squashfs payload.**

---

## 4. Target specification — "Helheim ISO"

> A live ISO that feels like walking into sir's own machine: greetd autologin → niri + Noctalia,
> fish shell, same apps, same configs. Light enough to carry.

### 4.1 Package strategy (new `packages_helheim.x86_64`)

**Foundation (KEEP):** base, linux-cachyos (+headers), linux-firmware (trimmed subsets possible),
mkinitcpio/-archiso, networkmanager, iwd/wpa_supplicant, bluez, pipewire+wireplumber+alsa,
sof-firmware, mesa, vulkan-intel, intel-media-driver, intel-ucode, btrfs-progs, snapper,
dosfstools/exfatprogs/e2fsprogs/ntfs-3g/xfsprogs, sudo, polkit, ufw, openssh, git, flatpak,
timesyncd/resolved, power-profiles-daemon, ananicy-cpp, cachyos-settings/keyring/mirrorlist/rate-mirrors, chwd.

**Sir's session (ADD):** `cachyos-niri-noctalia` (meta), `greetd`, `noctalia-greeter` (optional),
fish + cachyos-fish-config, foot/alacritty, xdg-desktop-portal bits come via the meta-pkg,
polkit-kde-agent (sir has it explicitly), wlsunset, wl-clipboard (via meta).

**Sir's apps (KEEP from our PoC additions):** alacritty, ark, baobab, btop, btrfs-assistant,
cachyos-hello/-kernel-manager/-packageinstaller, firefox, helium-browser-bin, flatseal,
freedownloadmanager, gnome-disk-utility, gnome-software, gparted, hwloc, meld, micro, mpv,
nautilus, noctalia, octopi, okular, pavucontrol, rapidraw-bin *(local repo)*, scx-manager,
shelly, telegram-desktop, ventoy-bin, v4l-utils, vim, zed, opencode, superfile, fastfetch,
glances, duf, ripgrep, yt-dlp, yay-bin (replace paru to match home).

**DROP:** everything in section 3 + KDE apps not used (kate/konsole/kcalc/spectacle/dolphin),
paru, plasma-* anything, greetd replaced by… nothing else.

### 4.2 Drivers decision (MX150)
Live session will run on **Intel (modesetting) + nouveau fallback** — correct default for Optimus.
The 580xx proprietary stack needs DKMS at install time anyway; after installing, `chwd`
handles it exactly like sir's real machine did. **Recommendation: no NVIDIA packages in the ISO**
(saves ~1.2 GB installed if lib32/opencl were included). Keep `switcheroo-control` + `nvidia-prime`
for hybrid plumbing.

### 4.3 Configuration overlay (the soul of it)

New script `sync-config.sh` in the repo root:
```
rsync selected dirs $HOME/.config → archiso/airootfs/etc/skel/.config
INCLUDE: niri noctalia fish alacritty foot shelly micro mpv gtk-3.0 gtk-4.0
         starship.toml mimeapps.list user-dirs.dirs user-dirs.locale autostart systemd/user
EXCLUDE: mozilla helium opencode gh BraveSoftware google-chrome octopi okular* (app state/tokens)
```
Plus hand-written airootfs files:
- `/etc/greetd/config.toml` — copy of sir's, but `user = "liveuser"` (autologin, same env vars)
- display-manager.service symlink → `greetd.service` (patch `prepare_profile()`)
- enable NetworkManager/ufw/sshd/snapper units via airootfs systemd symlinks
- `/etc/skel` gets applied to liveuser automatically at boot

### 4.4 Build system changes needed
`util-iso.sh::prepare_profile()` hardcodes `desktop` (package list name + plasmalogin symlink).
Two options:
- **A (quick):** keep editing the desktop files in our fork — zero code change.
- **B (clean, recommended):** accept `"helheim"` profile: its own package list,
  greetd display-manager link, custom iso_name/publisher in `profiledef.sh`.

### 4.5 Flatpaks (Warehouse & friends)
Cannot be baked via pacman. Options: leave out (recommended for weight), or preconfigure the
flathub remote in airootfs so one click installs them post-boot.

---

## 5. Size projection

| Build | Installed size | ISO |
|---|---|---|
| Current PoC | ~9.3 GB | 3.7 GB |
| Minus KDE stack, 4 kernels, VM agents, fs-zoo, rescue heavies | ~5.5–6.5 GB | **~2.1–2.5 GB** |
| Optional extra trims (drop noto-cjk 299M, drop meslo-nerd full→code variant 200M, drop printing, drop calamares installer for pure-live) | ~5 GB | **~1.6–1.9 GB** |

Realistic target: **≈ 2 GB**, stretch goal under 1.7 GB.

---

## 6. Decisions sir must make (checklist)

1. Installer: keep Calamares (installable ISO) or pure live rescue/desktop?
2. Printing: drop entirely, or minimal cups?
3. Fonts: keep noto-fonts-cjk (299M)? Does sir read CJK text?
4. NVIDIA: confirm "none in ISO, chwd after install" strategy
5. Profile approach: quick edit-in-place vs proper second profile (recommend B)
6. Live username: keep upstream `liveuser` or rename?

---

## 7. Workplan

1. ☐ Patch `util-iso.sh` for `helheim` profile (+profiledef naming)
2. ☐ Write `packages_helheim.x86_64` from audit lists above
3. ☐ Write `sync-config.sh` + run it (skel overlay)
4. ☐ Drop in greetd config + unit symlinks in airootfs
5. ☐ Rebuild, measure, iterate on size
6. ☐ Boot test in VM (`sudo ./testiso.sh`) → verify niri session, Noctalia, apps launch
