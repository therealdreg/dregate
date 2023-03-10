/*
GPLv3 License

https://github.com/therealdreg/dregate

Copyright (c) [2022] by David Reguera Garcia aka Dreg
dreg@fr33project.org
https://www.fr33project.org
https://github.com/therealdreg
TW @therealdreg

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.

WARNING: BULLSHIT CODE X-), may crash, races, bad design... its just an ALPHA POC :D
*/

#ifndef _COM_H__
#define _COM_H__

#ifdef FSTDNI
#include <stdint.h>
#endif

#define DEVICE_NAME "lkmdregatux"
#define CLASS_NAME "example"
#define VBOXBP() asm volatile("1: jmp 1b" ::: "memory");
#define BOCHSBP() asm volatile("xchgw %%bx, %%bx" ::: PROREGS);
#define PROREGS "rax", "rbx", "rcx", "rdx", "rsi", "rdi", "r15"
#define IOCTL_MAGIC 0x69
#define IOCTL_SET_MSG _IOW(IOCTL_MAGIC, 0, char *)


#pragma pack(push,1)
typedef struct
{
    uint16_t size;
    unsigned char *addr;
} GIDTR_t;
#pragma pack(pop)

// if you are dumb then dont manipulate this shit:
static unsigned char far_data[] = { 
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x03, 0x00, 0x44, 0x72, 0x65, 0x67, 0x69, 0x73, 0x68, 0x6F, 0x74, 0x00 };

#endif /* _COM_H__ */
