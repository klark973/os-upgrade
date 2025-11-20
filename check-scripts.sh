#!/bin/bash -efu

# Directories to check
bindirs="SCRIPTDIR:usr/bin:usr/libexec/os-upgrade"

# List of scripts to skip
skip_check=

# Not interested shellcheck codes that need to be excluded
#
# https://www.shellcheck.net/wiki/SC2004: $/${} is unnecessary on arithmetic variables.
# https://www.shellcheck.net/wiki/SC2015: Note that A && B || C is not if-then-else.
# https://www.shellcheck.net/wiki/SC2034: Foo appears unused. Verify it or export it.
# https://www.shellcheck.net/wiki/SC2059: Don't use variables in the printf format string.
# https://www.shellcheck.net/wiki/SC2086: Double quote to prevent globbing and word splitting.
# https://www.shellcheck.net/wiki/SC2154: Var is referenced but not assigned.
# https://www.shellcheck.net/wiki/SC2268: Avoid x-prefix in comparisons...
# https://www.shellcheck.net/wiki/SC2329: This function is never invoked.
#
sclist="
	SC2004
	SC2015
	SC2034
	SC2059
	SC2086
	SC2154
	SC2268
	SC2329
"

do_check()
{
	local fname nc

	rm -f ERROR

	find usr -type f -and \( -name '*.sh' \
		 -or -path usr/bin/os-upgrade \
		 -or -path usr/libexec/os-upgrade/os-upgrade \
	\) |
	while read -r fname; do
		for nc in $skip_check _; do
			[ "$nc" != _ ] ||
				continue
			[ "$nc" != "$fname" ] ||
				continue 2
		done
		nc=( --norc -s bash "$@" -x "$fname" )
		shellcheck -P "$bindirs" "${nc[@]}" || :> ERROR
	done

	if [ -f ERROR ]; then
		rm -f ERROR
		return 1
	fi
}


excludes=
for e in $sclist; do
	excludes="${excludes:+$excludes,}$e"

	if [ "${1-}" = "-v" ] || [ "${1-}" = "--verbose" ]; then
		printf "*** Checking to %s...\n" "$e"
		do_check -i "$e" ||:
	fi
done

printf "*** Checking with all excludes...\n"
do_check -e "$excludes"

