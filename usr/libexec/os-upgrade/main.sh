#!/bin/bash
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

#####################################
### OS Upgrade utility and daemon ###
#####################################

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
readonly progname="${scriptname##*/}"

# Supplemental sources
readonly libdir="/usr/libexec/$progname"

# The OS Upgrade service state directory
readonly statedir="/var/lib/$progname"

# This flag is set when the program is started as a service
readonly OS_UPGRADE_SERVICE="${OS_UPGRADE_SERVICE-}"

# Bootstrapping
# shellcheck source=./defaults.sh
. "$libdir"/defaults.sh
# shellcheck source=./common.sh
. "$libdir"/common.sh

# Catch all unexpected errors
trap 'unexpected_error "${BASH_SOURCE[0]##*/}" "$LINENO"' ERR

# Entry point
if [ -z "$OS_UPGRADE_SERVICE" ]; then
	# shellcheck source=./parser.sh
	. "$libdir"/parser.sh

	parse_cmdline "$@"

	# shellcheck source=./checks.sh
	. "$libdir"/checks.sh

	# Determine the source branch name
	check_requirements

	# Environment
	export LANG=C
	export LC_ALL=C
	export DURING_INSTALL=

	# Use branch-specific defaults
	eval "save_${branch}_data() { :; }"
	# shellcheck source=/dev/null
	[ ! -s "$libdir/$branch"/defaults.sh ] ||
		. "$libdir/$branch"/defaults.sh
	stage="${stage:-start}"
	setup_console

	# Empty the log
	:> "$logfile"

	# Demonize the utility
	su_demonize

	# Show and log the first messages
	msg_bold "The program was started on @BOLD@." "$(date +'%Y-%m-%d')"
	will_run "$progname" "$@"
	[ -n "$ping_server" ] ||
		msg_warn "The network connection check was skipped."
	msg "The program will be restarted as a service very soon."
else
	# User verification
	[ "$EUID" = 0 ] ||
		fatal "You can't run this program as a service!"

	# Show the current progress on the specified TTY
	if [ "$#" = 1 ] && [ "x${1-}" = "x-s" ]; then
		# shellcheck source=./progress.sh
		. "$libdir"/progress.sh

		show_progress
	else
		# Run sub-process on the specified TTY
		openvt -f -w -s -c "$TTY_NUMBER" -- \
			/bin/bash "$scriptname" -s 2>/dev/null &
		printf "%s\n" "$!" >"$statedir"/PROGRESS.PID
	fi

	# Environment
	export LANG=C
	export LC_ALL=C
	export DURING_INSTALL=

	# Check the status
	read_state_var stage
	! have_state_var FAILED && [ "$stage" != finished ] ||
		fatal "The service has already been finished."
	read_state_var logfile
	[ -n "$logfile" ] ||
		fatal "The log file is not defined."
	[ -s "$logfile" ] ||
		fatal "The log file was not found: '%s'." "$logfile"
	read_state_var reboot_delay
	read_state_var colormode
	read_state_var verbose
	reset_colors

	# Demonize the utility
	su_demonize

	# Load the remaining fields
	msg "Reading the service state..."
	read_state_var autoclean
	read_state_var background
	read_state_var veto_packages
	read_state_var mirror
	read_state_var ping_server
	read_state_var username
	read_state_var ima_evm
	read_state_var ima_required
	read_state_var integalert
	read_state_var auditd
	read_state_var branch

	# Load branch-specific fields too
	if [ -n "$branch" ] && [ -s "$libdir/$branch"/defaults.sh ]; then
		eval "load_${branch}_data() { :; }"
		# shellcheck source=/dev/null
		. "$libdir/$branch"/defaults.sh
		load_${branch}_data
	fi
fi

while :; do
	# The loop of passing the stages
	if [ -z "$stage" ] || [ -z "$branch" ] ||
	   [ ! -s "$libdir/$branch/$stage.sh" ]
	then
		su_fatal "Non-existent stage: '%s/%s'." "$branch" "${stage^^}"
	fi

	if [ "$last_stage" = "$stage" ]; then
		msg_bold "Restarting the stage: '@BOLD@'..." "${stage^^}"
	else
		msg_bold "Starting the stage: '@BOLD@'..." "${stage^^}"
		last_stage="$stage"

		# shellcheck source=./c10f1/start.sh
		. "$libdir/$branch/$stage.sh"
	fi

	run_stage

	[ "$stage" != finished ] ||
		break
	! have_state_var FAILED ||
		break
	[ -n "$no_reboot" ] ||
		break
	no_reboot=
done

# Exit the daemon and reboot
su_exit --reboot
exit 1

