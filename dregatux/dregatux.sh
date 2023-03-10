#!/usr/bin/env bash

# GPLv3 License
#
# https://github.com/therealdreg/dregate
#
# Copyright (c) [2022] by David Reguera Garcia aka Dreg
# dreg@fr33project.org
# https://www.fr33project.org
# https://github.com/therealdreg
# TW @therealdreg
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# WARNING: BULLSHIT CODE X-)


echo "dregatux by David Reguera Garcia aka Dreg https://www.fr33project.org - https://github.com/therealdreg/dregate"
echo "-"
echo "WARNING: you must install:"
echo "sudo apt update -y"
echo "sudo apt install -y build-essential linux-headers-`uname -r`"
echo "-"
sleep 2s

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [[ $(uname -m | grep '64') ]]; then
	echo "ok! x64 machine"

	set -x

        dmesg | grep isolat
        cat /proc/cmdline
	rmmod lkmdregatux
	make clean
	make
	echo "loading driver in 3 secs...."
	sleep 3s
	insmod lkmdregatux.ko
	echo "loading driver log in 3 secs...."
	sleep 3s
	dmesg
	echo "loading user mode in 3 secs...."
	sleep 3s
	./dregatux $1
        rmmod lkmdregatux.ko
else
	echo "Error this POC dont works on 32-bit"
fi
