###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

##########################
### The stage: "start" ###
##########################

# Prepares the service state directory and starts the daemon
#
run_stage()
{
	local v

	# Use common parts
	# shellcheck source=../start.sh
	. "$libdir/$stage.sh"

	# Initialization
	su_init_statedir

	# Determine of IMA/EVM protection
	v="head -n1 /sys/kernel/security/evm"
	will_run $v
	#
	if run test "$($v 2>/dev/null ||:)" = 1 ||
	   run grep -qs -E " (lsm|ima_appraise|evm|ima_hash)=" /proc/cmdline ||
	   run grep -qs -E "^FEATURES.*integrity" /etc/initrd.mk
	then
		msg "The IMA/EVM protection has been detected."
		ima_evm=1
	fi
	if [ -n "$ima_evm" ] && [ -z "$disable_ima" ]; then
		ima_required=1
	elif [ -n "$enable_ima" ]; then
		ima_required=1
	fi

	# Start the daemon
	su_start_daemon prepare
}

