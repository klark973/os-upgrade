###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

####################################
### Command line argument parser ###
####################################

parse_cmdline()
{
	local l_opts="apt:,background,color:,disable-ima,enable-ima,force,yes"
	      l_opts="$l_opts,important:,keep-package,logfile:,mirror:,ping:"
	      l_opts="$l_opts,quiet,reboot:,show,username:,version,help"
	local s_opts="+a:bc:defi:kl:m:p:qr:su:Vh"
	local msg

	l_opts=$(getopt -n "$progname" -o "$s_opts" -l "$l_opts" -- "$@") ||
		show_usage
	eval set -- "$l_opts"
	while [ "$#" != 0 ]; do
		case "$1" in
		-a|--apt)
			check_2nd_arg --apt "${2-}" \
				"path to additional APT sources"
			msg="The specified APT sources list not found: '%s'."
			[ -s "$2" ] ||
				show_usage "$msg" "$2"
			apt_sources="$(realpath -- "$2")"
			shift
			;;

		-b|--background)
			background=1
			;;

		-c|--color)
			case "${2-}" in
			always|never|auto)
				colormode="$2"
				;;
			*)	msg="Invalid color mode: '%s'."
				show_usage "$msg" "${2-}"
				;;
			esac
			shift
			;;

		-d|--disable-ima)
			disable_ima=1
			;;

		-e|--enable-ima)
			enable_ima=1
			;;

		-f|--force|--yes)
			batchmode=1
			;;

		-i|--important)
			check_2nd_arg --important "${2-}" \
				"a list of important packages"
			veto_packages="$2"
			shift
			;;

		-k|--keep-package)
			autoclean=
			;;

		-l|--logfile)
			check_2nd_arg --logfile "${2-}" \
				"a full path to the log file"
			msg="Invalid path to the log file: '%s'."
			[ -d "${2%/*}" ] ||
				show_usage "$msg" "$2"
			[ -n "${2##*/*}" ] && logfile="$(realpath .)/$2" ||
				logfile="$(realpath -- "${2%/*}")/${2##*/}"
			shift
			;;

		-m|--mirror)
			check_2nd_arg --mirror "${2-}" \
				"an alternative mirror (URL)"
			mirror="$2"
			shift
			;;

		-p|--ping)
			check_2nd_arg --ping "${2-}" "server name or address"
			[ "x$2" = 'x-' ] && ping_server="" ||
				ping_server="$2"
			shift
			;;

		-q|--quiet)
			verbose=
			;;

		-r|--reboot)
			check_2nd_arg --reboot "${2-}" "reboot delay"
			! is_number "$2" && reboot_delay="" ||
				reboot_delay="$2"
			shift
			;;

		-s|--show)
			. "$libdir"/progress.sh

			show_progress
			;;

		-u|--username)
			check_2nd_arg --username "${2-}" \
				"username who is allowed to track progress"
			[ "$EUID" = 0 ] ||
				show_usage "You can't use '--username='."
			if [ "$2" != AUTO ]; then
				id -- "$2" >/dev/null 2>&1 ||
					show_usage "Unknown user: '%s'." "$2"
				[ "$2" != 0 ] && [ "$2" != root ] &&
				[ "$(id -u -- "$2")" -ge 500 ] 2>/dev/null ||
					show_usage "Invalid username: '%s'." "$2"
			fi
			username="$2"
			shift
			;;

		-V|--version)
			show_version
			;;

		-h|--help)
			show_help
			;;

		--)	shift
			break
			;;

		-*)	msg="Unsupported option: '%s'."
			show_usage "$msg" "$1"
			;;

		*)	break
			;;
		esac
		shift
	done

	[ "$#" = 0 ] || show_usage "Too many arguments."
}

# Adjusts the color mode of the console
#
setup_console()
{
	case "$colormode" in
	always)	colormode=1;;
	never)	colormode="";;
	*)	[ -t 1 ] && colormode=1 || colormode="";;
	esac

	reset_colors
}

# Shows the program version
#
show_version()
{
	local SU_VERSION=VERSION
	local SU_BUILD_DATE=BUILD_DATE

	. "$libdir"/version.sh

	printf "%s %s %s\n" "$progname" "$SU_VERSION" "$SU_BUILD_DATE"
	exit 0
}

# Shows a help message
#
show_help()
{
	local lang helpfile

	lang="${LC_ALL:-en_US.utf8}"
	lang="${LC_MESSAGES:-$lang}"
	lang="${LANG:-$lang}"
	lang="${lang%.*}"
	[ -n "$lang" ] ||
		lang=en_US
	helpfile="$libdir/l10n/$lang/help.msg"
	[ -s "$helpfile" ] ||
		helpfile="$libdir/l10n/en_US/help.msg"
	sed -e "s/@PROG@/$progname/g" <"$helpfile"
	exit 0
}

# Shows messages about use of program and terminates the program
#
show_usage()
{
	local msg

	if [ "$#" -ge 1 ]; then
		msg="$1"; shift
		printf "$msg\n" "$@" >&2
	fi

	msg="Invalid use of the command line."
	msg="$msg Try '%s -h' for more information."
	fatal "$msg" "$progname"
}

# Checks the second (required) argument, it cannot be empty
#
check_2nd_arg()
{
	local msg="After the option '%s' you should specify %s."

	[ -n "$2" ] && [ "x$2" != "x--" ] ||
		show_usage "$msg" "$1" "$3"
	return 0
}

