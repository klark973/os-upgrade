###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

#############################
### The stage: "finalize" ###
#############################

# Removes unneeded packages and old kernels
#
run_stage()
{
	local v pkgs=

	msg "Cleaning up the system of unnecessary packages..."

	# Build a final list of important packages
	for v in ${veto_packages//,/ } apt-repo systemd \
		apt make-initrd update-kernel grub-common
	do
		is_pkg_installed "$v" ||
			continue
		in_array "$v" $pkgs ||
			pkgs="$pkgs $v"
	done

	# 2.6. Remove all kernels excluding the used one
	run remove-old-kernels -f -A

	# Mark important packages to prevent them from being deleted
	run apt-mark manual -- ${pkgs:1}

	# Mark this package itself to autoremove
	[ -z "$autoclean" ] || run apt-mark auto -- "$progname"

	# Remove unnecessary packages
	run apt-get autoremove -y --force-yes

	# Clear the APT cache
	run apt-get clean

	# Define the next stage
	if [ -z "$ima_required" ]; then
		next_stage -n deinit
	else
		# 3.2. Prepare the integrity applier
		msg "Preparing the integrity applier for the next boot..."
		run integrity-applier -i -v -R

		if [ -n "$verbose" ]; then
			local f=/etc/sysconfig/grub2
			local key=GRUB_CMDLINE_LINUX_DEFAULT

			v="$(run sed -ne "s/^$key=//p" "$f")"
			msg_diag "%s" "$v"
		fi

		next_target "$progname.target"
		next_stage imasign
	fi
}

