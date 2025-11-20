###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

############################
### The stage: "prepare" ###
############################

# Download packages and deactivates IMA/EVM protection
#
run_stage()
{
	# This is the first stage after starting the service
	msg "The program was started as a service."

	# Determine the platform settings
	platform="$(run uname -m)"
	[ "$platform" != x86_64 ] ||
		biarch=x86_64-i586
	msg_diag "%s" "$platform"

	# Download the packages to the cache
	check_c10f2_repo
	check_c10f1_repo

	# Deactivate IMA/EVM protection
	if [ -n "$ima_evm" ]; then
		next_stage -n ima-off
		return 0
	fi

	# Continue updating without rebooting in this case
	if [ -n "$background" ] && [ -z "$auditd" ]; then
		no_reboot=1
	elif [ -z "$background" ]; then
		next_target "$progname.target"
	fi

	# Define the next stage
	next_stage upgrade
}

# Downloads packages from the c10f2 repository
#
check_c10f2_repo()
{
	local value repo
	local branch=c10f2
	local macro=/etc/rpm/macros.d/priority_distbranch

	# Compute the repository URL
	if [ "${mirror:0:5}" = "file:" ]; then
		repo="$mirror/$branch"
	elif [ "${mirror:0:1}" = "/" ]; then
		repo="file:$mirror/$branch"
	else
		repo="$mirror/$branch/branch"
	fi

	# Clear the file system, APT indexes and APT cache
	run rm -rf /var/lib/apt/lists.c10f1
	run rm -rf /var/lib/apt/lists.c10f2
	run rm -rf /var/cache/apt.c10f1
	run rm -rf /var/cache/apt.c10f2
	run apt-repo rm all
	run apt-get update
	run apt-get clean

	# Save the APT state
	[ ! -f /etc/apt/sources.list ] ||
		run cp -Lpf /etc/apt/sources.list "$statedir"/
	run cp -Lprf /var/lib/apt/lists /var/lib/apt/lists.c10f1
	run cp -Lprf /var/cache/apt /var/cache/apt.c10f1

	# Actually this directory is already provided by the rpm package
	run mkdir -p -- "${macro%/*}"
	run chmod -- 0755 "${macro%/*}"

	# 2.1. Switch to the new branch
	printf "%%_priority_distbranch %s\n" "$branch" >"$macro"
	run chmod -- 0644 "$macro"

	# 2.2. Make sure that the previous step went fine
	value="$(run rpm --eval %_priority_distbranch)"
	msg_diag "%s" "$value"
	#
	if [ "$value" != "$branch" ]
	then
		run rm -f -- "$macro"
		run rm -rf /var/cache/apt.c10f1
		run rm -rf /var/lib/apt/lists.c10f1
		su_fatal "Couldn't set the new branch: %s" "$branch"
	fi

	# 2.3. Change APT sources
	value=/etc/apt/sources.list
	( echo "# Added automatically by $progname"
	  echo "rpm [cert8] $repo $platform classic gostcrypto"
	  [ -z "$biarch" ] ||
		echo "rpm [cert8] $repo $biarch classic"
	  echo "rpm [cert8] $repo noarch classic"
	  [ ! -r "$statedir"/sources.add ] ||
		cat -- "$statedir"/sources.add
	) >>"$value"
	run chmod -- 0644 "$value"
	run cp -Lpf -- "$value" "$statedir"/sources.c10f2
	run apt-repo
	value=

	# 2.5. Update indexes, user space and kernel
	download_packages "$branch" || value=1

	# Restore the APT state
	[ ! -f "$statedir"/sources.list ] ||
		run cp -Lpf -- "$statedir"/sources.list /etc/apt/
	run mv -f /var/lib/apt/lists /var/lib/apt/lists.c10f2
	run mv -f /var/lib/apt/lists.c10f1 /var/lib/apt/lists
	run mv -f /var/cache/apt /var/cache/apt.c10f2
	run mv -f /var/cache/apt.c10f1 /var/cache/apt
	run rm -f -- "$macro"

	# Final check
	if [ -n "$value" ]; then
		run rm -rf /var/cache/apt.c10f2
		run rm -rf /var/lib/apt/lists.c10f2
		su_fatal "Failed to download packages!"
	fi
}

# Downloads packages from the c10f1 repository
#
check_c10f1_repo()
{
	local branch=c10f1
	local repo="$mirror c10f/branch/"
	local value=/etc/apt/sources.list.d/altsp.list

	# Compute the repository URL
	if [ "${mirror:0:5}" = "file:" ]; then
		repo="$mirror/$branch"
	elif [ "${mirror:0:1}" = "/" ]; then
		repo="file:$mirror/$branch"
	elif [ -s "$value" ] && grep -qs -- "$repo" "$value"; then
		repo="$mirror/c10f/branch"
	else
		repo="$mirror/$branch/branch"
	fi

	# 1.1. Change APT sources
	value=/etc/apt/sources.list
	( echo "# Added automatically by $progname"
	  echo "rpm [cert8] $repo $platform classic gostcrypto"
	  [ -z "$biarch" ] ||
		echo "rpm [cert8] $repo $biarch classic"
	  echo "rpm [cert8] $repo noarch classic"
	) >>"$value"
	run chmod -- 0644 "$value"
	run apt-repo
	value=

	# 1.2. Update indexes and user space
	download_packages "$branch" || value=1

	# Final check
	if [ -n "$value" ]; then
		run rm -rf /var/cache/apt.c10f2
		run rm -rf /var/lib/apt/lists.c10f2
		su_fatal "Failed to download packages!"
	fi
}

# Downloads packages from the specified repository
#
download_packages()
{
	local dp_imp="" v dp_repo="$1"
	local dp_opts="-y -d -q --force-yes"
	local dp_msg1="Try #@BOLD@: updating APT indexes..."
	local dp_msg2="Downloading packages from the @BOLD@ repository..."

	CB_dp_inner()
	{
		msg_bold "$dp_msg1" "$1/$2"
		run apt-get update ||
			return $?
		msg_bold "$dp_msg2" "$dp_repo"
		run apt-get dist-upgrade $dp_opts ||
			return $?
		[ -z "$dp_imp" ] ||
		run apt-get install $dp_opts -- ${dp_imp:1}
	}

	if [ "$dp_repo" = c10f2 ] && [ -n "$ima_required" ]; then
		for v in attr ima-evm-integrity-check; do
			is_pkg_installed "$v" ||
				dp_imp="$dp_imp $v"
		done
	fi

	try CB_dp_inner 7
	unset CB_dp_inner
}

