#!/usr/bin/env bash

## HamClock Installer for OpenFrame / Joggler devices
##
## Installs HamClock on an OpenFrame running Debian Trixie.
## Uses of-install to set up the X.Org server if not already present.

## What this script does:
##   1. Updates the system (via sudo)
##   2. Installs X.Org via of-install xserver (if not already installed)
##   3. Downloads and runs the HamClock installer (as current user)
##   4. Installs the Open-HamClock-Backend (OHB) tools (via sudo)
##   5. Creates a systemd service to launch HamClock at boot via startx

## The OpenFrame has an 800x480 display, so HamClock is built at that
## resolution. CPU usage is throttled to ~10%.


set -e

HAMCLOCK_USER="$(id -un)"
HAMCLOCK_HOME="$HOME"
INSTALLER_URL="https://hamclock.co.uk/install-hc-rpi"
CPU_THROTTLE=10
OF_INSTALL="/usr/local/sbin/of-install"

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
# Argument parsing
# -----------------------------------------------------------------------------

SKIP_COMPILE=false
for arg in "$@"; do
	case "$arg" in
		--no-compile) SKIP_COMPILE=true ;;
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
# Step 1: System update
# -----------------------------------------------------------------------------

info "Updating package lists and upgrading system packages..."
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
success "System updated."

# -----------------------------------------------------------------------------
# Step 2: Make /etc/hosts persistent (Trixie quirk)
# Some Trixie configurations reset /etc/hosts on reboot.
# -----------------------------------------------------------------------------

info "Ensuring /etc/hosts is persistent across reboots..."
sudo chattr -i /etc/hosts 2>/dev/null || true
success "/etc/hosts persistence ensured."

# -----------------------------------------------------------------------------
# Step 3: Install X.Org via of-install (if not already present)
# -----------------------------------------------------------------------------

if command -v xinit &>/dev/null; then
	info "X.Org already installed, skipping."
else
	info "Installing X.Org server via of-install..."
	sudo "$OF_INSTALL" xserver || error "of-install xserver failed."
	success "X.Org server installed."
fi

if [[ "$SKIP_COMPILE" == false ]]; then
# -----------------------------------------------------------------------------
# Step 4: Download and run the HamClock installer
#
# The installer asks:
#   - Proceed? -> y
#   - Build for web access only? -> n  (we want native X11 display)
#   - Resolution choice -> 1           (800x480 — fits the OpenFrame exactly)
#   - Install desktop icon? -> n       (no desktop environment on OpenFrame)
#   - Install user guide? -> y
#   - Auto-start HamClock? -> n        (handled by our systemd service)
# -----------------------------------------------------------------------------

INSTALLER_PATH="${HAMCLOCK_HOME}/install-hc-rpi"

info "Downloading HamClock installer..."
curl -fsSL -o "$INSTALLER_PATH" "$INSTALLER_URL" \
	|| error "Failed to download installer. Check your internet connection."
chmod u+x "$INSTALLER_PATH"
success "Installer downloaded."

info "Running HamClock installer (this will take a while)..."
info "Go and make a brew — compilation may take about 20 minutes."
echo ""

# Start a temporary X session so the installer can query the display size.
# Killed automatically when this script exits.
X :0 -nolisten tcp &
X_PID=$!
trap "kill $X_PID 2>/dev/null || true" EXIT
sleep 2  # Give X a moment to initialise
export DISPLAY=:0

cd "$HAMCLOCK_HOME"
printf 'y\nn\n1\nn\ny\nn\n' | ./install-hc-rpi \
	|| error "HamClock installer failed. Check the output above for details."

echo ""
success "HamClock build complete."

else
	info "Skipping HamClock compilation (--no-compile)."
fi

# Locate the binary
HAMCLOCK_BIN="$(command -v hamclock 2>/dev/null || true)"
if [[ -z "$HAMCLOCK_BIN" ]]; then
	error "HamClock binary not found. Installation may have failed."
fi
success "HamClock binary found at: ${HAMCLOCK_BIN}"

# -----------------------------------------------------------------------------
# Step 5: Install Open-HamClock-Backend (OHB) tools
# The original clearskyinstitute.com backend is being retired.
# OHB is the community replacement.
# -----------------------------------------------------------------------------

info "Installing Open-HamClock-Backend (OHB) tools..."
if curl -fsSL https://hamclock.co.uk/tools | sudo bash; then
	success "OHB tools installed."
	info "Configuring OHB backend..."
	sudo ohb || warn "OHB configuration step failed — run 'sudo ohb' manually after reboot."
else
	warn "OHB tools installation failed. Run this manually after reboot:"
	warn "  curl -fsSL https://hamclock.co.uk/tools | sudo bash && sudo ohb"
fi

# -----------------------------------------------------------------------------
# Step 6: Set up .xinitrc to launch HamClock in X
#
# startx will run ~/.xinitrc. We disable screen blanking/DPMS first,
# then launch HamClock with CPU throttling. If HamClock exits, X exits too.
# -----------------------------------------------------------------------------

info "Configuring .xinitrc for HamClock startup..."

cat > "${HAMCLOCK_HOME}/.xinitrc" <<EOF
#!/bin/sh
# Launch HamClock — throttled to ~${CPU_THROTTLE}% CPU (suits the Atom Z520)
exec ${HAMCLOCK_BIN} -t ${CPU_THROTTLE}
EOF

chmod +x "${HAMCLOCK_HOME}/.xinitrc"
success ".xinitrc configured."

# -----------------------------------------------------------------------------
# Step 7: Install xinit.service to launch HamClock via .xinitrc at boot
# -----------------------------------------------------------------------------

info "Installing xinit.service..."

sudo tee /etc/systemd/system/xinit.service > /dev/null <<UNIT
[Unit]
Description=Xinit
After=network-online.target
Wants=network-online.target

[Service]
User=${HAMCLOCK_USER}
ExecStart=/usr/bin/xinit -- :0 vt1 -nolisten tcp
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable xinit.service
success "xinit.service installed and enabled."


# -----------------------------------------------------------------------------
# Done!
# -----------------------------------------------------------------------------

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  HamClock installation complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "  Binary:   ${HAMCLOCK_BIN}"
echo -e "  X init:   ${HAMCLOCK_HOME}/.xinitrc"
echo -e "  Autostart: xinit.service → .xinitrc"
echo -e "  CPU cap:  ${CPU_THROTTLE}%"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Reboot the OpenFrame:"
echo -e "     ${CYAN}sudo reboot${NC}"
echo -e "  2. On first boot, HamClock will run its setup wizard."
echo -e "     Use a mouse/keyboard to enter your callsign, grid square, etc."
echo -e "  3. On Setup Page 2, set DX Cluster to Yes and use:"
echo -e "     Host: dxspider.co.uk   Port: 7300"
echo -e "  4. On Setup Page 5, enable Auto SpcWx Map and Full scrn direct."
echo ""
echo -e "  Web access (from another machine on your network):"
echo -e "     ${CYAN}http://$(hostname -I | awk '{print $1}'):8081/live.html${NC}"
echo ""