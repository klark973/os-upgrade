###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

#########################################
### Parts of the common "start" stage ###
#########################################

# Prepares the service state directory
#
su_init_statedir()
{
	local v

	# Determine the regular user
	if [ -z "$username" ]; then
		v="loginctl list-users --no-pager"
		v="$v --no-legend |grep -v -E ' root\$'"
		[ "$(eval "$v |wc -l")" != 1 ] && v="" ||
			v="$(eval "$v |head -n1 |cut -f2 -d' '")"
		username="$v"
	fi

	# Reset the username if it is equal '-'
	if [ "x$username" = "x-" ]; then
		username=

	# Make the log readable by the regular user
	elif [ -n "$username" ]; then
		v="$(run id -ng -- "$username")"
		msg_diag "%s" "$v"
		run chgrp -- "$v" "$logfile"
		run chmod -- 0640 "$logfile"
	fi

	# Save the main control fields
	msg "Initializing the service state..."
	run rm -rf --one-file-system -- "$statedir"
	run mkdir -p -- "$statedir"
	write_state_var logfile
	write_state_var colormode
	write_state_var reboot_delay
	write_state_var username
	write_state_var verbose
	write_state_var branch
	write_state_var stage

	# Make few fields readable by the regular user
	if [ -n "$username" ]; then
		run chgrp -- "$v" "$statedir"/STAGE
		run chgrp -- "$v" "$statedir"/LOGFILE
		run chgrp -- "$v" "$statedir"/COLORMODE
		run chgrp -- "$v" "$statedir"/USERNAME
		run chgrp -- "$v" "$statedir"
		run chmod -- 0640 "$statedir"/STAGE
		run chmod -- 0640 "$statedir"/LOGFILE
		run chmod -- 0640 "$statedir"/COLORMODE
		run chmod -- 0640 "$statedir"/USERNAME
		run chmod -- 0750 "$statedir"
	fi

	# Determine the current systemd default target
	v="$(run systemctl get-default)"
	msg_diag "%s" "$v"
	write_state_var v DEFAULT

	# A bit of diagnostics
	if [ -n "$verbose" ]; then
		msg "Collecting diagnostic data for technical support..."

		set +o errtrace
		( set +o errexit
		  run /bin/bash "$scriptname" --version
		  run /bin/bash --version |head -n1
		  run rpm --eval %_priority_distbranch
		  run cat /etc/os-release
		  run cat /proc/cmdline
		  run uname -mrs
		  run apt-repo
		  ! can_run inxi ||
			run inxi -c0 -v8
		  [ ! -s /boot/boot.conf ] ||
			run cat /boot/boot.conf
		  [ ! -s /etc/sysconfig/grub2 ] ||
			run grep -v -E '^(#|\s*$)' /etc/sysconfig/grub2
		  [ ! -s /etc/initrd.mk ] ||
			run cat /etc/initrd.mk
		  [ ! -s /etc/mdadm.conf ] ||
			run cat /etc/mdadm.conf
		  ! can_run multipath ||
			run multipath -ll && run multipath -v3 ||:
		  run grep -v -E '^(#|\s*$)' /etc/fstab
		  ! can_run lsblk ||
			run lsblk -f
		  run findmnt
		  run systemctl --no-pager status |head -n5
		  run systemctl --no-pager --failed |head -n20
		  run loginctl --no-pager list-users |head -n20
		  run loginctl --no-pager list-sessions |head -n20
		)
		set -o errtrace
	fi

	# Temporary disable the auditd service
	v="systemctl -q is-enabled auditd.service"
	if will_run $v && $v 2>/dev/null; then
		msg "Disabling the auditd service..."
		run systemctl disable auditd.service
		auditd=1
	fi

	# Temporary disable the integalert service
	v="systemctl -q is-enabled integalert.service"
	if can_run integalert && will_run $v && $v 2>/dev/null; then
		msg "Disabling the integalert service..."
		run systemctl disable --now integalert.service
		integalert=1
	fi
}

# Installs the service and starts the daemon
#
su_start_daemon()
{
	local m next="$1"
	local v=/etc/sysconfig/grub2

	# Fix a known installer issue by removing the
	# "init_on_free=1" parameter from these comments:
	#
	#   #GRUB_AUTOUPDATE_DEVICE='/dev/sda  init_on_free=1'
	#   #GRUB_AUTOUPDATE_FORCE='no init_on_free=1'
	#   #GRUB_PRELOAD_MODULES=' init_on_free=1'
	#
	if grep -qs -E '^#.* init_on_free=1' "$v"; then
		msg "Correcting strange comments in %s..." "$v"
		run sed -i -E "s/^(#.*) init_on_free=1'$/\1'/g" "$v"
	fi

	# Fix a known system issue by disabling the secondary
	# nscd/nslcd caches to resolve potential conflicts
	#
	v="systemctl -q is-enabled sssd.service"
	if will_run $v && $v 2>/dev/null; then
		m="Disabling the %s service because sssd is enabled..."

		v="systemctl -q is-enabled nslcd.service"
		if will_run $v && $v 2>/dev/null
		then
			msg "$m" nslcd
			run systemctl disable --now nslcd.service
		fi

		v="systemctl -q is-enabled nscd.service"
		if will_run $v && $v 2>/dev/null
		then
			msg "$m" nscd
			run systemctl disable --now nscd.service nscd.socket
			run systemctl mask nscd.service
		fi
	else
		v="systemctl -q is-enabled nslcd.service"
		m="systemctl -q is-enabled nscd.service"
		if will_run $v && $v 2>/dev/null &&
		   will_run $m && $m 2>/dev/null
		then
			msg "Disabling the nscd service because nslcd is enabled..."
			run systemctl disable --now nscd.service nscd.socket
			run systemctl mask nscd.service
		fi
	fi

	# Save additional APT sources
	if [ -n "$apt_sources" ]; then
		run cp -Lf -- "$apt_sources" "$statedir"/sources.add
	fi

	# Save the remaining fields
	write_state_var autoclean
	write_state_var background
	write_state_var veto_packages
	write_state_var mirror
	write_state_var ping_server
	write_state_var ima_evm
	write_state_var ima_required
	write_state_var integalert
	write_state_var auditd
	save_${branch}_data

	# Install the service
	v="/usr/local/libexec/$progname"
	if [ ! -s "$v"/main.sh ]; then
		msg "Installing the OS Upgrade service..."
		run mkdir -p -m 0755 /usr/local/libexec
		run mkdir -p -m 0755 /etc/systemd/system
		run cp -aRf -- "$libdir" /usr/local/libexec/
		run sed -i -E "s|^(readonly libdir)=.*$|\1=\"$v\"|" "$v"/main.sh
		(set +f; run cp -Lf -- "$libdir"/units/* /etc/systemd/system/)
		run chmod -- 0644 "$v/$progname"
		run systemctl -q daemon-reload
	fi

	# Prepare for the next stage without rebooting
	next_stage -n "$next"
	v=0

	# Start the Software Updater service
	msg "Enabling the OS Upgrade service..."
	run systemctl enable "$progname.service"
	msg "Starting the OS Upgrade service..."
	run systemctl start "$progname.service" || v="$?"
	exit "$v"
}

