###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

################################
### Software update progress ###
################################

# Shows the current progress of the software update
#
show_progress()
{
	local rows=80 failed=1
	local m="You can't do that! Contact your system administrator."

	# Environment
	export LANG=C
	export LC_ALL=C

	# Check permissions
	if [ "$EUID" != 0 ]; then
		if [ -d "$statedir" ]; then
			read_state_var username

			if [ -z "$username" ] ||
			   [ "$EUID" != "$(id -u -- "$username")" ]
			then
				fatal "$m"
			fi
		fi

	# The program is launched as a service
	elif [ -n "$OS_UPGRADE_SERVICE" ]; then

		# Do not interrupt the daemon
		trap : INT TERM QUIT HUP USR1 USR2

		# Switch output to the specified TTY
		exec >"/dev/tty$TTY_NUMBER" 2>&1 </dev/null
	fi

	# The program is launched after the daemon was finished
	if [ ! -d "$statedir" ]; then
		[ -s "$logfile" ] ||
			fatal "$m"
		[ -t 1 ] && colormode=1 ||
			colormode=
		stage=finished
		failed=

	# Try to find the log and read the current status of the service
	else
		read_state_var logfile
		[ -n "$logfile" ] ||
			fatal "The log file is not defined."
		[ -r "$logfile" ] ||
			fatal "The log file was not found: '%s'." "$logfile"
		read_state_var stage
		[ -n "$stage" ] ||
			stage=finished
		have_state_var FAILED ||
			failed=
		read_state_var colormode
	fi

	# Resets colors on a dumb terminal
	reset_colors

	# Determine the geometry of the terminal
	# tty_geometry rows

	# Fill in the current terminal
	if [ "$stage" = finished ] || [ -n "$failed" ]; then
		# The main process has already been finished
		exec less -R -- "$logfile"
	else
		# Connect to the end of the log
		exec tail -n "$rows" -f -- "$logfile"
	fi

	exit 1
}

# Determines the geometry of the current terminal
#
tty_geometry()
{
	local __R_varname="${1-}"
	local __C_varname="${2-}"
	local __Rows=0
	local __Cols=0
	local IFS __E=

	# This snippet by Oleg Nesterov (C) was modified for the Software Updater,
	# see: https://lists.altlinux.org/pipermail/make-initrd/2021-June/000458.html
	#
	echo -ne "\e[s\e[1000;1000H\e[6n\e[u"
	# shellcheck disable=SC2162
	IFS=';[' read -s -t2 -dR __E __Rows __Cols &&
	is_number "${__Rows}" && is_number "${__Cols}" || {
		__Rows=24
		__Cols=80
	}
	[ -z "${__R_varname}" ] || eval "${__R_varname}=${__Rows}"
	[ -z "${__C_varname}" ] || eval "${__C_varname}=${__Cols}"
}

