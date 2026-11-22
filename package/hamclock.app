# HamClock on sprite, the OpenFrame touch shell: installed by the openframe-hamclock package.
# -t 10 keeps it to about 10% of the CPU: it was written for a microcontroller, and otherwise
# spins a whole core. -b points it at the Open HamClock Backend, as clearskyinstitute.com, the
# original backend, is being retired. sprite runs apps in sandboxes without a network unless
# they ask for one, and HamClock lives on its data.
name=HamClock
exec=/usr/bin/hamclock -t 10 -b ohb.hamclock.app:80
icon=radio
color=b8860b
display=x11
allow=network
