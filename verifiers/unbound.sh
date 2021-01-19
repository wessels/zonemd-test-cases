#!/bin/sh
set -e

origin=$1 ; shift
file=$1; shift

TD=`mktemp -d`
trap 'rm -rf $TD' EXIT

cp -p $file $TD
file=`basename $file`

cat >$TD/unbound.conf <<EOF
server:
	verbosity: 3
        interface: 127.0.0.1
        port: 5001
        access-control: 127.0.0.0/8 allow
        username: ""
        use-syslog: no
        chroot: ""
        directory: "$TD"

        # the log file, "" means log to stderr.
        # Use of this option sets use-syslog to "no".
        logfile: "$TD/unbound.log"

        pidfile: "$TD/unbound.pid"

auth-zone:
	name: "$origin"
	zonefile: "$file"
EOF

/path/to/unbound -c $TD/unbound.conf -d -v -v -v 2>/dev/null &
sleep 1
grep -q 'ZONEMD verification successful' $TD/unbound.log
rc=$?
kill `cat $TD/unbound.pid`
grep ZONEMD $TD/unbound.log
exit $rc
