###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

############################
### The stage: "upgrade" ###
############################

# Updates packages and the kernel
#
run_stage()
{
	local v opts="-y -q --force-yes"
	local msg1="Try #@BOLD@: updating the system"
	      msg1="$msg1 from the c10f1 repository..."
	local msg2="Try #@BOLD@: updating the system"
	      msg2="$msg2 from the c10f2 repository..."
	local msg3="Try #@BOLD@: updating the Linux kernel"
	      msg3="$msg3 from the c10f2 repository..."
	local macro=/etc/rpm/macros.d/priority_distbranch

	CB_inst_c10f1()
	{
		msg_bold "$msg1" "$1/$2"
		run apt-get dist-upgrade $opts
	}

	CB_inst_c10f2()
	{
		msg_bold "$msg2" "$1/$2"
		run apt-get dist-upgrade $opts ||
			return $?
		[ -z "$ima_required" ] ||
		run apt-get install $opts attr ima-evm-integrity-check
	}

	CB_inst_kernel()
	{
		msg_bold "$msg3" "$1/$2"
		run update-kernel -f -t 6.12
	}

	# 1.2. Update from the c10f1 repository
	try CB_inst_c10f1 3
	unset CB_inst_c10f1

	# 2.1. Finally switch to the c10f2 branch
	run rm -rf /var/lib/apt/lists /var/cache/apt
	run mv -f /var/cache/apt.c10f2 /var/cache/apt
	run mv -f /var/lib/apt/lists.c10f2 /var/lib/apt/lists
	run mv -f -- "$statedir"/sources.c10f2 /etc/apt/sources.list
	printf "%%_priority_distbranch c10f2\n" >"$macro"
	run chmod -- 0644 "$macro"
	run rpm --eval %_priority_distbranch

	# 2.4. Backup OSEC settings
	[ ! -d /etc/osec/integalert ] ||
		run mv -f /etc/osec/integalert "$statedir"/
	[ ! -d /etc/osec/integalert_fix ] ||
		run mv -f /etc/osec/integalert_fix "$statedir"/

	# Workaround to run make-initrd
	run mountpoint -q /tmp && run mount -o remount,exec /tmp ||:

	# 2.5. Update from the c10f2 repository
	try CB_inst_c10f2 5
	unset CB_inst_c10f1
	try CB_inst_kernel 5
	unset CB_inst_kernel
	run rm -f -- "$macro"

	# Disable the integalert service again
	v="systemctl -q is-enabled integalert.service"
	if [ -n "$integalert" ] && will_run $v && $v 2>/dev/null; then
		msg "Disabling the integalert service again..."
		run systemctl disable integalert.service
	fi

	# Define the next target and stage
	if [ -n "$ima_required" ]; then
		next_target "$progname.target"
	else
		next_target --restore
	fi
	#
	next_stage finalize
}

