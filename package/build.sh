#!/bin/sh
# Builds the openframe-hamclock package: HamClock for the OpenFrame's 800x480 screen, and a
# manifest for sprite. Run as root in an i386 Debian Trixie container (the workflow uses
# i386/debian:trixie), as: sh build.sh <this folder> <version> <output folder>
#
# The source is the HamClock release in upstream.sh, checked by its hash. The binary isn't
# setuid, unlike upstream's 'make install' does as root: it only needs that for GPIO on a
# Raspberry Pi, and here it runs as the 'of' user.

set -eu

here=$1
version=$2
out=$3
. "$here/upstream.sh"
PKGNAME=openframe-hamclock

export DEBIAN_FRONTEND=noninteractive
apt-get -qq --error-on=any update
apt-get -qq install -y --no-install-recommends ca-certificates curl unzip g++ make libx11-dev \
  dpkg-dev file > /dev/null

work=$(mktemp -d)
curl -fsSL -o "$work/$ZIP" "https://github.com/openhamclock/hamclock/releases/download/$TAG/$ZIP"
echo "$SHA256  $work/$ZIP" | sha256sum -c -
unzip -q "$work/$ZIP" -d "$work"
src=$work/ESPHamClock
make -C "$src" -j"$(nproc)" hamclock-800x480 > "$work/build.log" 2>&1 || { tail -40 "$work/build.log"; exit 1; }

pkg=$work/pkg
install -d "$pkg/DEBIAN" "$pkg/usr/bin" "$pkg/usr/share/doc/$PKGNAME" "$pkg/usr/share/man/man1" \
  "$pkg/usr/share/sprite/apps"
install -m 755 "$src/hamclock-800x480" "$pkg/usr/bin/hamclock"
strip --strip-unneeded "$pkg/usr/bin/hamclock"
gzip -9n -c "$src/hamclock.1" > "$pkg/usr/share/man/man1/hamclock.1.gz"
install -m 644 "$here/hamclock.app" "$pkg/usr/share/sprite/apps/hamclock.app"
{
  cat "$here/copyright"
  printf '\nLicense: MIT\n'; sed 's/^/ /; s/^ $/ ./' "$src/LICENSE"
  printf '\nLicense: GPL-3.0-or-later\n On Debian systems, the full text is in /usr/share/common-licenses/GPL-3.\n'
} > "$pkg/usr/share/doc/$PKGNAME/copyright"
for f in wsServer/LICENSE; do
  install -m 644 "$src/$f" "$pkg/usr/share/doc/$PKGNAME/$(echo "$f" | tr / -)"
done

# Dependencies from the binary itself.
mkdir -p "$work/deb/debian"
printf 'Source: %s\n\nPackage: %s\nArchitecture: i386\n' "$PKGNAME" "$PKGNAME" > "$work/deb/debian/control"
deps=$(cd "$work/deb" && dpkg-shlibdeps -O "$pkg/usr/bin/hamclock" 2>/dev/null | sed -n 's/^shlibs:Depends=//p')
[ -n "$deps" ] || { echo "dpkg-shlibdeps found no dependencies"; exit 1; }

size=$(du -sk "$pkg/usr" | cut -f1)
cat > "$pkg/DEBIAN/control" <<CONTROL
Package: $PKGNAME
Version: $version
Architecture: i386
Section: hamradio
Priority: optional
Maintainer: OpenFrame Project <noreply@openbeak.net>
Installed-Size: $size
Depends: $deps
Homepage: https://github.com/birdslikewires/openframe-hamclock
Description: HamClock for the OpenFrame
 HamClock $VERSION, the amateur radio clock and propagation display by Elwood Downey and
 the openhamclock contributors, built for the OpenFrame's 800x480 screen. It appears on
 sprite's home screen, using the Open HamClock Backend.
CONTROL

deb="$out/${PKGNAME}_${version}_i386.deb"
dpkg-deb --root-owner-group -Zxz --build "$pkg" "$deb" > /dev/null
cp "$work/$ZIP" "$out/"
dpkg-deb -I "$deb" | sed -n '/Package:/,$p'
ls -l "$out"
