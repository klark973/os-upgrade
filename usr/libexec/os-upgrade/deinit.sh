###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

###########################
### The stage: "deinit" ###
###########################

# Finishes the daemon
#
run_stage()
{
	local v

	msg "Disabling the %s service..." "$progname"
	run systemctl disable "$progname.service"

	# Restore the auditd service
	if [ -n "$auditd" ]; then
		msg "Enabling the auditd service..."
		run systemctl enable auditd.service

		if [ -z "$ima_required" ]; then
			msg "Starting the auditd service..."
			run systemctl start auditd.service
		fi
	fi

	# Delete this package itself
	msg "Preparing for cleaning..."
	run cp -Lf -- "$libdir"/cleanup.sh "$cleanup_script"
	v="systemd-run -q -d --no-block -- /bin/bash"
	next_stage finished
	run $v "$cleanup_script"
	su_exit
}

