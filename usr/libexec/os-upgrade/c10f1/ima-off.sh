###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

############################
### The stage: "ima-off" ###
############################

# Deactivates IMA/EVM protection
#
run_stage()
{
	local f k

	msg "Deactivating IMA/EVM protection..."
	k="$(read_grub_cmdline)"

	# 2.1. Change grub config
	for f in lsm ima_appraise evm ima_hash; do
		k="$(printf "%s\n" "$k" |sed -e "s/ $f=[^[:space:]]*//")"
	done
	write_grub_cmdline "$k"

	# 2.2. Change initrd config
	f=/etc/initrd.mk
	[ ! -s "$f" ] ||
		run sed -i -E "/^FEATURES.*integrity/d" "$f"

	# 2.3. Remove the old policy
	run rm -f /etc/integrity/policy

	# 2.4. Remove old keys
	for f in evm-key.blob kmk-user.blob x509_evm.der x509_ima.der; do
		run rm -f "/etc/keys/$f"
	done

	# Workaround to run make-initrd
	run mountpoint -q /tmp && run mount -o remount,exec /tmp ||:

	# 2.5. Update the current initramfs image
	run make-initrd

	# 2.6. Update the grub menu
	run update-grub

	# Define the next target and stage
	next_target "$progname.target"
	next_stage upgrade
	no_reboot=
}

# Reads the current boot parameters from the grub configuration
#
read_grub_cmdline()
{
	local v f=/etc/sysconfig/grub2
	local key=GRUB_CMDLINE_LINUX_DEFAULT

	v="$(run sed -ne "s/^$key=//p" "$f")"
	msg_diag "%s" "$v"

	case "${v:0:1}" in
	"'"|'"')
		printf "%s" "${v:1:-1}"
		;;
	*)	printf "%s" "$v"
		;;
	esac
}

# Saves new boot parameters in the grub configuration
#
write_grub_cmdline()
{
	local v="$*"
	local f=/etc/sysconfig/grub2
	local key=GRUB_CMDLINE_LINUX_DEFAULT

	run sed -i -E "s|^($key)=.*$|\1='$v'|" "$f"
}

