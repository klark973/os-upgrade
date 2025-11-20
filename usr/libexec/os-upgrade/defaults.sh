###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2025, ALT Linux Team

#################################
### OS Upgrade default values ###
#################################

# The URL pointing to the default mirror
default_mirror="http://ftp.altlinux.org/pub/distributions/ALTLinux"

# The full path to the self-removal script of this package
cleanup_script="/tmp/$progname-cleanup.sh"

# The full path to the log file
logfile="/var/log/$progname.log"

# The DNS-name or IP-address of the server for checking the network connection
ping_server=ya.ru

# The delay before restarting the system in seconds
reboot_delay=10

# The URL pointing to the selected mirror
mirror=

# Additional APT sources list to be used after switching to the target branch
apt_sources=

# 1: delete the os-upgrade package itself after the update
autoclean=

# 1: do not use isolated systemd targets if possible
background=

# 1: enable color output to the console and to the log
colormode=

# 1: do not re-enable the IMA/EVM protection after the update
disable_ima=

# 1: enable IMA/EVM after the update, even if it has not been activated before
enable_ima=

# 1: the IMA must be activated after the update (calculated automatically)
ima_required=

# A list of packages that should be marked as necessary to prevent deletion
veto_packages=

# The user who is allowed to monitor the progress of the system update
username=

# 1: the IMA/EVM protection was activated before the update
ima_evm=

# 1: the integalert service was enabled before the update
integalert=

# 1: the auditd service was enabled before the update
auditd=

# Platform
platform=

# Bi-arch name
biarch=

# The source branch name
branch=

# Current stage name or "finished"
stage=

# Saved value of the previous one
last_stage=

# 1: do not restart the system after finishing the daemon
no_reboot=

# 1: show all the details of the performing operations
verbose=

# The specified TTY number
TTY_NUMBER=@TTY_NUMBER@

# Console colors
CLR_NORM="\033[00m"
CLR_BOLD="\033[01;37m"
CLR_LC1="\033[00;36m"
CLR_LC2="\033[00;33m"
CLR_OK="\033[01;32m"
CLR_ERR="\033[01;31m"
CLR_WARN="\033[01;33m"

