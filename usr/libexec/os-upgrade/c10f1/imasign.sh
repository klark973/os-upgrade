###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

############################
### The stage: "imasign" ###
############################

# Launches the integrity applier for signing executable files
#
run_stage()
{
	local s=(
		"[--------]"
		"[\\\\\\\\\\\\\\\\]"
		"[||||||||]"
		"[////////]"
	) # a spinner
	local pid lines fsize n=0 m=9
	local log=/var/log/integrity-sign.log

	# Workaround to run make-initrd
	run mountpoint -q /tmp && run mount -o remount,exec /tmp ||:

	# 3.4. Run the integrity applier to sign files without reboot
	msg "Signing system files with the IMA certificate..."
	lines="systemd-run -p KeyringMode=inherit -p PrivateTmp=false"
	lines="$lines --service-type=oneshot -q -d -P --"
	lines="$lines integrity-applier -s -v -R --log=-"
	will_run $lines
	$lines >"$log" 2>&1 &
	pid="$!"
	#
	( local fmt="(%s lines) complete..."

	  # Show a line of initial results
	  fmt="\r${CLR_BOLD}%s ${CLR_LC1}%s${CLR_NORM} $fmt"
	  printf "$fmt" "${s[0]}" 0.0K 0

	  # While the integrity-applier is not finished...
	  while kill -0 "$pid" >/dev/null 2>&1
	  do
		sleep "0.$m"
		n="$((1 + $n))"
		[ "$n" -lt "${#s[@]}" ] ||
			n=0
		[ "$n" != 0 ] || [ "$m" = 1 ] ||
			m="$(($m - 1))"
		lines="$(wc -l -- "$log" |sed -E 's/\s+.*$//')"
		fsize="$(du -sh --apparent-size -- "$log" |cut -f1)"
		printf "$fmt" "${s[$n]}" "$fsize" "$lines"
	  done

	  # Clear the last line with results
	  printf "\r                                                       \r"
	) >"/dev/tty$TTY_NUMBER"
	#
	# Log the finally results
	msg_bold "The IMA signing log: @BOLD@" "$log"
	lines="$(wc -l -- "$log" |sed -E 's/\s+.*$//')"
	fsize="$(du -sb --apparent-size -- "$log" |cut -f1)"
	msg "%s bytes (%s lines) complete." "$fsize" "$lines"
	#
	# Remove 'zombie' flag
	wait "$pid" >/dev/null 2>&1 ||:

	# Check the results
	if [ "$lines" = 2 ] &&
	   grep -qs "integrity-applier: Error while signing" "$log"
	then
		su_fatal "Something's wrong: IMA signing has been failed!"
	fi

	# 3.3. Enable IMA-specific services
	msg "Enabling IMA/EVM protection services..."
	run systemctl -q is-enabled integrity-scanner.service ||
		run systemctl enable integrity-scanner.service
	run systemctl -q is-enabled integrity-notifier.service ||
		run systemctl enable integrity-notifier.service
	run systemctl -q is-enabled ima-check.service ||
		run systemctl enable ima-check.service

	# Restore the default systemd target
	next_target --restore

	# Move on to the next stage
	next_stage -n deinit
}

