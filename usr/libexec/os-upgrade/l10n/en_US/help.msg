Usage: @PROG@ [<options>...]

Options:
  -a, --apt=         The path to the additional list of APT sources that
                     will be used after switching to the target branch.
  -b, --background   Perform the main update, if possible, against the
                     background of normal work, don't use isolated targets.
  -c, --color=       Change a color output mode in the log and on the terminal:
                     * "auto": auto detection, used by default;
                     * "always": always output in different colors;
                     * "never": never use colors in the console.
  -d, --disable-ima  Don't re-enable the IMA/EVM protection after the update.
                     By default, protection is enabled automatically only
                     if it was enabled before the update started.
  -e, --enable-ima   Enable IMA/EVM protection after the update,
                     even if it was turned off before the update.
  -f, --force/--yes  Don't ask for confirmation of the update, just do it.
  -i, --important=   Prohibit accidental removal of the listed packages during
                     cleaning operations. Package names are separated by commas.
                     Before cleaning, these packages will be marked as manually
                     installed.
  -k, --keep-package Don't delete the package itself during the update.
  -l, --logfile=     Use the specified path to the log file.
  -m, --mirror=      Use the specified package repository mirror.
  -p, --ping=        Use the specified server to verify the network connection.
                     You can specify a minus sign ("-") as the name, in which
                     case this check will be skipped.
  -q, --quiet        Don't show all the details of the performing operations.
  -r, --reboot=      Use the specified reboot delay in seconds. To turn
                     it off completely, use the minus sign ("-").
  -s, --show         Show the current update progress. This is the only
                     operation that can be allowed to a regular user. If the
                     update has already been completed, the entire log will be
                     shown, otherwise only the latest entries are shown, new
                     entries are displayed interactively.
  -u, --username=    Allow the specified user to monitor the progress of
                     the execution. By default, the user will be identified
                     automatically. To allow only root to monitor progress,
                     specify a minus sign as the name (--username="-").
  -V, --version      Show the version of this program and exit.
  -h, --help         Show this help message and exit.

Please, report bugs to https://bugzilla.altlinux.org/
