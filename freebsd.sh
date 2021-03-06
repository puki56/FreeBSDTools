#! /bin/sh
#
# Copyright (c) 2019 Adriaan de Groot <adridg@FreeBSD.org>. All rights reserved.
#
# SPDX-License-Identifier: BSD-2-Clause
#
# This shell script can be run on a freshly-installed FreeBSD system
# to create an "instant-workstation". It uses dialog(1) for user-input,
# and does a best-effort to install what's needed.
# - a desktop environment
# - a display manager (and X and the rest)
# - graphics drivers
#
# TODO: offer a selection of common applications (e.g. Firefox, an IDE, ..)
#
# Run with --selfupdate to update the script from its canonical source
# (useful for testing updates to the script itself).

# Get a temporary location for dialog output
base=`basename $0`
CONFIG=`mktemp /tmp/${base}.XXXXXX` || { echo "! Cannot create temporary file." ; exit 1 ; }

### SELF-UPDATE
#
#
if test "x$1" = "x--selfupdate"
then
	/usr/bin/fetch -o "${CONFIG}" https://raw.githubusercontent.com/adriaandegroot/FreeBSDTools/master/bin/instant-workstation
	/bin/mv "${CONFIG}" "$0" ; exit 0
fi


### USER INPUT
#
# Pick one or more DE's, and exactly one DM
# 	NOTE: each ID should be distinct
#
/usr/bin/dialog --no-tags --separate-output \
	--checklist "Desktop Environment" 0 0 0 \
		kde5 "KDE Plasma Desktop" 0 \
		gnome3 "GNOME Desktop" 0 \
		xfce4 "XFCE Desktop" 0 \
		mate "MATE Desktop" 0 \
	--radiolist "Display Manager" 0 0 0 \
		sddm "SDDM" 1 2> ${CONFIG}

### PACKAGE SELECTION
#
# Turn the user input into specific packages and sysrc
# commands to execute.
#
packages=""
sysrc=""
sysctl=""
for line in `cat "${CONFIG}"`
do
	case "x$line" in
		"xkde5") 
			packages="$packages x11/kde5 devel/dbus"
			sysrc="$sysrc dbus_enable=YES"
			sysctl="$sysctl net.local.stream.recvspace=65536 net.local.stream.sendspace=65536"
			;;
		"xgnome3") 
			packages="$packages x11/gnome3"
			;;
		"xxfce4") 
			packages="$packages x11-wm/xfce4"
			;;
		"xmate") 
			packages="$packages x11/mate-desktop"
			;;
		"xsddm") 
			packages="$packages x11/sddm"
			sysrc="$sysrc sddm_enable=YES"
			;;
		"*")
			echo "! Unrecognized tag '${line}' in ${CONFIG}" 
			exit 1
			;;
	esac
done

rm "${CONFIG}"

### HARDWARE SUPPORT
#
# Best-guess for necessary hardware drivers
#
fbsd_version=$( /usr/bin/uname -r | /usr/bin/sed 's/-.*//' )
vga_product=$( /usr/sbin/pciconf -l | /usr/bin/awk '/^vgapci/{ print substr($4,length($4)-3); }' )
vga_vendor=$( /usr/sbin/pciconf -l | /usr/bin/awk '/^vgapci/{ print substr($4,8,4); }' )

# Look for Intel graphics
if test 8086 = "${vga_product}"
then
	case "x${fbsd_version}" in
		"x12."[012])
			packages="$packages graphics/drm-fbsd12.0-kmod"
			;;
		"x11."[234])
			packages="$packages graphics/drm-fbsd11.2-kmod"
			;;
		"*")
			:
			;;
	esac
fi

### VIRTUALBOX
#
#
if test beef = "${vga_vendor}"
then
	# Virtualbox Support
	packages="$packages emulators/virtualbox-ose-additions"
	sysrc="$sysrc vboxguest_enable=YES vboxservice_enable=YES"
fi

### X11
#
#
packages="$packages x11/xorg"

### INSTALLATION
#
#
if test -z "$packages"
then
	echo "! No packages selected for installation."
	exit 1
fi

command="/usr/sbin/pkg install $packages"
if test -n "$sysrc"
then
	command="$command ; /usr/sbin/sysrc $sysrc";
fi
if test -n "$sysctl"
then
	command="$command ; /usr/sbin/sysrc -f /etc/sysctl.conf $sysctl";
fi

su root -c "$command"
