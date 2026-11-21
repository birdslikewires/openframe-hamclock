# openframe-hamclock

Installs [HamClock](https://github.com/openhamclock/hamclock) on an OpenFrame/Joggler device running Debian Trixie, built for its 800×480 display.

HamClock is packaged here as `openframe-hamclock`, an i386 `.deb` that this repository's CI builds and publishes on the [Releases](https://github.com/birdslikewires/openframe-hamclock/releases) page, so nothing needs compiling on the OpenFrame itself (that used to take around 20 minutes; CI takes seconds).

## What It Does

1. Downloads the latest `openframe-hamclock` package and installs it with apt
2. **With sprite**, the OpenFrame touch shell: HamClock is on the home screen, and is set as the app sprite opens at startup (add `startup=no` to `setup.txt`, or run with `SETUP_STARTUP=no`, to leave the home screen as it is)
3. **Without sprite**: installs X.Org via `of-install xserver` (if not already present), configures `~/.xinitrc` to launch HamClock, and installs and enables `xinit.service` to start it at boot, as before

## Usage

On a fresh system, put this repository's address in `setup.txt` in the `settings` folder of the `OF-BOOT` volume before first boot, and it installs itself:

```
project=https://github.com/birdslikewires/openframe-hamclock
```

Or on a running system, as your normal user (not root):

```bash
curl -sS https://raw.githubusercontent.com/birdslikewires/openframe-hamclock/main/install.sh | bash
```

After installation, just reboot:

```bash
sudo reboot
```

To install a package by hand instead, download it from Releases and run `sudo apt install ./openframe-hamclock_<version>_i386.deb`.

## First Launch

HamClock will launch and run its setup wizard. Its on-screen keyboard types the upper character on a key when you tap the key's top half and the lower one from the bottom half, so taps need to be accurate: calibrating the touchscreen in sprite's Settings helps, and a USB keyboard is easier still. I personally don't know how to use this, so please [refer to some proper instructions](https://qso365.co.uk/2024/05/how-to-set-up-a-hamclock-for-your-shack/)!

### Backend

The original HamClock backend at clearskyinstitute.com is being retired. HamClock is started with `-b ohb.hamclock.app:80`, the [Open HamClock Backend](https://hamclock.co.uk), so nothing in `/etc/hosts` needs changing.

### Throttling

Because the software was designed for a microcontroller, it runs in a constant loop and without throttling would simply use 100% of whatever processor runs it. I've set 10% as the limit, but this may be wrong. Without sprite, you can change it by editing the .xinitrc file:

```bash
nano .xinitrc
```

Then change `-t 10` to `-t 20`. Or whatever you think is appropriate. With sprite, it's in `/usr/share/sprite/apps/hamclock.app`, which a package update replaces.

## Browser View

HamClock also serves a live view on port 8081 — accessible from any machine on your network:

```
http://<openframe-ip>:8081/live.html
```

## Building

`package/build.sh` builds the package in an i386 Debian Trixie container, from the HamClock release pinned in `package/upstream.sh` (version, tag and the zip's SHA-256). The workflow in `.github/workflows/build.yml` runs it on every change to `package/`, tests the package on a clean Trixie, and publishes a release. To move to a new HamClock, change `package/upstream.sh`.

To build locally (Docker, or colima on a Mac; the version is any you like):

```bash
mkdir -p out
docker run --rm --security-opt seccomp=unconfined --platform linux/386 -v "$PWD/package:/src:ro" -v "$PWD/out:/out" \
  i386/debian:trixie sh /src/build.sh /src 4.33-0.local /out
```

The package version is HamClock's, then the OpenFrame year.month.N, e.g. `4.33-26.11.1`.

## Licences

This repository's scripts are under the GNU General Public License, version 3 or (at your option) any later version (see [LICENSE](LICENSE)). Copyright 2026 Andrew Davison. HamClock is MIT, and includes wsServer (GPL-3.0) and zlib; the package carries their licences, and each release carries HamClock's source zip.
