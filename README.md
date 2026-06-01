# openframe-hamclock

Installs [HamClock]([https://www.clearskyinstitute.com/ham/HamClock/](https://qso365.co.uk/2024/05/how-to-set-up-a-hamclock-for-your-shack/)) on an OpenFrame/Joggler device running Debian Trixie, configured for its 800×480 display.

## What It Does

1. Updates system packages
2. Installs X.Org via `of-install xserver` (if not already present)
3. Downloads and compiles HamClock at 800×480 resolution
4. Installs the [Open-HamClock-Backend](https://hamclock.co.uk) (OHB) community tools
5. Configures `~/.xinitrc` to launch HamClock
6. Installs and enables `xinit.service` systemd unit to autostart HamClock at boot

## Usage

Run as your normal user (not root):

```bash
curl -sS https://raw.githubusercontent.com/birdslikewires/openframe-hamclock/main/install.sh | bash
```

To skip recompilation for whatever reason (e.g. HamClock is already built):

```bash
bash install.sh --no-compile
```

After installation, just reboot:

```bash
sudo reboot
```

## First Launch

HamClock will launch automatically and run its setup wizard. You'll likely need a mouse and keyboard connected. I personally don't know how to use this, so please [refer to some proper instructions](https://qso365.co.uk/2024/05/how-to-set-up-a-hamclock-for-your-shack/)!

### Throttling

Because the software was designed for the ESP32, it runs in a constant loop and without a throttling would simply use 100% of whatever processor runs it. I've set 10% as the limit, but this may be wrong. You can change it by editing the .xinitrc file.


```bash
nano .xinitrc
```

Then change `-t 10` to `-t 20`. Or whatever you think is appropriate.

## Browser View

HamClock also serves a live view on port 8081 — accessible from any machine on your network:

```
http://<openframe-ip>:8081/live.html
```
