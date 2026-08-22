# HYCAC

**H**e's **Y**our **C**ustom **A**rch-based **C**ompanion — a light, personal live environment.
*niri + Noctalia on a CachyOS base, packaged as a portable ISO.*

> Pure live: nothing installs to any disk. Boot it on any machine and it looks
> and behaves exactly like the source system — same shell, same keybinds,
> same desktop, same applications. Everything is forgotten on reboot.

## What's inside

| Layer | Choice |
|---|---|
| Session | greetd → autologin → `niri-session` (user `hycac`, fish shell) |
| Desktop | Noctalia v5 shell on niri, xwayland-satellite, HYCAC wallpapers |
| Kernel | single `linux-cachyos` |
| Graphics | Intel primary / nouveau fallback — **no NVIDIA in ISO** (use `chwd` after any real install) |
| Apps | the source machine's daily set: firefox & helium-browser, zed, micro, vim, mpv, okular, ark, meld, octopi, gnome-software, btop, fastfetch, superfile, telegram, ventoy, rapidraw, opencode … |
| Networking | NetworkManager + wpa_supplicant, ufw, sshd, openvpn |
| Storage | btrfs-progs + snapper-aware tools, zram-generator (ram-sized, zstd) |

Deliberately excluded: KDE/Plasma, installers (pure live), printing stack,
NVIDIA drivers, CJK fonts, VM guest agents, legacy rescue heavies.

## Building

Requirements (Arch/CachyOS host):

```bash
sudo pacman -S --needed archiso mkinitcpio-archiso squashfs-tools grub git
```

1. **Refresh personal configs** from the source machine into the skeleton:

   ```bash
   ./sync-config.sh
   ```

2. **Build**:

   ```bash
   sudo ./buildiso.sh -p hycac -v -w
   ```

3. Result lands in `out/hycac/hycac-hycac-YYMMDD.iso`.

### Local package repository

`local-repo/` is a tiny pacman repository for AUR packages rebuilt locally
(currently `rapidraw-bin`). It is referenced by `archiso/pacman.conf`
(`[iso-local]`, kept last so it can never shadow official repos) and is
git-ignored. To add/update packages:

```bash
cd local-repo/x86_64
repo-add iso-local.db.tar.gz *.pkg.tar.zst
```

## Repository layout

```
archiso/                 ISO profile (airootfs overlay, package list, bootloader configs)
  packages_hycac.x86_64    curated package list (the heart of the ISO)
  airootfs/etc/greetd      autologin config → niri-session as hycac
  airootfs/etc/skel        personal dotfiles (via sync-config.sh)
  airootfs/usr/share/backgrounds/hycac   bundled HYCAC wallpapers
branding/                logo SVG + generated splash/wallpaper sources
local-repo/              local pacman repo (git-ignored) for AUR builds
sync-config.sh           copies personal configs into the skeleton (whitelist-based)
docs/AUDIT_REPORT.md     audit that shaped this project
```

## Test-boot without hardware

```bash
sudo ./testiso.sh out/hycac/<file>.iso
```

## Credits & license

Forked from [CachyOS-Live-ISO](https://github.com/CachyOS/CachyOS-Live-ISO),
which is based on [archiso](https://gitlab.archlinux.org/archlinux/archiso).
Build scripts retain their GPL-2.0-or-later licensing (see `LICENSE`).
HYCAC branding assets live in `branding/`.
