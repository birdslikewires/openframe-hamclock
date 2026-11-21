#!/usr/bin/env bash

## HamClock Installer for OpenFrame / Joggler devices
##
## Installs HamClock on an OpenFrame running Debian Trixie, from the openframe-hamclock
## package that this repository's CI builds (see package/): nothing is compiled here.
##
## What this script does:
##   1. Downloads the latest openframe-hamclock package and installs it with apt
##   2. With sprite (the OpenFrame touch shell): sets HamClock as the app sprite opens at
##      startup, unless SETUP_STARTUP=no. HamClock is on sprite's home screen either way.
##   3. Without sprite: installs X.Org via of-install xserver (if not already present), and
##      starts HamClock at boot through ~/.xinitrc and xinit.service, as before.
##
## HamClock is built for the OpenFrame's 800x480 display, throttled to ~10% CPU, and uses the
## Open HamClock Backend (ohb.hamclock.app), the community replacement for the original.

set -e

HAMCLOCK_USER="$(id -un)"
HAMCLOCK_HOME="$HOME"
PACKAGE_URL="${PACKAGE_URL:-https://github.com/birdslikewires/openframe-hamclock/releases/latest/download/openframe-hamclock_i386.deb}"
HAMCLOCK_BIN="/usr/bin/hamclock"
HAMCLOCK_ARGS="-t 10 -b ohb.hamclock.app:80"
OF_INSTALL="/usr/local/sbin/of-install"
SPRITE_HELPER="/opt/sprite/libexec/sprite-helper"

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[*]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; exit 1; }

# -----------------------------------------------------------------------------
# Argument parsing (--no-compile is accepted for older instructions: nothing compiles now)
# -----------------------------------------------------------------------------

for arg in "$@"; do
	case "$arg" in
		--no-compile) ;;
		*) error "Unknown argument: $arg" ;;
	esac
done

# -----------------------------------------------------------------------------
# Preflight checks
# -----------------------------------------------------------------------------

if [[ $EUID -eq 0 ]]; then
	error "Do not run this script as root. Run it as your normal user."
fi

info "Installing for user: ${HAMCLOCK_USER} (home: ${HAMCLOCK_HOME})"

# -----------------------------------------------------------------------------
# Step 1: Install the openframe-hamclock package
# -----------------------------------------------------------------------------

DEB="$(mktemp -d)/openframe-hamclock_i386.deb"
trap 'rm -rf "${DEB%/*}"' EXIT

info "Downloading the HamClock package..."
curl -fsSL -o "$DEB" "$PACKAGE_URL" \
	|| error "Failed to download the package. Check your internet connection."
success "Package downloaded."

info "Installing it..."
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$DEB" > /dev/null \
	|| error "Installing the package failed."
sudo apt-get clean    # apt's cache is held in RAM on OpenFrame images
success "HamClock $(dpkg-query -W -f='${Version}' openframe-hamclock) installed: ${HAMCLOCK_BIN}"

# -----------------------------------------------------------------------------
# Step 2: sprite, if it's here
# -----------------------------------------------------------------------------

if [ -x "$SPRITE_HELPER" ]; then
	if [ "${SETUP_STARTUP:-yes}" != "no" ]; then
		info "Setting HamClock as the app sprite opens at startup..."
		REPLY=$(echo "set startup HamClock" | sudo "$SPRITE_HELPER")
		[ "$REPLY" = "ok" ] && success "sprite opens HamClock at startup." \
			|| warn "sprite's helper said: $REPLY. Hold HamClock's tile and choose 'Open at startup' instead."
	fi
	MODE="sprite"
else
	# -------------------------------------------------------------------------
	# Step 3: no sprite: X.Org and xinit, as before
	# -------------------------------------------------------------------------

	if command -v xinit &>/dev/null; then
		info "X.Org already installed, skipping."
	else
		info "Installing X.Org server via of-install..."
		sudo "$OF_INSTALL" xserver || error "of-install xserver failed."
		success "X.Org server installed."
	fi

	info "Configuring .xinitrc for HamClock startup..."
	cat > "${HAMCLOCK_HOME}/.xinitrc" <<EOF
#!/bin/sh
# Launch HamClock: throttled to ~10% CPU (suits the Atom Z520), with the Open HamClock Backend
exec ${HAMCLOCK_BIN} ${HAMCLOCK_ARGS}
EOF
	chmod +x "${HAMCLOCK_HOME}/.xinitrc"
	success ".xinitrc configured."

	info "Installing xinit.service..."
	sudo tee /etc/systemd/system/xinit.service > /dev/null <<UNIT
[Unit]
Description=Xinit
After=network-online.target
Wants=network-online.target

[Service]
ExecStartPre=+/usr/local/sbin/of-settings xdefaults
User=${HAMCLOCK_USER}
ExecStart=/usr/bin/xinit -- :0 vt1 -nolisten tcp
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
	sudo systemctl daemon-reload
	sudo systemctl enable xinit.service
	success "xinit.service installed and enabled."
	MODE="xinit"
fi

# -----------------------------------------------------------------------------
# Done!
# -----------------------------------------------------------------------------

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  HamClock installation complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "  Binary:   ${HAMCLOCK_BIN} ${HAMCLOCK_ARGS}"
if [ "$MODE" = "sprite" ]; then
	echo -e "  Starts:   from sprite's home screen$([ "${SETUP_STARTUP:-yes}" != "no" ] && echo ", and at startup")"
else
	echo -e "  Starts:   at boot, through xinit.service and ~/.xinitrc"
fi
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Reboot the OpenFrame:"
echo -e "     ${CYAN}sudo reboot${NC}"
echo -e "  2. On first start, HamClock runs its setup pages: enter your callsign, grid"
echo -e "     square and so on. A USB keyboard makes that easier than the on-screen one."
echo -e "  3. On Setup Page 2, set DX Cluster to Yes and use:"
echo -e "     Host: dxspider.co.uk   Port: 7300"
echo -e "  4. On Setup Page 5, enable Auto SpcWx Map and Full scrn direct."
echo ""
echo -e "  Web access (from another machine on your network):"
echo -e "     ${CYAN}http://$(hostname -I | awk '{print $1}'):8081/live.html${NC}"
echo ""
