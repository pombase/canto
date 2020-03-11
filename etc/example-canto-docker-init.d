#!/bin/sh -
#
### BEGIN INIT INFO
# Provides:          canto
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Should-Start:
# Should-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Canto
### END INIT INFO
#

su -c "/sbin/canto-docker-initd $* 7000" root &

