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

#ifndef _DRVDREGATE_H__
#define _DRVDREGATE_H__

#pragma warning(push , 0 )
// #define _WDMDDK_
#include <ntddk.h>
// #include <wdm.h>
#pragma warning(pop)

#pragma warning( disable: 4214 4152 )

#include "comm.h"

#define MIN(X, Y) (((X) < (Y)) ? (X) : (Y))

#define DEVNAME L"\\Device\\" DRV_RG_NAME_W

#define KGDT_R0_CODE 0x8 
#define KGDT_R0_PCR  0x30

#define I386_CALL_GATE_TYPE 0xC

#define MAKELONG(a, b)((LONG)(((WORD)(a))|((DWORD)((WORD)(b))) << 16))
#define MAKELOW(a) ((WORD) a)
#define MAKEHIGH(a) ((WORD) ((LONG) ( ((LONG)a) >> 16) ))

typedef unsigned short            WORD,       *PWORD;
typedef unsigned long             DWORD,      *PDWORD;
typedef long                      LONG,       *PLONG;
typedef unsigned char             BYTE,       *PBYTE;
typedef __int64                   LONG64,     *PLONG64;
typedef unsigned __int64          ULONG64,    *PULONG64;
typedef unsigned __int64          DWORD64,    *PDWORD64;
typedef ULONG_PTR                 SIZE_T,     *PSIZE_T;
typedef LONG_PTR                  SSIZE_T,    *PSSIZE_T;
typedef signed char               INT8,       *PINT8;
typedef signed short              INT16,      *PINT16;
typedef signed int                INT32,      *PINT32;
typedef signed __int64            INT64,      *PINT64;
typedef unsigned char             UINT8,      *PUINT8;
typedef unsigned short            UINT16,     *PUINT16;
typedef unsigned int              UINT32,     *PUINT32;
typedef unsigned __int64          UINT64,     *PUINT64;
typedef int                       BOOL,       *PBOOL;

#ifndef FALSE
#define FALSE               0
#endif

#ifndef TRUE
#define TRUE                1
#endif

typedef struct 
{
    KSPIN_LOCK lock;
    KIRQL old_irql;
    PKDPC dpcs;
} BIG_LCK_t;

typedef enum _SYSTEM_INFORMATION_CLASS { 
    SystemBasicInformation, 				// 0 
    SystemProcessorInformation, 			// 1 
    SystemPerformanceInformation, 			// 2
    SystemTimeOfDayInformation, 			// 3
    SystemNotImplemented1, 				// 4
    SystemProcessesAndThreadsInformation, 		// 5
    SystemCallCounts, 					// 6
    SystemConfigurationInformation, 			// 7
    SystemProcessorTimes, 				// 8
    SystemGlobalFlag, 					// 9
    SystemNotImplemented2, 				// 10
    SystemModuleInformation, 				// 11
    SystemLockInformation, 				// 12
    SystemNotImplemented3, 				// 13
    SystemNotImplemented4, 				// 14
    SystemNotImplemented5, 				// 15
    SystemHandleInformation, 				// 16
    SystemObjectInformation, 				// 17
    SystemPagefileInformation, 				// 18
    SystemInstructionEmulationCounts, 			// 19
    SystemInvalidInfoClass1, 				// 20
    SystemCacheInformation, 				// 21
    SystemPoolTagInformation, 				// 22
    SystemProcessorStatistics, 				// 23
    SystemDpcInformation, 				// 24
    SystemNotImplemented6, 				// 25
    SystemLoadImage, 					// 26
    SystemUnloadImage, 				// 27
    SystemTimeAdjustment, 				// 28
    SystemNotImplemented7, 				// 29
    SystemNotImplemented8, 				// 30
    SystemNotImplemented9, 				// 31
    SystemCrashDumpInformation, 			// 32
    SystemExceptionInformation, 			// 33
    SystemCrashDumpStateInformation, 			// 34
    SystemKernelDebuggerInformation, 			// 35
    SystemContextSwitchInformation, 			// 36
    SystemRegistryQuotaInformation, 			// 37
    SystemLoadAndCallImage, 				// 38
    SystemPrioritySeparation, 				// 39
    SystemNotImplemented10, 				// 40
    SystemNotImplemented11, 				// 41
    SystemInvalidInfoClass2, 				// 42
    SystemInvalidInfoClass3, 				// 43
    SystemTimeZoneInformation, 				// 44
    SystemLookasideInformation, 			// 45
    SystemSetTimeSlipEvent, 				// 46
    SystemCreateSession, 				// 47
    SystemDeleteSession, 				// 48
    SystemInvalidInfoClass4, 				// 49
    SystemRangeStartInformation, 			// 50
    SystemVerifierInformation, 				// 51
    SystemAddVerifier, 				// 52
    SystemSessionProcessesInformation 			// 53
} SYSTEM_INFORMATION_CLASS;


typedef struct _SYSTEM_BASIC_INFORMATION { // <--- WARNING: NERVER pragma pack(1) this struct
    BYTE Reserved1[24];
    PVOID Reserved2[4];
    CCHAR NumberOfProcessors;
} SYSTEM_BASIC_INFORMATION;

#pragma pack(1)
typedef struct
{
    DWORD saved_es;
    DWORD saved_ds;
    DWORD saved_fs;
    DWORD saved_eflags;
    DWORD pusha_edi;
    DWORD pusha_esi;
    DWORD pusha_ebp;
    DWORD pusha_esp_ring0;
    DWORD pusha_ebx;
    DWORD pusha_edx;
    DWORD pusha_ecx;
    DWORD pusha_eax;
    DWORD trap_eip_call_gate_addr;
    DWORD trap_cs;
    DWORD trap_eflags;
    DWORD ret_addr_for_call_far;
    DWORD usermode_cs;
    void* arg1;
    void* arg2;
    void* arg3;
    void* arg4;
    void* arg5;
    void* arg6;
    void* arg7;
    DWORD usermode_esp;
    DWORD usermode_ss;

} gate_info_t;
#pragma pack()

typedef struct
{
    PIO_WORKITEM item;
    DWORD pid;
    DWORD tid;
    DWORD addr_to_ret;
} WORK_ITEM_ARGS, *PWORK_ITEM_ARGS;

#pragma pack(1)
typedef enum _KAPC_ENVIRONMENT
{
    OriginalApcEnvironment,
    AttachedApcEnvironment,
    CurrentApcEnvironment,
    InsertApcEnvironment
} KAPC_ENVIRONMENT;
#pragma pack()

#pragma pack(1)
typedef struct
{
    WORD IDTLimit;
    WORD LowIDTbase;
    WORD HiIDTbase;
} IDTINFO;
#pragma pack()

#pragma pack(1)
typedef struct
{
    WORD LowOffset;
    WORD selector;
    BYTE unused_lo;
    unsigned char unused_hi:5; 
    unsigned char DPL:2;
    unsigned char P:1;         
    WORD HiOffset;
} IDTENTRY;
#pragma pack()

#pragma pack(1)
typedef struct _GIDTR
{
    WORD  nBytes;
    DWORD baseAddress;
} GIDTR;
#pragma pack()

#pragma pack(1)
typedef struct _SELECTOR
{
    WORD rpl:2;
    WORD ti:1;
    WORD index:13;
} SELECTOR;
#pragma pack()

#pragma pack(1)
typedef struct _SEG_DESCRIPTOR
{
    WORD size_00_15; 
    WORD baseAddress_00_15; 
    WORD baseAddress_16_23:8;
    WORD type:4;
    WORD sFlag:1;
    WORD dpl:2;
    WORD pFlag:1;
    WORD size_16_19:4;
    WORD notUsed:1;
    WORD lFlag:1;
    WORD DB:1;
    WORD gFlag:1;
    WORD baseAddress_24_31:8;
} SEG_DESCRIPTOR, *PSEG_DESCRIPTOR;
#pragma pack()

#pragma pack(1)
typedef struct _CALL_GATE_DESCRIPTOR
{
    WORD offset_00_15;
    WORD selector;
    WORD argCount:5;
    WORD zeroes:3;
    WORD type:4;
    WORD sFlag:1;
    WORD dpl:2;
    WORD pFlag:1; 
    WORD offset_16_31;
} CALL_GATE_DESCRIPTOR, *PCALL_GATE_DESCRIPTOR;
#pragma pack()

typedef VOID (NTAPI *PKNORMAL_ROUTINE)(
    PVOID NormalContext,
    PVOID SystemArgument1,
    PVOID SystemArgument2
    );

typedef VOID (NTAPI *PKKERNEL_ROUTINE)(
    PKAPC Apc,
    PKNORMAL_ROUTINE* NormalRoutine,
    PVOID* NormalContext,
    PVOID* SystemArgument1,
    PVOID* SystemArgument2
    );

typedef VOID (NTAPI *PKRUNDOWN_ROUTINE) (PKAPC Apc);

NTSYSAPI NTSTATUS NTAPI ZwQuerySystemInformation(
    SYSTEM_INFORMATION_CLASS SystemInformationClass,
    PVOID SystemInformation,
    ULONG SystemInformationLength,
    PULONG ReturnLength
    );

NTKERNELAPI VOID NTAPI KeInitializeApc(
    PRKAPC Apc,
    PETHREAD Thread,
    KAPC_ENVIRONMENT Environment,
    PKKERNEL_ROUTINE KernelRoutine,
    PKRUNDOWN_ROUTINE RundownRoutine,
    PKNORMAL_ROUTINE NormalRoutine,
    KPROCESSOR_MODE ApcMode,
    PVOID NormalContext
    );

NTKERNELAPI BOOLEAN NTAPI KeInsertQueueApc(
    PRKAPC Apc,
    PVOID SystemArgument1,
    PVOID SystemArgument2,
    KPRIORITY Increment
    );

NTKERNELAPI VOID KeSetSystemAffinityThread(KAFFINITY Affinity);

NTKERNELAPI NTSTATUS PsLookupThreadByThreadId(HANDLE ThreadId, PETHREAD *Thread);


#endif /* _DRVDREGATE_H__ */
