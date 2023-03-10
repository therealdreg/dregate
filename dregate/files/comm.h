/*
MIT License

https://github.com/therealdreg/dregate

Copyright (c) [2022] by David Reguera Garcia aka Dreg 
dreg@fr33project.org
https://www.fr33project.org 
https://github.com/therealdreg
TW @therealdreg

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

WARNING: BULLSHIT CODE X-)
*/

#ifndef _COMM_H__
#define _COMM_H__

#define DRV_RG_NAME_W L"drvdregate"

#define DOS_DRV_NAME_W L"dosdrvdregate"

#define DOS_DEVICE_NAME_W L"\\DosDevices\\"DOS_DRV_NAME_W

#define DIOCTL_TYPE 40000

#define IOCTL_DIOCTL_METHOD_BUFFERED CTL_CODE( DIOCTL_TYPE, 0x902, METHOD_BUFFERED, FILE_ANY_ACCESS )

#define APC_ARG1_dr3g 0x67337264
#define APC_ARG2_DrEg 0x67457244
#define APC_ARG3_dRE6 0x36455264 

#define GDT_ENTRY_CALL_GATE_INDEX 102

#define GDT_ENTRY_CALL_GATE_CGATELOOP_INDEX 101

#define CALL_GATE_FAR_CGATELOOP_VAL 0x328

#define IDT_KITRAP_01_INDEX 1

#define CALL_GATE_FAR_VAL 0x330

#define CALL_GATE_NR_ARGS 7

#define DRV_CTL_STR "This String is from Device Driver !!!"

#endif /* _COMM_H__ */