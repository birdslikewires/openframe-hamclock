#!/bin/bash
# Prints the package version, from the repository's root with its full history:
# <HamClock version>-<year.month.N>, e.g. 4.33-26.11.1. N counts the commits that changed the
# package in that month, as for the other OpenFrame packages. Every path the package is
# built from is listed below, the workflow included, so a change to any of them gives a new
# version.

paths=(package .github/workflows/build.yml)
month=$(TZ=UTC git log -1 --format=%cd --date=format-local:%y.%m -- "${paths[@]}")
count=$(TZ=UTC git log --format=%cd --date=format-local:%y.%m -- "${paths[@]}" | grep -cx "${month}")
[ -n "$month" ] && [ "$count" -gt 0 ] || { echo "Can't work out the version: no history?" >&2; exit 1; }
. "$(dirname "$0")/upstream.sh"
echo "${VERSION}-${month%.*}.$((10#${month#*.})).${count}"
