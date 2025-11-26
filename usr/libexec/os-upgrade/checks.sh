###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

#################################################
### Mandatory checks before start the service ###
#################################################

# Checks all the prerequisites for running the daemon
#
check_requirements()
{
	local PRETTY_NAME VERSION_ID ALT_BRANCH_ID
	local m="There is no supported distribution for updating."

	# Check permissions
	[ "$EUID" = 0 ] ||
		fatal "You must be a root user to run this program!"

	# Check the service status
	! have_state_var STAGE &&
	! have_state_var FAILED &&
	! have_state_var LOGFILE &&
	! systemctl -q is-active "$progname.service" ||
		fatal "The daemon has already been started."

	# Check the APT-specific configuration directory
	[ -d /etc/apt/sources.list.d ] ||
		fatal "$m"

	# Check the /etc/os-release file
	[ -s /etc/os-release ] ||
		fatal "$m"

	# Check the system version and repository name
	PRETTY_NAME="$(read_release_field PRETTY_NAME)"
	VERSION_ID="$(read_release_field VERSION_ID)"
	ALT_BRANCH_ID="$(read_release_field ALT_BRANCH_ID)"
	branch="$(rpm --eval %_priority_distbranch 2>/dev/null ||:)"
	#
	# shellcheck disable=SC2166
	if [ -n "$branch" ] && [ -s "$libdir/$branch"/checks.sh ] &&
	   [ "$branch" = "$ALT_BRANCH_ID" -o -z "$ALT_BRANCH_ID" ]
	then
		# shellcheck source=./c10f1/checks.sh
		. "$libdir/$branch"/checks.sh

		# Branch-specific checks and show the last warning
		if check_$branch && ask_user_agree
		then
			# Check a network connectivity
			check_network ||
				fatal "A network connection is required."

			# Set the default mirror
			mirror="${mirror:-$default_mirror}"

			# Updating in the background isn't usable on desktops
			[ ! -x /usr/bin/Xorg ] ||
				background=

			return 0
		fi
	fi

	fatal "$m"
}

# Reads the value of the specified field in the /etc/os-release file
#
read_release_field()
{
	local x

	x="$(sed -ne "s/^$1=//p" /etc/os-release)"
	[ "${x:0:1}" != '"' ] ||
		x="${x:1:-1}"
	printf "%s" "$x"
}

# Prompts the user to confirm the update
#
ask_user_agree()
{
	local lang prompt

	[ -z "$batchmode" ] ||
		return 0
	lang="${LC_ALL:-en_US.utf8}"
	lang="${LC_MESSAGES:-$lang}"
	lang="${LANG:-$lang}"
	lang="${lang%.*}"
	[ -n "$lang" ] ||
		lang=en_US
	prompt="$libdir/l10n/$lang/prompt.msg"
	[ -s "$prompt" ] ||
		prompt="$libdir/l10n/en_US/prompt.msg"
	cat <"$prompt"
	read -rs -n1 prompt ||:
	printf "\n"
}

# Checks the network connection
#
check_network()
{
	local tmpf rc=0

	if [ -n "$ping_server" ]; then
		tmpf="$(mktemp -qt -- "$progname-XXXXXXXX.tmp")" ||
			fatal "Couldn't create a temporary file."
		LANG=C ping -c4 -W10 -- "$ping_server" 2>&1 |
			tee -- "$tmpf"
		grep -qs -- ', 0% packet loss,' "$tmpf" ||
			rc=1
		rm -f -- "$tmpf"
	fi

	return $rc
}

