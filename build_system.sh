#!/bin/bash

# build_system.sh: build a bootable Linux system on a USB stick with the
# MMGen Bitcoin wallet preinstalled (https://github.com/mmgen/mmgen).
#
# mmgen = Multi-Mode GENerator, command-line Bitcoin cold storage solution
# Copyright (C)2013-2016 Philemon <mmgen-py@yandex.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

export LANG=en_US.UTF-8; export LANGUAGE=en

[ $EUID = '0' ] || { echo 'This script must be run as root'; exit; }
PROGNAME=`basename $0`
SCRIPT=$PROGNAME

declare -A RELEASES=(
	[wily]="Ubuntu 15.10 'wily'"
	[xenial]="Ubuntu 16.04 'xenial'"
	[jessie]="Debian 8.x 'jessie'"
)

# defaults
RELEASE='xenial'
ARCH='amd64'
export ARCH_BITS='64'
DO_BLANK=
DO_INSTALL_EXTRAS_TTY=1 DO_INSTALL_EXTRAS_GFX=1 DO_INSTALL_X=1

declare -A DESCS=(
	[apt_get_update]='update package lists'
	[backup_apt_archives]='back up apt archives'
	[backup_apt_lists]='back up apt lists'
	[backup_chroot_system]='back up chroot system'
	[build]='build the complete MMGenLive system; install on USB stick'
	[build_base]='build the base debootstrap system with no MMGen additions'
	[build_chroot]='build the chroot system with MMGen additions'
	[build_live_system]='build the live system in the chroot'
	[build_mmgen_sdist]='build MMGen source archive'
	[build_usb]='copy the live system to the USB drive; configure the system'
	[copy_mmgen_sdist]='copy MMGen source archive to chroot system'
	[copy_user_bitcoind_to_chroot]='copy user-supplied Bitcoin Core tar archive to chroot system'
	[cleanup_mmgen_builds]='clean up build files in the /setup directory'
	[install_bitcoind]='install Bitcoin Core on the chroot system'
	[install_host_dependencies]='install required packages on build machine'
	[install_mmgen_dependencies]='install MMGen dependencies'
	[install_mmgen]='install MMGen on the chroot system'
	[install_vanitygen]='install Vanitygen'
	[test_mmgen]='test the MMGen wallet suite'
	[mount_boot_chroot]='mount the USB drive boot partition on the chroot system'
	[mount_boot_usb]='mount the USB drive boot partition on the USB drive'
	[mount_root]='mount the USB drive root partition'
	[mount_vfs_chroot]='mount virtual filesystems on chroot dir'
	[partition_usb_boot]='create the USB drive boot partition'
	[partition_usb_root]='create the USB drive root partition'
	[restore_chroot_system]='restore the chroot system from saved archive'
	[restore_apt_archives]='restore the apt archives on the chroot system'
	[restore_apt_lists]='restore the apt lists on the chroot system'
	[setup_user]='set up the user account'
	[umount_all]='unmount mounted filesystems'
	[umount_vfs_chroot]='unmount virtual filesystems on chroot dir'
	[umount_vfs_usb]='unmount virtual filesystems on USB drive'
	[usbimg2file]='copy the USB disk image to file'

	[install_grub]='install the GRUB boot loader'
	[install_kernel]='install the Linux kernel'
	[install_system_utils]='install system utilities'
	[install_x]='install the X Window system'
	[remove_packages]='delete unneeded packages from live system'

	[usb_config_misc]='configure services on USB system'
	[usb_copy_system]='copy chroot system to USB drive'
	[usb_create_grub_cfg_file]='create GRUB configuration file (grub.cfg)'
	[usb_create_system_cfg_files]='create system configuration files on USB drive'
	[usb_gen_locales]='generate configured locales'
	[usb_install_extras_gfx]='install X Windows extras'
	[usb_install_extras_tty]='install console extras'
	[usb_pre_initramfs]='do pre-update-initramfs configurations on USB drive'
	[usb_update_initramfs]='generate the init RAM filesystem'
	[usb_update_mmgen]='update the MMGen installation on the USB stick'

	[depclean]='keep all built and downloaded files; reset progress state to zero'
	[clean]='delete all built files but keep archives of bootstrap and chroot system; reset progress state to zero'
	[distclean]='delete all generated and downloaded files; restore repository to its original state'
)

declare -A TARGETS
for i in ${!DESCS[@]}; do
	[ ${i:0:7} != 'chroot_' -a ${i:0:5} != 'live_' ] && TARGETS[$i]=${DESCS[$i]}
done
TARGET='build'


while getopts hAbBcCdDGiLMor:sSuvxX OPT
do
	case "$OPT" in
	h)  printf "  %-16s Build an MMGenLive system\n" "${PROGNAME^^}:"
		echo   "  USAGE:           $PROGNAME [options] [target]"
		echo   "  OPTIONS: '-h'    Print this help message"
		echo   "           '-A'    Don't backup/restore apt archive"
		echo   "           '-b'    Blank partitions before formatting for greater security"
		echo   "           '-B'    Don't back up the chroot system after building it"
		echo   "           '-c'    Don't do cleanup/unmount at end of script execution"
		echo   "           '-C'    Don't install console extras (this is not recommended)"
		echo   "           '-d'    Print debugging information"
		echo   "           '-D'    Print out dependency information; don't execute targets"
		echo   "           '-G'    Don't install graphical extras (this is not recommended)"
		echo   "           '-i'    Build for Intel i386 (32-bit) architecture (not implemented yet)"
		echo   "           '-L'    Don't backup/restore '/var/lib/apt/lists' dir"
		echo   "           '-M'    Skip MMGen test"
		echo   "           '-o'    Build image on loop device instead of USB stick (doesn't work)"
		echo   "           '-r r'  Install Ubuntu/Debian release 'r' (choices: ${!RELEASES[*]})"
		echo   "           '-s'    Simulate, don't execute, shell commands"
		echo   "           '-S'    Simulate, don't execute, shell commands (in chroot only)"
		echo   "           '-u'    Skip 'apt-get update' -- assume cache is current"
		echo   "           '-v'    Produce more verbose output"
		echo   "           '-x'    Echo shell commands ('set -x')"
		echo   "           '-X'    Don't install X Window system"
		echo
		echo   "  Available releases:   ${RELEASES[*]}"
		echo   "  Default release:      ${RELEASES[$RELEASE]}"
		echo   "  Default architecture: $ARCH ($ARCH_BITS-bit)"
		echo
		echo   "  Available targets:"
		(for i in "${!TARGETS[@]}"; do
		 	printf "      %-32s - %s\n" "$i" "${TARGETS[$i]}"
		done | sort)
		echo   "  Default target:"
		echo   "      $TARGET"
		exit ;;
	A)  NO_APT_BACKUP=1 ;;
	b)  DO_BLANK=1 ;;
	B)  NO_CHROOT_BACKUP=1 ;;
	c)  NO_CLEAN=1 ;;
	C)  DO_INSTALL_EXTRAS_TTY= ;;
	d)  DEBUG=1 ;;
	D)  SHOW_DEPENDS=1 ;;
	G)  DO_INSTALL_EXTRAS_GFX= ;;
	i)  ARCH='i386' ARCH_BITS='32'; echo "32-bit build is not implemented yet"; exit ;;
	L)  NO_APT_LISTS_BACKUP=1 ;;
	M)  SKIP_MMGEN_TEST=1 ;;
	o)  LOOP_INSTALL=1 ;;
	r)  RELEASE=$OPTARG ;;
	s)  SIMULATE=1 ;;
	S)  SIMULATE_IN_CHROOT=1 ;;
	u)  APT_UPDATED=1 ;;
	v)  VERBOSE=1 ;;
	x)  ECHO_CMDS=1 ;;
	X)  DO_INSTALL_X= DO_INSTALL_EXTRAS_GFX= ;;
	*)  exit ;;
	esac
done

OPTS=${@:1:$OPTIND-1}

shift $((OPTIND-1))

if [ "$1" -a "$1" == "${1/=}" ]; then TARGET=$1; shift; else TARGET='build'; fi

if [ $SCRIPT == 'build_system.sh' -a ! "${TARGETS[$TARGET]}" ]; then
	echo $TARGET: bad target
	exit
fi

eval "$@" || exit
#echo "$@"; exit

if which infocmp >/dev/null && infocmp $TERM 2>/dev/null | grep -q 'colors#256'; then
	RED="\e[38;5;210m" YELLOW="\e[38;5;228m" GREEN="\e[38;5;157m"
	BLUE="\e[38;5;45m" RESET="\e[0m"
else
	RED="\e[31;1m" YELLOW="\e[33;1m" GREEN="\e[32;1m" BLUE="\e[34;1m" RESET="\e[0m"
fi

function msg()  { echo ${2:+$1} $PROJ_NAME: "${2:-$1}"; }
function rmsg() { echo -e ${2:+$1} $RED$PROJ_NAME: "${2:-$1}$RESET"; }
function ymsg() { echo -e ${2:+$1} $YELLOW$PROJ_NAME: "${2:-$1}$RESET"; }
function gmsg() { echo -e ${2:+$1} $GREEN$PROJ_NAME: "${2:-$1}$RESET"; }
function bmsg() { echo -e ${2:+$1} $BLUE$PROJ_NAME: "${2:-$1}$RESET"; }
function pause() { ymsg -n 'Paused.  Hit ENTER to continue: '; read junk; }

function dbecho() { return; echo -e "${RED}DEBUG: $@$RESET"; }
function recho() { echo -e ${2:+$1} "$RED${2:-$1}$RESET"; }
function yecho() { echo -e ${2:+$1} "$YELLOW${2:-$1}$RESET"; }
function gecho() { echo -e ${2:+$1} "$GREEN${2:-$1}$RESET"; }
function becho() { echo -e ${2:+$1} "$BLUE${2:-$1}$RESET"; }

function debug_msg() {
	printf "%b%s:%b %b%s%b\n" $RED 'Debug' $RESET $YELLOW "$1" $RESET
}

function mount_vfs_chroot() { mount_vfs $CHROOT_DIR; }
function mount_vfs_usb()    { mount_vfs $USB_MNT_DIR; }
function mount_vfs() {
	DIR=$1
	[ "$TARGET" == ${FUNCNAME[1]} ] && NO_CLEAN=1 # called by user
	FOUND=
	for i in proc:proc:proc sysfs:sys:sysfs udev:dev:devtmpfs tmpfs:dev/shm:tmpfs devpts:dev/pts:devpts; do
		a=${i/:*} d=${i#*:} b=${d/:*} c=${d/*:}
		exec_or_die "mountpoint -q $DIR/$b || { mount -t $c $a $DIR/$b; FOUND=1; }"
	done
	[ "$FOUND" ] && msg "Mounted virtual filesystems under '$DIR'"
	return 0
}

function umount_vfs_chroot() { umount_vfs $CHROOT_DIR; }
function umount_vfs_usb()    { umount_vfs $USB_MNT_DIR; }
function umount_vfs() {
	DIR=$1
	[ "$TARGET" == ${FUNCNAME[1]} ] && NO_CLEAN=1 # called by user
	A='thermald dbus-daemon xl2tpd tor gmain gdbus NetworkManager'
	if lsof -v 2>/dev/null; then
		PIDS=`lsof -c ${A// / -c } +c0 | grep $DIR | awk '{ print $2 }' | uniq`
		[ "$PIDS" ] && { for i in $PIDS; do exec_or_die "kill $i"; done; sleep 1; }
	fi

	FOUND=
	for i in dev/shm dev/pts proc sys dev; do
		mp=$DIR/$i
		if mountpoint -q $mp; then
			FOUND=1
			umount $mp || { rmsg "Unable to unmount '$mp'"; exit; }
		fi
	done
	[ "$FOUND" ] && msg "Unmounted virtual filesystems under '$DIR'"
	return 0
}

function mount_root() {
	[ "$TARGET" == $FUNCNAME ] && CBU=1 # called by user
	mountpoint -q "$USB_MNT_DIR" && { [ "$CBU" ] && exit; return; }
	[ "$USB_P2" ] || get_target_dev

	gmsg "Mounting $USB_DEV_DESC on '$USB_MNT_DIR'"

	close_luks_partition $DM_DEV
	open_luks_partition $USB_P2 $DM_DEV

	exec_or_die "mkdir -p $USB_MNT_DIR"
	msg 'Mounting LUKS partition'
	exec_or_die "mount /dev/mapper/$DM_DEV $USB_MNT_DIR"

	[ "$CBU" ] && exit # called by user
}

function umount_root() {
	mountpoint -q "$USB_MNT_DIR" || return

	gmsg "Unmounting root partition on '$USB_MNT_DIR'"
	msg 'Unmounting LUKS partition'
	exec_or_die "umount $USB_MNT_DIR"

	close_luks_partition $DM_DEV

	exec_or_die 'L=`losetup -O NAME -lnj $LOOP_FILE`'
	[ "$L" ] && {
		msg "Detaching loop device '$L'"
		exec_or_die "losetup -d $L"
	}
}

function mount_boot_chroot() { mount_vfs_chroot; mount_boot $CHROOT_DIR; }
function mount_boot_usb()    { mount_root; mount_vfs_usb; mount_boot $USB_MNT_DIR; }
function mount_boot() {
	dbecho "==> $FUNCNAME($@)"
	DIR=$1
	[ "$TARGET" == ${FUNCNAME[1]} ] && CBU=1 # called by user
	MNT_DIR="$DIR/boot"
	mountpoint -q $MNT_DIR && { [ "$CBU" ] && exit; return; }
	[ "$USB_P1" ] || get_target_dev

	[ `lsblk -no LABEL $USB_P1` == $BOOTFS_LABEL ] || die 'Boot partition label incorrect!'
	exec_or_die "mkdir -p $MNT_DIR"

	gmsg "Mounting boot partition on '$MNT_DIR'"
	exec_or_die "umount $MNT_DIR 2>/dev/null || true"
	exec_or_die "mount $USB_P1 $MNT_DIR"

	[ "$CBU" ] && exit
}

function umount_boot_chroot() { umount_boot $CHROOT_DIR; }
function umount_boot_usb()    { umount_boot $USB_MNT_DIR; }
function umount_boot() {
	DIR=$1 MNT_DIR="$DIR/boot"
	mountpoint -q $MNT_DIR || return

	gmsg "Unmounting boot partition on '$MNT_DIR'"
	exec_or_die "umount $MNT_DIR"
#	exec_or_die "umount $MNT_DIR 2>/dev/null || true"
}

function clean_exit() {
	[ "$SCRIPT" == 'setup.sh' -o "$NO_CLEAN" ] && exit 1
	umount_all
	HUSH_EXIT=
	exit
}

function die() {
	MSG="${1:-script died} on line number $BASH_LINENO in function '${FUNCNAME[1]}'"
	if [ "$SIMULATE" -o "$SIMULATE_IN_CHROOT" -a "$SCRIPT" == 'setup.sh' ]; then
		msg -e "Would have died with message: $YELLOW$MSG$RESET"
	else
		printf "%b%s: %s%b\n" $RED $PROJ_NAME "$MSG" $RESET
		[ "$SCRIPT" == 'setup.sh' ] && exit 1
		clean_exit
	fi
}
function exec_or_die_print() {
	echo "Executing: $@"
	exec_or_die "$@"
}
function exec_or_die() {
	if [ "$SIMULATE" -o "$SIMULATE_IN_CHROOT" -a "$SCRIPT" == 'setup.sh' ]; then
		echo -e "\nWould execute: $YELLOW$1$RESET"
	elif [ "$SIMULATE_SILENT" ]; then
		true
	else
		[ "$ECHO_CMDS" ] && set -x
		eval "$@" || {
			set +x
			echo -e "$RED$PROJ_NAME: '$@' failed, line number $BASH_LINENO$RESET"
			[ "$SCRIPT" == 'setup.sh' ] && exit 1
			clean_exit
		}
		set +x
	fi
}
function delete_chroot() {
	if [ "`ls $CHROOT_DIR`" ]; then
		gmsg "Deleting '$CHROOT_DIR'"
		exec_or_die "rm -rf $CHROOT_DIR"
	fi
}
function build_mmgen_sdist() {
	dbecho "=======> $FUNCNAME"
	exec_or_die_print '(cd ../mmgen && rm -rf build test/tmp*)'
	exec_or_die_print '(cd ../mmgen && ./setup.py -q clean)'
	exec_or_die_print '(cd ../mmgen && ./setup.py -q sdist 2>/dev/null)'
}
function apt_get_update () {
	if [ "$TARGET" == "$FUNCNAME" ]; then # called by user, for chroot system
		mount_vfs_chroot
		chroot $CHROOT_DIR apt-get update
		chroot $CHROOT_DIR apt-get upgrade
	elif [ "$SCRIPT" == 'build_system.sh' ]; then # called by script, for host system
		[ "$HOST_APT_UPDATED" ] || {
			apt-get update
			apt-get upgrade
		}
		HOST_APT_UPDATED=1
	else
		T=`stat -c %Y '/setup/last_apt_update' 2>/dev/null` NOW=`date +%s`
		[ "$T" -a $((NOW-T)) -lt 3600 ] || {
			exec_or_die 'apt-get -q update'
			exec_or_die 'apt-get --yes upgrade'
			exec_or_die 'touch /setup/last_apt_update'
		}
	fi
}
function apt_get_install_chk() {
	ADD_ARGS=$2
	if [ "$SCRIPT" == 'setup.sh' ]; then SYSTEM='chroot'; else SYSTEM='host'; fi
	REQ_PKGS=$1 NUM_PKGS=`echo $REQ_PKGS | wc -w`
	[ "$DEBUG" ] && debug_msg "REQ_PKGS: $REQ_PKGS NUM_PKGS: $NUM_PKGS"
	INSTALLED=`dpkg -l $REQ_PKGS | grep ^ii | wc -l`
	if [ "$INSTALLED" != $NUM_PKGS -o "$ADD_ARGS" == '--reinstall' ]; then
		apt_get_update
		msg "Installing requested packages on $SYSTEM system: $REQ_PKGS"
		exec_or_die "apt-get -q --yes $ADD_ARGS install $REQ_PKGS"
	else
		msg "Requested packages already installed on $SYSTEM system: $REQ_PKGS"
	fi
}
function install_host_dependencies() {
	apt_get_install_chk 'debian-archive-keyring debootstrap parted cryptsetup lsof'
}
function backup_chroot_system() {
	[ "$NO_CHROOT_BACKUP" ] && return
	umount_vfs_chroot
	gmsg "Making backup copy of '$CHROOT_DIR' ($CHROOT_SYSTEM_ARCHIVE)"
	exec_or_die "chroot $CHROOT_DIR apt-get clean"
	exec_or_die "tar czf $CHROOT_SYSTEM_ARCHIVE $CHROOT_DIR"
}
function copy_mmgen_sdist() {
	exec_or_die "rm -f $CHROOT_DIR/setup/$MMGEN_ARCHIVE_NAME"
	exec_or_die "cp -v ../mmgen/dist/$MMGEN_ARCHIVE_NAME $CHROOT_DIR/setup"
}
function copy_mmgen_sdist_usb() {
	DEST="$USB_MNT_DIR/home/$USER/src"
	exec_or_die_print "rm -rf $DEST/*"
	exec_or_die_print "cp ../mmgen/dist/$MMGEN_ARCHIVE_NAME $DEST"
}
function run_setup_chroot() { run_setup_in_chroot $CHROOT_DIR $@; }
function run_setup_usb()    { run_setup_in_chroot $USB_MNT_DIR $@; }
function run_setup_in_chroot() {
	DIR=$1; shift
	mount_vfs $DIR
#	gmsg "Copying setup script to '$DIR'"
	mkdir -p $DIR/setup
	exec_or_die "cp $SCRIPT $DIR/setup/setup.sh"

	echo -e "${GREEN}Entering chroot ==>$RESET setup.sh $@"
	exec_or_die "chroot $DIR /bin/bash ./setup/setup.sh $@"
	echo -e "${GREEN}Leaving chroot$RESET"
}
function live_remove_packages() {
	case "$RELEASE" in
		wily|xenial) A='g++-5 gcc-5 grub-gfxpayload-lists' ;;
		jessie)      A='g++-4.9 g++-4.8 gcc-4.9 gcc-4.8' ;;
		*) die "$RELEASE: unknown release"
	esac
	exec_or_die "apt-get --yes remove build-essential busybox-static colord colord-data fakeroot g++ gcc grub-common grub-efi-amd64-bin grub-pc grub-pc-bin grub2-common gvfs gvfs-backends gvfs-common gvfs-daemons gvfs-libs $A"
# lvm2
	exec_or_die 'apt-get --yes autoremove'
}
function chroot_install_mmgen_dependencies() {

	echo "deb $REPO_URL $RELEASE $REPOS" > /etc/apt/sources.list
	echo "deb $UPDATES_URL $REPOS" >> /etc/apt/sources.list

	chroot_create_system_cfg_files # supported_locales
	apt_get_install_chk 'locales'
	do_gen_locales

	apt_get_install_chk 'gcc make python-pip python-dev python-pexpect python-ecdsa python-scrypt libssl-dev lynx curl git libpcre3-dev python-setuptools python-wheel' '--no-install-recommends'

	gmsg 'Installing the Python Cryptography Toolkit'
	exec_or_die 'pip install pycrypto'
}
function chroot_install_vanitygen() {
	exec_or_die 'cd /setup'
	rm -rf 'vanitygen'
	exec_or_die 'git clone https://github.com/samr7/vanitygen.git'
	exec_or_die '(cd vanitygen; make)'
	gmsg "Copying 'keyconv' executable to execution path"
	exec_or_die 'cp vanitygen/keyconv /usr/local/bin'
}
function copy_user_bitcoind_to_chroot() {
	ARCHIVE=`ls bitcoin*linux*$ARCH_BITS*t*gz 2>/dev/null` && {
		exec_or_die "sudo cp $ARCHIVE $CHROOT_DIR/setup"
		ymsg "Found user-supplied Bitcoin Core archive: $ARCHIVE"
	}
}
function chroot_install_bitcoind() {
	exec_or_die 'cd /setup'
	gmsg 'Retrieving Bitcoin Core'
	URL='https://bitcoin.org/bin/'
	TEXT=`lynx --listonly --nonumbers --dump $URL`
#	TEXT=`cat /setup/bitcoin.org.bin.txt`
	UPATH=`echo "$TEXT"| egrep -i  'http.*bitcoin.*core' | sort -V | tail -n1`
	VER=${UPATH/*-} VER=${VER%/}
	if ARCHIVE=`ls bitcoin*linux*$ARCH_BITS*t*gz 2>/dev/null`; then
		yecho "Found Bitcoin Core archive '$ARCHIVE' in the chroot system"
		VER=${ARCHIVE#*-} VER=${VER%-linux*gz}
		echo "Version is $VER"
	elif echo "$VER" | egrep -q '^[0-9]+\.[0-9]+\.[0-9]+$'; then
#	if false; then
		echo "Latest version is $VER"
		ARCHIVE="bitcoin-$VER-linux${ARCH_BITS}.tar.gz"
		WGET_URL="${UPATH%/}/$ARCHIVE"
		exec_or_die "curl -O $WGET_URL"
	else
		yecho -n "Unable to find latest version of Bitcoin Core"
		yecho " (version number ${VER} doesn't fit pattern)."
		yecho "See: $URL"
		yecho -n "Download the latest Linux $ARCH_BITS-bit gzipped tar archive, place it in"
		yecho " the same directory as this script, and restart the script."
		die
	fi
#	https://bitcoin.org/bin/bitcoin-core-0.12.0/bitcoin-0.12.0-linux64.tar.gz
	gmsg 'Unpacking and installing Bitcoin Core'
	tar xzf $ARCHIVE || {
		rm -f $ARCHIVE
		ymsg 'Archive could not be unpacked, so it was deleted.  Exiting.'; die
	}
	exec_or_die "(cd bitcoin*$VER/bin; cp bitcoind bitcoin-cli /usr/local/bin)"
}
function chroot_install_mmgen() {
	exec_or_die 'cd /setup'
	exec_or_die "tar xzf $MMGEN_ARCHIVE_NAME"
	exec_or_die "(cd ${MMGEN_ARCHIVE_NAME/.tar.gz}; python ./setup.py --quiet install)"
}
function chroot_cleanup_mmgen_builds() {
	exec_or_die 'cd /setup'
	exec_or_die 'rm -rf bitcoin-* mmgen-* pexpect-* vanitygen'
}
function chroot_setup_user() {
	grep -q "^$USER:" /etc/passwd || exec_or_die "useradd -s /bin/bash -m $USER"
	[ -e "/home/$USER" ] || die 'No home directory!'

	ymsg "Setting user password to '$PASSWD'"
	exec_or_die "echo $USER:$PASSWD | chpasswd"
#	exec_or_die "echo root:$PASSWD | chpasswd"  # no root login

	gmsg "Unpacking MMGen repository to user ${USER}'s ~/src directory"
	exec_or_die "chmod 644 /setup/$MMGEN_ARCHIVE_NAME"
	exec_or_die "su - $USER -c 'mkdir -p src; tar -C src -xzf /setup/$MMGEN_ARCHIVE_NAME'"
}
function chroot_test_mmgen() {
	c=1
	while pgrep bitcoind >/dev/null; do
		printf "\rYou must stop your running bitcoind before the script will proceed (%s)" $c
		sleep 1
		let c++
	done

	echo
	gmsg 'Starting bitcoind'
	exec_or_die "su - $USER -c 'bitcoind -daemon -listen=0 -maxconnections=0'"
	gmsg 'Waiting for Bitcoin RPC to become available'
		while ! su - $USER -c 'bitcoin-cli getbalance >/dev/null 2>&1'; do
			sleep 2
		done

	gmsg 'Running the MMGen test suite'
	eval "(su - $USER -c 'cd src/${MMGEN_ARCHIVE_NAME/.tar.gz}; test/test.py -s')" || {
		ymsg 'MMGen test suite failed'
		eval "su - $USER -c 'bitcoin-cli stop'"
		return 73
	}

	gmsg 'Stopping Bitcoind'
	exec_or_die "su - $USER -c 'bitcoin-cli stop'"
}

function cf_append()    { cf_write "$@"; }
function cf_uncomment() { cf_write "$@"; }
function cf_edit()      { cf_write "$@"; }
function cf_write() {
	ACTION='write'
	echo -n "${FUNCNAME[1]}" | egrep -q '^(cf_uncomment|cf_append|cf_edit)$' && ACTION=${FUNCNAME[1]/cf_}

	CF_HDR=
	if [ $1 == 'do_hdr' ]; then
		if [ "$ACTION" == 'write' ]; then M1="\n### Generated"; else M1=' edited'; fi
		CF_HDR="### ${CFG_NAMES[$2]}$M1 by $PROJ_NAME/$PROGNAME\n"
		shift
	fi

#	echo $ACTION $1 $CF_HDR; return
	ID=$1 TEXT=$2 REPL=$3
	gecho "${CFG_NAMES[$ID]} $YELLOW($ACTION)$RESET"
	if [ "$DEBUG" ]; then OUT='/dev/tty'; else OUT=${OF[$ID]}; fi
	if [ "$ACTION" == 'append' ]; then
		NLINES=`echo -e "$CF_HDR$TEXT" | wc -l`
		A="`tail -n$NLINES ${OF[$ID]}`"
		B=`echo -e "$CF_HDR$TEXT"`
		[ "$A" == "$B" ] || exec_or_die 'echo -e "$CF_HDR$TEXT" >> $OUT'
	elif [ "$ACTION" == 'uncomment' ]; then
		PAT='^#\s*'${TEXT// /\\s*}'\s*'
		sed "s/$PAT/$TEXT/" ${OF[$ID]} > /tmp/sed.out
		exec_or_die 'cat /tmp/sed.out > $OUT'
	elif [ "$ACTION" == 'edit' ]; then
		sed "s/$TEXT/${REPL//\//\\/}/" ${OF[$ID]} > /tmp/sed.out
		exec_or_die 'cat /tmp/sed.out > $OUT'
	else
		[ "$OUT" != '/dev/tty' ] && exec_or_die "mkdir -p `dirname $OUT`"
		exec_or_die 'echo -e "$CF_HDR$TEXT" > $OUT'
	fi
}
declare -A CFG_NAMES=(
	[etc_fstab]='/etc/fstab'
	[etc_hostname]='/etc/hostname'
	[etc_hosts]='/etc/hosts'
	[etc_resolvconf]='/etc/resolv.conf'
	[console_setup]='/etc/default/console-setup'
	[dfl_locale]='/etc/default/locale'
	[dfl_grub]='/etc/default/grub'
	[rc_local]='/etc/rc.local'
	[supported_locales]='/var/lib/locales/supported.d/SUPPORTED'
	[initrd_cryptsetup]='/etc/initramfs-tools/conf.d/cryptsetup'
	[etc_groups]='/etc/groups'
	[pam_su]='/etc/pam.d/su'
	[etc_sudoers]='/etc/sudoers'
	[lxdm_conf]='/etc/lxdm/lxdm.conf'
	[lightdm_conf]='/etc/lightdm/lightdm.conf'
	[lightdm_greeter_conf]='/etc/lightdm/lightdm-gtk-greeter.conf'
)
[ "$RELEASE" == 'jessie' ] && {
	CFG_NAMES[supported_locales]='/etc/locale.gen'
}
function chroot_create_system_cfg_files() {
	declare -A OF
	for i in ${!CFG_NAMES[*]}; do OF[$i]=${CFG_NAMES[$i]}; done
	cf_write 'do_hdr' 'supported_locales' '
en_US.UTF-8 UTF-8
en_US ISO-8859-1
en_US.ISO-8859-15 ISO-8859-15'
}
function usb_create_system_cfg_files() {
	depends 'location=usb' mount_root && return

	declare -A OF
	for i in ${!CFG_NAMES[*]}; do OF[$i]=$USB_MNT_DIR${CFG_NAMES[$i]}; done

	BOOT_UUID=`lsblk -no UUID $USB_P1`
	[ "$BOOT_UUID" ] || die 'Missing boot filesystem UUID'

	cf_write 'do_hdr' 'etc_resolvconf' '# nameserver 127.0.0.1'

	cf_write 'do_hdr' 'etc_fstab' "
/dev/mapper/$DM_ROOT_DEV /        ext4     errors=remount-ro 0 1
UUID=$BOOT_UUID          /boot    vfat     errors=remount-ro 0 2
# proc                     /proc    proc     defaults 0 0
# sysfs                    /sys     sysfs    defaults 0 0
# udev                     /dev     devtmpfs defaults 0 0
# devpts                   /dev/pts devpts   defaults 0 0"

	cf_write 'etc_hostname' "$HOST"

	cf_edit 'etc_hosts' '^127.0.0.1\s\+localhost.*' "127.0.0.1       localhost $HOST"

	cf_write 'do_hdr' 'console_setup' "
# CONFIGURATION FILE FOR SETUPCON
# Consult the console-setup(5) manual page.
ACTIVE_CONSOLES='/dev/tty[1-6]'
CHARMAP='UTF-8'
CODESET='guess'
FONTFACE='Fixed'
FONTSIZE='12x24'
VIDEOMODE=
FONT='/etc/console-setup/mmgen-24.psfu'"

	cf_write 'dfl_locale' 'LANG="en_US.UTF-8"'

	cf_write 'do_hdr' 'dfl_grub' '
GRUB_BACKGROUND="/boot/grub/backgrounds/dark-blue.tga"
GRUB_DEFAULT=0
GRUB_HIDDEN_TIMEOUT_QUIET=true
GRUB_TIMEOUT=-1
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
GRUB_TERMINAL=gfxterm
GRUB_GFXMODE=640x480
GRUB_ENABLE_CRYPTODISK="y"'

	cf_write 'do_hdr' 'initrd_cryptsetup' 'export CRYPTSETUP=y'

	cf_edit 'do_hdr' 'rc_local' '^exit 0\s*$' '# exit 0' # won't touch our 'exit 0' below
	cf_append 'do_hdr' 'rc_local' 'echo "Disabling network services, wifi and bluetooth"
rfkill block wifi
rfkill block bluetooth
/etc/init.d/xl2tpd stop
exit 0 # MMGen'

	cf_append 'do_hdr' 'etc_sudoers' "$USER ALL = NOPASSWD: ALL"

	cf_uncomment 'do_hdr' 'pam_su' 'auth sufficient pam_wheel.so trust'

	msg "Adding user '$USER' to the 'wheel' group"
	exec_or_die "chroot $USB_MNT_DIR groupadd -f -g 14 wheel"
	exec_or_die "chroot $USB_MNT_DIR usermod -a -G wheel $USER"

	[ "$DO_INSTALL_X" ] && {
		BG='/usr/share/images/mmgen/login-background.png'
		case "$RELEASE" in
			wily|xenial)
				STARTX='/usr/bin/startxfce4'
				cf_edit 'do_hdr' 'lxdm_conf' '^#\s*autologin=.*' "autologin=$USER"
				cf_edit 'do_hdr' 'lxdm_conf' '^session=.*'       "session=$STARTX"
				cf_edit 'do_hdr' 'lxdm_conf' '^#\s*session=.*'   "session=$STARTX"
				cf_edit 'do_hdr' 'lxdm_conf' '^bg=.*'            "bg=$BG"
				;;
			jessie)
				cf_edit 'do_hdr' 'lightdm_conf' '^\(autologin-.*\)$' '# \1'
				cf_edit 'do_hdr' 'lightdm_conf' \
						'^\(\[SeatDefaults\]\)\s*$' \
						'\1\nautologin-user='$USER'\nautologin-user-timeout=0'
				cf_edit 'do_hdr' 'lightdm_greeter_conf' '^background=.*$' "background=$BG"
				;;
			*) die "$RELEASE: unknown release"
		esac
	}
	return 0
}

function inform()               { gmsg "TO DO: ${DESCS[$1]}"; eval $1; }
function do_gen_locales()       { exec_or_die 'locale-gen'; }

function install_mmgen_dependencies() {
	depends 'location=chroot' restore_apt_archives restore_apt_lists && return
	chroot_install $FUNCNAME
}
function install_vanitygen() {
	depends 'location=chroot' && return
	chroot_install $FUNCNAME
}
function setup_user() {
	depends 'location=chroot' && return
	chroot_install $FUNCNAME
}
function install_bitcoind() {
	depends 'location=chroot' copy_user_bitcoind_to_chroot && return
	chroot_install $FUNCNAME 'INFORM=1'
}
function install_mmgen() {
	dbecho "==> $FUNCNAME($@)"
	depends 'location=chroot' build_mmgen_sdist copy_mmgen_sdist && return
	chroot_install $FUNCNAME 'INFORM=1'
}
function test_mmgen() {
	depends 'location=chroot' && return
	[ "$SKIP_MMGEN_TEST" ] && return 73
	chroot_install $FUNCNAME
}
function cleanup_mmgen_builds() {
	depends 'location=none' && return
	chroot_install $FUNCNAME
}
function chroot_install() { FUNC=$1; shift; run_setup_chroot $OPTS chroot_$FUNC $@; }

function setup_loop() {
	if [ -e $LOOP_FILE ]; then
		S=$((`du -b $LOOP_FILE | sed 's/\s.*//'` / 1024 / 1024))
		if [ "$S" != $LOOP_SIZE ]; then
			msg "Loop file had incorrect size (${S}M)...deleting"
			exec_or_die 'L=`losetup -O NAME -lnj $LOOP_FILE`'
			exec_or_die '[ "$L" ] && losetup -d $L'
			exec_or_die "rm $LOOP_FILE"
		fi
	fi
	if [ ! -e $LOOP_FILE ]; then
		msg -n "Creating loop file '$LOOP_FILE' (size: ${LOOP_SIZE}M)..."
		exec_or_die "dd if=/dev/zero of=$LOOP_FILE bs=1M count=$LOOP_SIZE 2>/dev/null"
		echo 'done'
	fi
	exec_or_die 'LOOP_DEV=`losetup -O NAME -lnj $LOOP_FILE`'
	if [ ! "$LOOP_DEV" ]; then
		msg "Associating file '$LOOP_FILE' with loop device '$LOOP_DEV'"
		exec_or_die 'LOOP_DEV=`losetup -f`'
		exec_or_die "losetup $LOOP_DEV $LOOP_FILE"
	else
		msg "File '$LOOP_FILE' already associated with loop device '$LOOP_DEV'"
	fi
	USB_DEV=$LOOP_DEV USB_DEV_TYPE='loop' USB_DEV_DESC=${USB_DEV_DESCS[loop]}
	USB_P1=${LOOP_DEV}p1 USB_P2=${LOOP_DEV}p2
}
function get_usb_dev() {
	[ "$USB_DEV_DESC" -a "$USB_P1" -a "$USB_P2" ] && return # no need to run this twice
	gmsg 'Checking for USB drive'
	if [ "$USB_DEV" ]; then # for debugging
		msg 'WARNING: The following USB device has been set MANUALLY!:'
	else
		M1='Insert a USB drive.'
		M2='If the device is already inserted, remove it and re-insert'
		msg "$M1 $M2"
		while sleep 2; do
			echo -n .
			LS_SAVE=$LS
			LS=`echo /dev/sd*`
			if [ "$LS_SAVE" -a "${#LS}" -gt "${#LS_SAVE}" ]; then
				USB_DEV=(${LS#$LS_SAVE})
				break
			fi
		done
		echo
		if [ ! "$USB_DEV" ]; then die 'No USB device was found!'; fi
		msg 'The following device appears to have been inserted:'
	fi

	exec_or_die "parted $USB_DEV unit GB print | head -n2"
	msg -n 'Is this correct?  ENTER to continue, Ctrl-C to abort: '; read
	USB_DEV_TYPE='usb' USB_DEV_DESC=${USB_DEV_DESCS[usb]}
	USB_P1=${USB_DEV}1 USB_P2=${USB_DEV}2
}
function partition_usb_root() {
	depends 'location=usb' partition_usb_boot && return
	umount_vfs_chroot; umount_vfs_usb; umount_boot_usb; umount_root
	partition_usb
}
function partition_usb_boot() {
	dbecho "==> $FUNCNAME($@)"
	depends 'location=chroot' mount_vfs_chroot && return
	partition_usb
}
function partition_usb() {
	TYPE=${FUNCNAME[1]#${FUNCNAME}_}
	get_target_dev
	gmsg "Creating $TYPE partition on $USB_DEV_DESC ($USB_DEV)"

	ROOTFS_SIZE=(`du -sm $CHROOT_DIR 2>/dev/null`)
	# 4MB alignment for cheap drives - see 'info parted - mkpart'
	ROOTFS_SIZE=$((ROOTFS_SIZE+4-(ROOTFS_SIZE%4)))
#	msg "Root FS size: $ROOTFS_SIZE"
	DEV_SIZE=`parted $USB_DEV unit MiB print 2>/dev/null | grep ^Disk | sed 's/.* //' | sed 's/MiB$//'`
	TOTAL_SIZE=$((BS_SIZE+BOOTFS_SIZE+ROOTFS_SIZE+PAD_SIZE))
	if [ "$LOOP_INSTALL" ]; then
		TOTAL_SIZE=$DEV_SIZE
		ROOTPART_SIZE=$((TOTAL_SIZE-BOOTFS_SIZE-BS_SIZE))
	else
		ROOTPART_SIZE=$((ROOTFS_SIZE+PAD_SIZE))
	fi

	msg 'Sizes:'
	echo "              device:           $DEV_SIZE MiB"
	echo "              boot sector:      $BS_SIZE MiB"
	echo "              boot partition:   $BOOTFS_SIZE MiB"
	echo "              root filesystem:  $ROOTFS_SIZE MiB"
	echo "              root partition:   $ROOTPART_SIZE MiB"
	if [ ! "$LOOP_INSTALL" ]; then
		echo "              extra partition:  $((DEV_SIZE-TOTAL_SIZE)) MiB"
	fi

	if [ $DEV_SIZE -lt $TOTAL_SIZE ]; then die 'Device is too small'; fi

	msg -n "Continue? (Y/n): "; read; if [ "$REPLY" == 'n' ]; then clean_exit; fi

# BEGIN DESTRUCTIVE ACTIONS
	DD="dd if=/dev/zero of=$USB_DEV bs=1M"

	if [ "$TYPE" == 'boot' ]; then
		msg 'Blanking boot sector'
		COUNT=$BS_SIZE
		echo -n "              boot sector ($COUNT MiB)..."
		exec_or_die "$DD count=$COUNT 2>/dev/null"
		echo 'done'
		if [ "$DO_BLANK" ]; then
			msg 'Blanking boot partition'
			COUNT=$((BS_SIZE+BOOTFS_SIZE))
			echo -n "              boot partition ($COUNT MiB)..."
			exec_or_die "$DD count=$COUNT 2>/dev/null"
			echo 'done'
		fi
	elif [ "$TYPE" == 'root' ]; then
		if [ "$DO_BLANK" ]; then
			msg 'Blanking root partition (be patient, this could take awhile)'
			COUNT=$ROOTPART_SIZE
			echo "              root partition ($COUNT MiB)..."
			exec_or_die "$DD count=$COUNT seek=$((BS_SIZE+BOOTFS_SIZE))"
			echo 'done'
		fi
	fi

	[ "$DO_BLANK" ] && exec_or_die 'sync; sleep 5; sync'

	msg 'Partitioning:'

	if [ "$TYPE" == 'boot' ]; then
		echo -n '              disk label (partition table)...'
		exec_or_die "parted -s $USB_DEV mklabel msdos"
		echo 'done'
		echo -n '              boot partition...'
		exec_or_die "parted -s $USB_DEV mkpart primary fat32 ${BS_SIZE}MiB $((BS_SIZE+BOOTFS_SIZE))MiB"
		exec_or_die "parted -s $USB_DEV set 1 boot on"
		if [ "$LOOP_INSTALL" ]; then FD_SUF='|| true'; fi
		exec_or_die "echo -ne 't\nef\nw\nq\n' | LANG=C sudo fdisk $USB_DEV >/dev/null 2>&1$FD_SUF"
		exec_or_die "partprobe $USB_DEV"
		echo 'done'
	elif [ "$TYPE" == 'root' ]; then
		echo -n '              root partition...'
		exec_or_die "parted -s $USB_DEV rm 3 2>/dev/null || true"
		exec_or_die "parted -s $USB_DEV rm 2 2>/dev/null || true"
		exec_or_die "parted -s $USB_DEV mkpart primary ext4 $((BS_SIZE+BOOTFS_SIZE))MiB ${ROOTPART_SIZE}MiB"
		echo 'done'
		if [ ! "$LOOP_INSTALL" ]; then
			echo -n '              extra partition...'
			exec_or_die "parted -s $USB_DEV -- mkpart primary ext4 ${TOTAL_SIZE}MiB -1s"
			echo 'done'
		fi
	fi
	mkfs_usb_drive $TYPE
	return 0
}

function open_luks_partition() {
	msg "Opening LUKS partition '$2'"
	exec_or_die "echo $PASSWD | cryptsetup luksOpen $1 $2"
}
function close_luks_partition() {
	if cryptsetup status $1 >/dev/null; then
		msg "Closing LUKS partition '$1'"
		exec_or_die "cryptsetup luksClose $1"
	fi
}
function mkfs_usb_drive() {
	[ "$1" ] || die; TYPE=$1

	exec_or_die 'sleep 3'

	gmsg "Setting up $TYPE filesystem on $USB_DEV_DESC"
	if [ ! "$USB_DEV" ]; then die 'No USB device configured!'; fi

	if [ "$TYPE" == 'root' ]; then
		close_luks_partition $DM_DEV
		msg -e "Formatting LUKS partition $YELLOW(password is '$PASSWD')$RESET"
		exec_or_die "echo -n $PASSWD | cryptsetup luksFormat $USB_P2 -"
		open_luks_partition $USB_P2 $DM_DEV
	fi

	msg 'Creating filesystem:'

	if [ "$TYPE" == 'boot' ]; then
		echo -n '              boot partition (vfat)...'
		exec_or_die "mkfs.fat -F32 -n $BOOTFS_LABEL $USB_P1 2>/dev/null"
		echo 'done'
	elif [ "$TYPE" == 'root' ]; then
		echo -n '              root partition (ext4)...'
		exec_or_die "mkfs.ext4 -q -L $ROOTFS_LABEL /dev/mapper/$DM_DEV"
		echo 'done'
		exec_or_die "sleep 1"

		# Mount, and leave mounted, so check_done() can write timestamp file!
		mount_root
#		close_luks_partition $DM_DEV
	fi
}
function usb_copy_system() {
	depends 'location=usb' build_live_system partition_usb_root && return
	umount_vfs_chroot
	mount_root
	exec_or_die "mountpoint -q $USB_MNT_DIR"

	if [ -e $USB_MNT_DIR/usr/local/bin ]; then
		msg -n "A system already exists on '$USB_MNT_DIR'.  Overwrite? (y/N): "; read
		if [ "$REPLY" != 'y' ]; then return; fi
	fi
	# save before clobbering
	exec_or_die "cp -f $USB_MNT_DIR/setup/progress/* $CHROOT_DIR/setup/progress"
	exec_or_die "rm -rf $USB_MNT_DIR/*"
	msg 'Copying root filesystem to LUKS partition'
	exec_or_die "for i in $CHROOT_DIR/*; do echo copying \$i; cp -a \$i $USB_MNT_DIR; done"
}
function backup_apt_archives() {
	[ "$NO_APT_BACKUP" ] && return
	[ "`ls $APT_ARCHIVE_DIR`" ] || { msg "'$APT_ARCHIVE_DIR' empty, nothing to back up"; return; }
	gmsg "Backing up '$APT_ARCHIVE_DIR'"
	exec_or_die "tar -C $APT_ARCHIVE_DIR -cf $APT_ARCHIVE ."
	exec_or_die "rm -r $APT_ARCHIVE_DIR/*"
}
function restore_apt_archives() {
	[ "`ls $APT_ARCHIVE_DIR`" ] && return
	[ "$NO_APT_BACKUP" ] && return
	[ -e "$APT_ARCHIVE" ] && {
		gmsg "Restoring '$APT_ARCHIVE_DIR'"
		exec_or_die "tar -C $APT_ARCHIVE_DIR -xf $APT_ARCHIVE"
	}
}
function backup_apt_lists() {
	[ "$NO_APT_LISTS_BACKUP" ] && return
	[ "`ls $APT_LISTS_DIR/*`" ] || { msg "'$APT_LISTS_DIR' empty, nothing to back up"; return; }
	gmsg "Backing up '$APT_LISTS_DIR'"
	exec_or_die "tar -C $APT_LISTS_DIR -cf $APT_LISTS_ARCHIVE ."
	exec_or_die "rm -r $APT_LISTS_DIR/*"
	exec_or_die "mkdir -p $APT_LISTS_DIR/partial"
}
function restore_apt_lists() {
	[ "`ls $APT_LISTS_DIR/*`" ] && return
	[ "$NO_APT_LISTS_BACKUP" ] && return
	[ -e "$APT_LISTS_ARCHIVE" ] && {
		gmsg "Restoring '$APT_LISTS_DIR'"
		exec_or_die "tar -C $APT_LISTS_DIR -xf $APT_LISTS_ARCHIVE"
	}
}

function live_install_grub() {
	echo 'APT { Architecture "amd64"; };' > /etc/apt/apt.conf
	MNT_DIR='/boot'
	gmsg "Installing GRUB on $USB_DEV_DESC"
	apt_get_install_chk 'grub2-common'

	exec_or_die 'apt-get -q --yes remove grub-pc-bin'
	apt_get_install_chk 'grub-efi-amd64-bin'
	exec_or_die "mkdir -p $MNT_DIR/EFI"

	gmsg "Installing GRUB (EFI) on boot partition '$MNT_DIR'"
	exec_or_die "grub-install --skip-fs-probe --boot-directory=$MNT_DIR --efi-directory=$MNT_DIR --removable"

	exec_or_die 'apt-get -q --yes remove grub-efi-amd64-bin'
	apt_get_install_chk 'grub-pc-bin'

	gmsg "Installing GRUB (BIOS/MBR) on boot partition '$MNT_DIR'"
	exec_or_die "grub-install --skip-fs-probe --boot-directory=$MNT_DIR $USB_DEV"
}

function live_install_kernel() {
	case $RELEASE in
		wily|xenial)   PKG='linux-image-generic' ;;
		jessie) PKG="linux-image-$ARCH" ;;
		*) die "$RELEASE: unknown release"
	esac
	bmsg "NOTE: the package installer may present you with a list of devices for GRUB to be installed on.  Leave all the items in the list unchecked and select 'OK'.  In the following dialog box, answer 'Yes' to the question 'Continue installing without GRUB?'"
	pause
	exec_or_die "PKG2=`apt-cache depends $PKG | head -n2 | tail -n1 | sed 's/.* //'`"
	apt_get_update
	# /boot might have been reformatted/deleted, but apt doesn't know
	exec_or_die "apt-get --yes purge $PKG $PKG2"
	exec_or_die "apt-get --yes --reinstall install $PKG"
	apt_get_install_chk "cryptsetup"
}

function live_install_system_utils() {
	apt_get_install_chk 'ethtool dosfstools parted gdisk wipe lsof fbset man rfkill nano tmux vim sudo openssh-client rsync ppp network-manager-pptp iputils-arping xl2tpd tor' '--no-install-recommends'
}

function live_install_x() {
	[ "$DO_INSTALL_X" ] || return 73
	case "$RELEASE" in
		wily|xenial) A='plymouth-theme-lubuntu-text plymouth-theme-lubuntu-logo lxdm' ;;
		jessie)      A='plymouth-themes plymouth-x11 lightdm' ;;
		*) die "$RELEASE: unknown release"
	esac
	apt_get_install_chk "xserver-xorg x11-xserver-utils xinit xfce4 xfce4-notifyd xscreensaver desktop-base tango-icon-theme rxvt-unicode-256color fonts-dejavu network-manager-gnome vim-gtk crystalcursors xcursor-themes $A" '--no-install-recommends'
}
function usb_install_extras_tty() {
	depends 'location=usb' mount_root && return
	[ "$DO_INSTALL_EXTRAS_TTY" ] || return 73
	check_extras_tty_present
	exec_or_die "tar -C $USB_MNT_DIR -xzf $EXTRAS_TTY_ARCHIVE"
}
function usb_install_extras_gfx() {
	depends 'location=usb' mount_root mount_boot_usb && return
	[ "$DO_INSTALL_EXTRAS_GFX" ] || return 73
	check_extras_gfx_present
	mount_boot_usb
	[ "$RELEASE" == 'wily' ] && {
		LOGO_FILE="$USB_MNT_DIR/lib/plymouth/themes/lubuntu-logo/lubuntu_logo.png"
		exec_or_die "mv $LOGO_FILE ${LOGO_FILE}.orig"
	}
	[ "$RELEASE" == 'jessie' ] || {
		LOGIN_IMG="$USB_MNT_DIR/usr/share/lxdm/themes/Industrial/login.png"
		exec_or_die "mv $LOGIN_IMG ${LOGIN_IMG}.orig"
	}
	BG_DIR="$USB_MNT_DIR/usr/share/backgrounds/xfce"
	exec_or_die "rm -f $BG_DIR/*"
	exec_or_die "tar -C $USB_MNT_DIR -xzf $EXTRAS_GFX_ARCHIVE"
}
function usb_create_grub_cfg_file() {
	# unmount, then mount, otherwise root UUID might be incorrect
	depends 'location=usb_boot' umount_all mount_root mount_boot_usb && return
	BOOT_UUID=`lsblk -no UUID $USB_P1`
	ROOT_UUID=`lsblk -no UUID $USB_P2 | head -n1`
	VMLINUZ=`basename $USB_MNT_DIR/boot/vmlinuz*`
	INITRD=`basename $USB_MNT_DIR/boot/initrd*`
	[ "$BOOT_UUID" -a "$ROOT_UUID" ] || die 'Missing UUID'
	[ "$VMLINUZ" -a "$INITRD" ] || die 'Missing kernel or initrd'

	if [ "$SIMULATE" ]; then OF='/dev/tty'; else OF="$USB_MNT_DIR/boot/grub/grub.cfg"; fi
	TEXT="### grub.cfg generated by $PROJ_NAME

function load_video {
	if [ \"\$feature_all_video_module\" = \"y\" ]; then
		insmod all_video
	else
		insmod efi_gop
		insmod efi_uga
		insmod ieee1275_fb
		insmod vbe
		insmod vga
		insmod video_bochs
		insmod video_cirrus
	fi
}

insmod part_msdos
insmod ext2
insmod fat
insmod cryptodisk
insmod luks
insmod gcry_rijndael
insmod gcry_sha1
insmod gfxterm
insmod gettext
insmod gzio

load_env
loadfont unicode
set gfxmode='640x480'
load_video
terminal_input gfxterm
terminal_output gfxterm

search --no-floppy --fs-uuid --set=root $BOOT_UUID
set rootfs_dev='/dev/disk/by-uuid/$ROOT_UUID'

insmod tga
background_image /grub/backgrounds/dark-blue.tga

set passwd_info='disk password: $PASSWD'
set kver='${VMLINUZ/vmlinuz-}'
set classinfo='--class ubuntu --class gnu-linux --class gnu --class os'
set kcryptoargs=\"root=/dev/mapper/$DM_ROOT_DEV cryptopts=source=\${rootfs_dev},target=$DM_ROOT_DEV rootfstype=ext4\"
set kargs_gfx='ro quiet splash'
set kargs_console='ro text'
set desc=\"$PROJ_NAME ${RELEASES[$RELEASE]}\" # release desc contains single quotes!

menuentry \"\${desc} \${passwd_info}\" \${classinfo} {
	echo \"Loading vmlinuz-\${kver}...\"
	linux /vmlinuz-\${kver} \${kcryptoargs} \${kargs_gfx}
	echo \"Loading initrd.img-\${kver}...\"
	initrd /initrd.img-\${kver}
}"
# menuentry \"\${desc} (console boot) \${passwd_info}\" \${classinfo} {
# menuentry \"\${desc} (graphical boot) \${passwd_info}\" \${classinfo} {
# 	echo \"Loading vmlinuz-\${kver}...\"
# 	linux /vmlinuz-\${kver} \${kcryptoargs} \${kargs_gfx}
# 	echo \"Loading initrd.img-\${kver}...\"
# 	initrd /initrd.img-\${kver}
# }
	[ "$VERBOSE" ] && echo "$TEXT"
	echo "$TEXT" > "$USB_MNT_DIR/boot/grub/grub.cfg"
	echo "$TEXT" > "$USB_MNT_DIR/boot/grub/grub.cfg.bak"
}
function usb_pre_initramfs() {
	depends 'location=usb' mount_root mount_boot_usb && return; usb_install $FUNCNAME
}
function usb_update_initramfs() {
	depends 'location=usb_boot' mount_root mount_boot_usb && return; usb_install $FUNCNAME
}
function usb_gen_locales() {
	depends 'location=usb' mount_root && return; usb_install $FUNCNAME
}
function usb_config_misc() {
	depends 'location=usb' mount_root && return; usb_install $FUNCNAME
}
function usb_update_mmgen() {
	build_mmgen_sdist
	mount_root
	copy_mmgen_sdist_usb
	usb_install $FUNCNAME
}
function usb_install() {
	ARGS="RELEASE=$RELEASE USB_DEV=$USB_DEV USB_P1=$USB_P1 USB_P2=$USB_P2 USB_DEV_TYPE=$USB_DEV_TYPE"
	run_setup_usb $OPTS setup_sh_$1 $ARGS
}


function check_extras_tty_present() {
	if [ ! -e $EXTRAS_TTY_ARCHIVE -a "$DO_INSTALL_EXTRAS_TTY" ]; then
		M1="The archive '$EXTRAS_TTY_ARCHIVE' is missing. You must obtain the file from the"
		M2="$PROJ_NAME boot images repository and copy it to the build directory."
		M3="Alternatively, you may disable console extras with the '-U' option,"
		M4="but this will leave you with a less than fully-functional system."
		echo -e "$M1 $M2\n$M3 $M4"; exit
	else
		msg "--- Console extras archive present: $EXTRAS_TTY_ARCHIVE"
	fi
}
function check_extras_gfx_present() {
	if [ ! -e $EXTRAS_GFX_ARCHIVE -a "$DO_INSTALL_X" -a "$DO_INSTALL_EXTRAS_GFX" ]; then
		M1="X Window system and graphics extras are requested for installation but the"
		M2="'$EXTRAS_GFX_ARCHIVE' archive is missing. You must obtain the file from the"
		M3="$PROJ_NAME boot images repository and copy it to the build directory."
		M5="Alternatively, you may disable graphics extras with the '-T' option,"
		M6="but this will leave you with a less than fully-functional system."
		echo -e "$M1 $M2 $M3\n$M4 $M5"; exit
	else
		msg "--- Graphics extras archive present: $EXTRAS_GFX_ARCHIVE"
	fi
}

function setup_sh_usb_update_mmgen() {
	DEST="/home/$USER/src"
	exec_or_die_print "chown $USER.$USER $DEST/*"
	exec_or_die_print "(cd $DEST; su $USER -c 'tar xf $MMGEN_ARCHIVE_NAME')"
	exec_or_die_print "rm $DEST/$MMGEN_ARCHIVE_NAME"
	exec_or_die_print "(cd $DEST/${MMGEN_ARCHIVE_NAME/.tar.gz}; python ./setup.py --quiet install)"
}
function setup_sh_usb_config_misc() {
	exec_or_die 'systemctl disable NetworkManager'
	exec_or_die 'systemctl disable wpa_supplicant'
	exec_or_die 'systemctl disable tor'
	[ "$RELEASE" != 'xenial' ] && exec_or_die 'systemctl disable bluetooth'
#	exec_or_die 'systemctl disable lvm2'
}
function setup_sh_usb_gen_locales() {
	exec_or_die 'locale-gen'
}
function setup_sh_usb_pre_initramfs() {
	[ "$RELEASE" == 'jessie' ] && {
		A='glow'
		gmsg "Setting default plymouth theme to '$A'"
		exec_or_die "plymouth-set-default-theme $A"
	}
}
function setup_sh_usb_update_initramfs() {
	export CRYPTSETUP=y
	gmsg 'Generating initramfs'
	KVER=`ls boot | grep vmlinuz | sed 's/vmlinuz-//'`
	if [ "$KVER" ]; then
		[ "$RELEASE" == 'jessie' ] && ARG='-t'
		msg "Found kernel version '$KVER'"
		exec_or_die "update-initramfs -k $KVER -d"
		exec_or_die "update-initramfs $ARG -k $KVER -c"
	else
		die 'No kernel found!'
	fi
}
function umount_all () {
	umount_boot_chroot
	umount_vfs_chroot
	umount_boot_usb
	umount_vfs_usb
	umount_root
	sync; sync; sleep 1
	HUSH_EXIT=1
}
function inf2tense() {
	TENSE=$1; shift
	local A=$*
	local PAIRS
	if [ "$TENSE" == 'past' ]; then
		PAIRS=(
			'delete deleted' 'keep kept' 'ack acked' 'build built'
			'stall stalled' 'ount ounted' 'test tested'
			'configure configured' 'copy copied' 'create created' 'store stored'
			'set set' 'enerate enerated'
		)
	elif [ "$TENSE" == 'gerund' ]; then
		PAIRS=(
			'e ing' 'k king' 'ld lding' 'll lling'
			'et etting' 'st sting' 'nt nting' 'y ying' 'p ping'
		)
	fi
	for p in "${PAIRS[@]}"; do
		A=`echo $A | sed -r "s/(^| but |; )([a-z]*)${p/ *}\>/\1\2${p/* }/g"`
	done
	echo ${A^}
}

function check_done () {
# 	recho "check_done(`eval echo $@`)"
	local FUNC location PDIR
	FUNC=$1
	eval "$2" # 'location=xxx'
	[ "$SHOW_DEPENDS" ] && { recho "$FUNCNAME: func:$FUNC, location:$location"; }
	case $location in usb|*_boot) get_target_dev ;; esac
	case $location in
		chroot)			PDIR="$CHROOT_DIR/setup/progress"; mount_vfs_chroot ;;
		usb)	  		[ -e "$USB_P2" ] && mount_root
						PDIR="$USB_MNT_DIR/setup/progress" ;;
		chroot_boot)	[ -e "$USB_P1" ] && mount_boot_chroot
						PDIR="$CHROOT_DIR/boot/progress" ;;
		usb_boot)		[ -e "$USB_P1" ] && mount_boot_usb
						PDIR="$USB_MNT_DIR/boot/progress" ;;
		none)			PDIR='none' ;;
		*) die "$location: unrecognized location" ;;
	esac
	[ "$SHOW_DEPENDS" ] && {
		recho "$FUNCNAME: func:$FUNC, location:$location, pdir:$PDIR, p1:$USB_P1"
	}

	if [ ! -e "$PDIR/$FUNC" -o "$TARGET" == "$FUNC" -o "$PDIR" == 'none' ]; then
		[ -e "$PDIR/$FUNC" ] && {
			msg -n "Target '$FUNC' already built.  Are you sure you want to proceed?"
			echo -n " (y/N) "; read; [ "${REPLY,}" == 'y' ] || return 73
		}
		gmsg "TO DO: ${DESCS[$FUNC]}"
		CMD=$FUNC
#		[ "$SHOW_DEPENDS" ] && CMD='recho "$FUNCNAME: would execute: $FUNC"'
		[ "$SHOW_DEPENDS" ] && recho "$FUNCNAME: executing: $FUNC"
 		if eval "$CMD"; then
			gmsg "`inf2tense 'past' ${DESCS[$FUNC]}`"
			[ "$PDIR" == 'none' ] && return
 			exec_or_die "mkdir -p $PDIR"
 			exec_or_die "touch $PDIR/$FUNC"
		elif [ "$?" == 73 ]; then
			echo '...skipped at user request'
		else
			die "Function '$FUNC' failed"
		fi
	else
		msg -e "--- ${DESCS[$FUNC]} - ${GREEN}done$RESET"
#		echo '...already done'
	fi
}
function usbimg2file () {
	get_usb_dev
	IMG_FILE='img.out.gz'
	M=$((1024*1024))
	BP_SIZE=`sudo lsblk -nb -o SIZE $USB_P1`
	RP_SIZE=`sudo lsblk -nb -o SIZE $USB_P2`
	for i in 'BP_SIZE' 'RP_SIZE'; do
		val=${!i} rem=$((val%(4*M)))
		if [ "$rem" -ne 0 ]; then die "$i size ($val) is not a multiple of 4M!"; fi
		eval "$i=$((val/M))"
	done

	TOTAL_SIZE=$((BS_SIZE+BP_SIZE+RP_SIZE))

	msg 'Sizes:'
	echo "              boot sector:      $BS_SIZE MiB"
	echo "              boot partition:   $BP_SIZE MiB"
	echo "              root partition:   $RP_SIZE MiB"
	echo "              total:            $TOTAL_SIZE MiB"
	msg "Copying and gzip compressing $TOTAL_SIZE MiB from '$USB_DEV' to file '$IMG_FILE'"
	msg -n "Continue? (Y/n): "; read; if [ "$REPLY" == 'n' ]; then clean_exit; fi
	msg 'Copying (be patient, this could take awhile)...'

	dd if=$USB_DEV bs=1M count=$TOTAL_SIZE | gzip > $IMG_FILE
}
function depclean() {
	depends 'location=none' mount_root mount_boot_usb && return
	CMD="rm -f $USB_MNT_DIR/setup/progress/*"
	echo $CMD; exec_or_die "$CMD"
	CMD="rm -f $USB_MNT_DIR/boot/progress/*"
	echo $CMD; exec_or_die "$CMD"
	CMD="rm -f $CHROOT_DIR/setup/progress/*"
	echo $CMD; exec_or_die "$CMD"
	umount_all
}
function clean() {
	depends 'location=none' depclean && return
	CMD="rm -rf $CHROOT_DIR"
	echo $CMD; exec_or_die "$CMD"
}
function distclean() {
	depends 'location=none' depclean && return
	CMD="rm -rf $CHROOT_DIR $BASE_SYSTEM_ARCHIVE $CHROOT_SYSTEM_ARCHIVE $APT_LISTS_ARCHIVE $APT_ARCHIVE"
	echo $CMD; exec_or_die "$CMD"
}

function install_grub() {
	depends 'location=chroot_boot' partition_usb_boot && return
	setup_sh_live $FUNCNAME
}
function install_kernel() {
	depends 'location=chroot' partition_usb_boot && return
	setup_sh_live $FUNCNAME
}
function install_system_utils() {
	depends 'location=chroot' && return
	setup_sh_live $FUNCNAME
}
function install_x() {
	depends 'location=chroot' && return
	setup_sh_live $FUNCNAME
}
function remove_packages() {
	depends 'location=chroot' && return
	setup_sh_live $FUNCNAME
}
function setup_sh_live(){
	restore_apt_lists
	restore_apt_archives
	ARGS="RELEASE=$RELEASE USB_DEV=$USB_DEV USB_P1=$USB_P1 USB_P2=$USB_P2 USB_DEV_TYPE=$USB_DEV_TYPE CRYPTSETUP=y"
	run_setup_chroot $OPTS live_$1 $ARGS
}

function build_live_system() {
	depends virtual \
		build_chroot \
		partition_usb_boot \
		install_grub \
		install_kernel \
		install_system_utils \
		install_x \
		remove_packages \
		backup_apt_archives \
		backup_apt_lists
}

function depends() {

	[ "${FUNCNAME[2]}" == 'check_done' ] && return 1

	local location virtual
	dbecho "==> $FUNCNAME($@)"

	case $1 in
		virtual) virtual=1; shift ;;
		location=*) eval $1; shift ;;
		*) die "$1: invalid first argument for '$FUNCNAME'" ;;
	esac

	for i in $@; do
		dbecho "====> $i"
		eval $i
	done

	[ "$SHOW_DEPENDS" ] && {
		recho "$FUNCNAME (${#FUNCNAME[@]}): caller:${FUNCNAME[1]}, virtual=$virtual, location=$location"
	}

	[ ! "$virtual" ] && {
		check_done ${FUNCNAME[1]} "location=$location"
	}
	return 0
}

function build_usb() {
	depends virtual \
		usb_copy_system \
		usb_create_system_cfg_files \
		usb_install_extras_tty \
		usb_install_extras_gfx \
		usb_pre_initramfs \
		usb_update_initramfs \
		usb_gen_locales \
		usb_config_misc \
		usb_create_grub_cfg_file
}

function build_base() {
	depends 'location=chroot' install_host_dependencies && return
	if [ -e $BASE_SYSTEM_ARCHIVE ]; then
		gmsg "Installing '$RELEASE' from backup copy ($BASE_SYSTEM_ARCHIVE)"
		exec_or_die "tar xzf $BASE_SYSTEM_ARCHIVE"
	else
		gmsg "Installing '$RELEASE' from '$REPO_URL'"
		exec_or_die "debootstrap $RELEASE $CHROOT_DIR"
		gmsg 'Deleting package files'
		exec_or_die "chroot $CHROOT_DIR apt-get clean"
		gmsg "Making backup copy of '$CHROOT_DIR' ($BASE_SYSTEM_ARCHIVE)"
		exec_or_die "tar czf $BASE_SYSTEM_ARCHIVE $CHROOT_DIR"
	fi
}
function restore_chroot_system() {
	if [ -e $CHROOT_SYSTEM_ARCHIVE ]; then
		gmsg "Installing chroot system from backup copy ($CHROOT_SYSTEM_ARCHIVE)"
		delete_chroot
		exec_or_die "tar xzf $CHROOT_SYSTEM_ARCHIVE"
	fi
}
function build_chroot() {
	depends virtual \
		build_base \
		install_mmgen_dependencies \
		install_vanitygen \
		install_bitcoind \
		install_mmgen \
		setup_user \
		test_mmgen \
		cleanup_mmgen_builds \
		backup_chroot_system
#	msg 'Installation of chroot system complete'
}
function get_target_dev() {
	if [ "$LOOP_INSTALL" ]; then setup_loop; else get_usb_dev; fi
}
function build() {
	# Check for these right away, so user won't be interrupted later
	[ "$TARGET" == $FUNCNAME ] && {
		check_extras_tty_present
		check_extras_gfx_present
	}
	depends virtual build_usb
}

# constants
FUNCNEST=30

PROJ_NAME='MMGenLive'
HOST='MMGenLive' USER='mmgen' PASSWD='mmgen'
BOOTFS_LABEL='MMGEN_BOOT' ROOTFS_LABEL='MMGEN_ROOT'
DM_DEV='mmgen_p2' DM_ROOT_DEV='root_fs'
CHROOT_DIR="$RELEASE$ARCH_BITS.system_root"
USB_MNT_DIR='usb_mnt'
LOOP_FILE='loop.img' LOOP_SIZE=3690 # 1M blocks
BS_SIZE=4 BOOTFS_SIZE=196 PAD_SIZE=1024

case "$RELEASE" in
	wily|xenial) REPO_URL='http://archive.ubuntu.com/ubuntu/' REPOS='main universe'
				 UPDATES_URL="http://archive.ubuntu.com/ubuntu/ $RELEASE-updates" ;;
	jessie)	     REPO_URL='http://httpredir.debian.org/debian' REPOS='main'
				 UPDATES_URL="http://security.debian.org/ $RELEASE/updates" ;;
# deb http://mirrors.kernel.org/debian jessie-backports main contrib
# apt-transport-https
	*)			 die "'$RELEASE': unknown release"
esac

BASE_SYSTEM_ARCHIVE=$RELEASE$ARCH_BITS'.base.tgz'
CHROOT_SYSTEM_ARCHIVE=$RELEASE$ARCH_BITS'.chroot.tgz'
APT_LISTS_DIR="$CHROOT_DIR/var/lib/apt/lists"
APT_LISTS_ARCHIVE=$RELEASE$ARCH_BITS'.apt-lists.tar'
APT_ARCHIVE_DIR="$CHROOT_DIR/var/cache/apt/archives"
APT_ARCHIVE=$RELEASE$ARCH_BITS'.apt-archive.tar'
EXTRAS_GFX_ARCHIVE=$RELEASE$ARCH_BITS'.extras-gfx.tgz'
EXTRAS_TTY_ARCHIVE=$RELEASE$ARCH_BITS'.extras-tty.tgz'
declare -A USB_DEV_DESCS=([usb]='USB drive' [loop]='loop device')
[ "$USB_DEV_TYPE" ] && USB_DEV_DESC=${USB_DEV_DESCS[$USB_DEV_TYPE]}

if [ $SCRIPT == 'build_system.sh' ]; then
	cd `dirname $0`
	mkdir -p $CHROOT_DIR/setup $USB_MNT_DIR
	[ -e '../mmgen/setup.py' ] || {
		echo 'Unable to find the MMGen source repository.'
		echo 'It must be located in the same directory as the MMGenLive source repository.'
		exit
	}
	exec_or_die 'export MMGEN_ARCHIVE_NAME='`../mmgen/setup.py --fullname`'.tar.gz'
fi

[ "$INFORM" ] && gmsg "`inf2tense 'gerund' ${DESCS[$TARGET]}`"
eval "$TARGET"; RET=$?
[ $SCRIPT == 'setup.sh' ] && exit 0

case "$RET" in
	73) HUSH_EXIT=1 ;;
	0) ;;
	*) die "Execution of target '$TARGET' failed" ;;
esac

[ "$HUSH_EXIT" ] || bmsg "Target '$TARGET' completed successfully"
[ "$NO_CLEAN" ] || clean_exit