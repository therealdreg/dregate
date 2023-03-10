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


NAME=lkmdregatux
UDEV=99-$(NAME).rules
obj-m += $(NAME).o
CFLAGS=-m64
CXXFLAGS=-m64
LDFLAGS=-m64

all: user kernel
	cp $(UDEV) /etc/udev/rules.d
user:
	gcc -ggdb -O0 -ffixed-r15 dregatux.c -o dregatux -lpthread
kernel:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	rm -f *.ko *.o *.mod* *odule* dregatux
	rm -f /etc/udev/rules.d/$(UDEV)
