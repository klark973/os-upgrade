###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

##########################
### Common definitions ###
##########################

# A simple fatal situation handler for the utility
#
fatal()
{
	local fmt="$1"; shift

	printf "%s fatal: $fmt\n" "$progname" "$@" >&2
	exit 1
}

# Software Updater's fatal situation handler:
# it will be redefined later in su_demonize()
#
su_fatal()
{
	fatal "$@"
}

# Unexpected error handler
#
unexpected_error()
{
	local rv="$?"

	trap - ERR
	su_fatal "Unexpected error #%s catched in %s[#%s]" "$rv" "$1" "$2"
}

# Resets colors on dumb terminals
#
reset_colors()
{
	[ -z "$colormode" ] ||
		return 0
	CLR_NORM=
	CLR_BOLD=
	CLR_LC1=
	CLR_LC2=
	CLR_OK=
	CLR_ERR=
	CLR_WARN=
}

# Displays a formatted debugging message on stderr
#
msg_diag()
{
	local fmt="$1"; shift

	if [ -n "$verbose" ]; then
		printf "$fmt\n" "$@" >&2
	fi
}

# Displays a formatted timestamp on the console
#
msg_time()
{
	local ts

	ts="$(date +'%T')"
	printf "${CLR_BOLD}[%s]${CLR_NORM} " "$ts"
}

# Displays a generic text message from the daemon
#
msg_prog()
{
	local color="$1" fmt="$2"

	shift 2
	msg_time
	printf "${color}${fmt}${CLR_NORM}\n" "$@"
}

# Displays a formatted text message on the console
#
msg()
{
	msg_prog "$CLR_LC2" "$@" >&2
}

# Displays a success text message on the console
#
msg_good()
{
	msg_prog "$CLR_OK" "$@" >&2
}

# Displays a warning text message on the console
#
msg_warn()
{
	msg_prog "$CLR_WARN" "$@" >&2
}

# Displays an error text message on the console
#
msg_fail()
{
	msg_prog "$CLR_ERR" "$@" >&2
}

# Shows the specified command (regular user mode)
#
msg_user()
{
	msg_time
	printf "${CLR_OK}\$ ${CLR_LC1}%s${CLR_NORM}\n" "$1"
}

# Shows the specified command (root mode)
#
msg_root()
{
	msg_time
	printf "${CLR_ERR}# ${CLR_LC1}%s${CLR_NORM}\n" "$1"
}

# Highlights one argument in a regular text message
#
msg_bold()
{
	local b="" n=""
	local fmt="$1" arg="$2"

	if [ -n "$colormode" ]; then
		b="\\$CLR_WARN"
		n="\\$CLR_LC2"
	fi

	fmt="$(printf "%s\n" "$fmt" |
		sed -e "s/@BOLD@/$b%s$n/")"
	msg_prog "$CLR_LC2" "$fmt" "$arg" >&2
}

# Returns 0, if the specified name is an executable program
#
can_run()
{
	type -p -- "$1" >/dev/null
}

# It's used for debugging purposes when STDERR should be suppressed
#
will_run()
{
	[ -n "$verbose" ] ||
		return 0

	if [ "$EUID" = 0 ]; then
		msg_root "$*" >&2
	else
		msg_user "$*" >&2
	fi
}

# Runs a command with additional logging for debugging purposes
#
run()
{
	will_run "$@"
	"$@"
}

# A "repeatable" wrapper for running some code ($1) N times ($2)
#
try()
{
	local callback="$1"
	local rv i=1 p=30 n="$2"

	shift 2
	while :; do
		rv=0
		#will_run "$callback" "$i" "$n" "$@"
		"$callback" "$i" "$n" "$@" && break ||
			rv="$?"
		[ "$i" != "$n" ] ||
			return $rv
		i="$((1 + $i))"
		run sleep "$p"
		p="$((2 * $p))"
	done
}

# Return 0 if argument is an integer number
#
is_number()
{
	[ -n "${1##*[!0-9]*}" ] && [ "$1" -ge 0 ] 2>/dev/null
}

# Searches the element "$1" in the array "$@" and returns 0 if it found
#
in_array()
{
	local needle="$1"; shift

	while [ "$#" -gt 0 ]; do
		[ "$needle" != "$1" ] ||
			return 0
		shift
	done

	return 1
}

# Returns 0, if the specified package is installed
#
is_pkg_installed()
{
	rpm -q -- "$@" >/dev/null 2>&1
}

# Returns 0, if the specified package is available to install
#
is_pkg_available()
{
	apt-cache show -- "$@" >/dev/null 2>&1
}

# Checks for the presence of the specified field in the state directory
#
have_state_var()
{
	[ -s "$statedir/$1" ]
}

# Reads the value of the specified field from the state directory
#
read_state_var()
{
	local __value
	local __varname="$1"
	local __filename="${2-}"

	[ -n "${__filename}" ] ||
		__filename="${__varname^^}"
	__value="$(head -n1 -- "$statedir/${__filename}" 2>/dev/null ||:)"
	eval "${__varname}=\"${__value//\"/\\\"}\""
}

# Saves the value of the specified field to the state directory
#
write_state_var()
{
	local __value
	local __varname="$1"
	local __filename="${2-}"

	[ -n "${__filename}" ] ||
		__filename="${__varname^^}"
	eval "__value=\"\$${__varname}\""
	printf "%s\n" "${__value}" >"$statedir/${__filename}"
}

# Sets the name of the next stage of the system update
#
next_stage()
{
	local v

	if [ "x$1" != "x-n" ]; then
		stage="$1"
	else
		no_reboot=1
		stage="$2"
	fi

	write_state_var stage

	if [ -n "$username" ]; then
		v="$(run id -ng -- "$username")"
		msg_diag "%s" "$v"
		run chgrp -- "$v" "$statedir"/STAGE
		run chmod -- 0640 "$statedir"/STAGE
	fi

	msg_bold "The next expected stage is '@BOLD@'." "${stage^^}"
}

# Sets the default systemd target value for the next
# system boot or restores the previously saved value
#
next_target()
{
	local tgt="$1"
	local m="The default systemd target has been changed to '@BOLD@'."

	if [ "x$tgt" = "x--restore" ]; then
		read_state_var tgt DEFAULT
		tgt="${tgt:-multi-user.target}"
	fi

	run systemctl set-default "$tgt"
	msg_bold "$m" "$tgt"
}

# Exits from the daemon and optionally reboots the system
#
su_exit()
{
	local pid="" rb="" rv="${1-0}"

	# The reboot option should also be the first one
	if [ "x$rv" = "x--reboot" ]; then
		rb=1
		rv=0
	fi

	# Reboot delay
	if [ -n "$rb" ] && [ -n "$reboot_delay" ]; then
		msg_warn "After few seconds the system will be restarted..."
		sleep "$reboot_delay"
	fi

	# PID of the helper process
	read_state_var pid PROGRESS.PID
	run rm -f -- "$statedir"/PROGRESS.PID

	# Exit the daemon
	if [ -z "$rb" ]; then
		[ -z "$pid" ] ||
			kill -KILL -- "$pid" >/dev/null 2>&1 ||:
		wait "$pid" >/dev/null 2>&1 ||:
		exit "$rv"
	fi

	# Reboot the system
	msg_fail "Rebooting the system..."
	[ -z "$pid" ] ||
		kill -KILL -- "$pid" >/dev/null 2>&1 ||:
	wait "$pid" >/dev/null 2>&1 ||:
	run systemctl -i reboot || {
		will_run reboot -fp
		# Suppress the output, otherwise it damages the log
		exec reboot -fp >/dev/null 2>&1
		exit 1
	}
}

# Finally switches the utility to daemon mode
#
su_demonize()
{
	# Overrides the previous definition
	#
	su_fatal()
	{
		local v rv="$?"

		trap - ERR
		msg_fail "$@"
		[ ! -s "$statedir"/FAILED ] ||
			exit "$rv"
		mkdir -p -- "$statedir"
		date +'%F %T' >"$statedir"/FAILED

		if [ -n "$username" ]; then
			v="$(run id -ng -- "$username")"
			msg_diag "%s" "$v"
			run chgrp -- "$v" "$statedir"
			run chmod -- 0750 "$statedir"
			run chgrp -- "$v" "$statedir"/FAILED
			run chmod -- 0640 "$statedir"/FAILED
		fi

		v="systemctl -q is-enabled $progname.service"
		will_run $v

		if $v 2>/dev/null; then
			msg "Disabling the %s service..." "$progname"
			run systemctl disable "$progname.service"
		fi

		v="$(date +'%Y-%m-%d')"
		msg_bold "The program was finished on @BOLD@." "$v"

		next_target --restore
		next_stage finished
		su_exit --reboot
	}

	# The daemon is always uninterruptable
	trap : INT TERM QUIT HUP USR1 USR2

	# It's safer for the daemon
	cd /

	# Redirect outputs to the log
	exec >>"$logfile" 2>&1 </dev/null
}

