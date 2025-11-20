###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

#############################
### Checks to ALT SP 10.0 ###
#############################

check_c10f1()
{
	local srv=

	# Check to the ALT SP distribution
	case "$PRETTY_NAME" in
	"ALT SP Server 11100-01")
		srv=1
		;; # It's OK
	"ALT SP Workstation 11100-01")
		;; # It's OK too
	*)	return 1;;
	esac

	# Check the ALT SP version
	case "$VERSION_ID" in
	10)	;; # This is also fine
	*)	return 1;;
	esac

	# The URL pointing to the selected mirror
	mirror="${mirror:-http://update.altsp.su/pub/distributions/ALTLinux}"

	# Mask these services on the ALT SP Server, see: ALT #47595
	if [ -n "$srv" ] && [ -z "${SUSPEND_BUTTONS-}" ]; then
		systemctl mask suspend-then-hibernate.target ||:
		systemctl mask hibernate.target ||:
		systemctl mask suspend.target ||:
	fi
}

