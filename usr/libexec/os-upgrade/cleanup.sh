#!/bin/bash
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

###############################################
### The self-removal script of this package ###
###############################################

# Safety first
set -o errexit
set -o noglob
set -o nounset
set -o errtrace

# By default, all new files will be available only to the root user
umask 0077

# Full path to this script
# shellcheck disable=SC2155
readonly scriptname="$(realpath -- "$0")"

# The short name of the program and package
readonly progname=os-upgrade

# Supplemental sources
readonly libdir="/usr/local/libexec/$progname"

# The OS Upgrade service state directory
readonly statedir="/var/lib/$progname"

# Bootstrapping
# shellcheck source=./defaults.sh
. "$libdir"/defaults.sh
# shellcheck source=./common.sh
. "$libdir"/common.sh

# Do not interrupt this script
trap : INT TERM QUIT HUP USR1 USR2

# Catch all unexpected errors
trap 'unexpected_error "${BASH_SOURCE[0]##*/}" "$LINENO"' ERR

# We can only continue from the specified location
[ "$scriptname" = "$cleanup_script" ] || exit 10

# User verification
[ "$EUID" = 0 ] || exit 20

# Environment
export LANG=C
export LC_ALL=C

# Entry point
read_state_var logfile
[ -s "$logfile" ] || exit 30
read_state_var colormode
read_state_var verbose
reset_colors

# IMA-protection after the update
read_state_var ima_required

# The integalert service
read_state_var integalert

# Wait for the main process to complete
while systemctl -q is-active "$progname"; do
	sleep 1
done

# Resume logging
exec >>"$logfile" 2>&1 </dev/null
will_run systemctl -q is-active "$progname"
msg "Final cleaning..."
run chvt 1

# Delete unit files, scripts and state directory
(set +f; run rm -f -- /etc/systemd/system/"$progname"*)
run rm -rf --one-file-system -- "$libdir" "$statedir"
run systemctl -q daemon-reload ||:

# Restore integrity control
if [ -n "$integalert" ]; then
	msg "Enabling the integalert service..."
	run systemctl enable integalert.service

	msg "Updating the OSEC Database..."
	run integalert fix

	msg "Starting the integalert service..."
	run systemctl start integalert.service
fi

# A bit of diagnostics
if [ -n "$verbose" ]; then
	msg "Collecting diagnostic data for technical support..."

	set +o errtrace
	( set +o errexit
	  /bin/bash --version |head -n1
	  run systemctl --no-pager status |head -n5
	  run systemctl --no-pager --failed
	  run rpm --eval %_priority_distbranch
	  run cat /etc/os-release
	  run cat /proc/cmdline
	  run uname -mrs
	  run apt-repo
	)
	set -o errtrace
fi

# The self-removal command
cmd="rm -f -- '$scriptname'"
if [ -n "$ima_required" ]; then
	msg "Preparing to the last reboot..."
	cmd="$cmd; reboot -fp"
fi

# Show the last messages
msg_bold "The program finished on @BOLD@." "$(date +'%Y-%m-%d')"
msg_good "The OS Upgrade has been finished successfully!"

# Delete this script itself and exit or reboot
will_run /bin/bash -c "$cmd"
# Suppress the output, otherwise it damages the log
exec /bin/bash -c "$cmd" >/dev/null 2>&1
exit 40

