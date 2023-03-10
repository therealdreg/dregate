/* GPLv3 License

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

#include <asm/uaccess.h>
#include <linux/delay.h>
#include <linux/device.h>
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/ioctl.h>
#include <linux/kernel.h>
#include <linux/kthread.h>
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/string.h>

#include "com.h"

static int loopfar = 0;

MODULE_LICENSE("GPL");
MODULE_AUTHOR("David Reguera Garcia aka Dreg");
MODULE_DESCRIPTION("lkmdregatux x64 call gates stable way https://github.com/therealdreg/dregate");
MODULE_VERSION("1.0");
module_param(loopfar, int, S_IRUGO);
MODULE_PARM_DESC(loopfar, "set this value != 0 to test call gate race condition with Bochs instrumentation for dregatux");

#define I386_CALL_GATE_TYPE 0xC
#define X64_CALL_GATE_TYPE I386_CALL_GATE_TYPE

#pragma pack(push, 1)
typedef struct
{
    uint16_t offset_0_15;
    uint16_t selector;
    uint8_t zeroes;
    uint8_t type : 4;
    uint8_t zero : 1;
    uint8_t dpl : 2;
    uint8_t p : 1;
    uint16_t offset_16_31;
    uint32_t offset_31_63;
    uint32_t reserved : 8;
    uint32_t type2 : 4;
    uint32_t reserved2 : 20;

} CALL_GATE64_t;
#pragma pack(pop)

#pragma pack(push, 1)
typedef struct
{
    uint16_t offset_0_15;
    uint16_t selector;
    uint8_t ist;
    uint8_t type;
    uint16_t offset_16_31;
    uint32_t offset_31_63;
    uint32_t zero;
} IDT_DESC64_t;
#pragma pack(pop)

extern char __CHECK__[1 / !(sizeof(CALL_GATE64_t) != 16)]; // wtf CALL_GATE64_t sizeof must be 16

static int device_open(struct inode *inode, struct file *file);
static int device_release(struct inode *inode, struct file *file);
long int device_ioctl(struct file *file, unsigned int ioctl_num, unsigned long ioctl_param);

static struct file_operations file_ops = {
    .open = device_open,
    .release = device_release,
    .unlocked_ioctl = device_ioctl,
};

volatile static int thread_end_flag;
volatile struct task_struct* thread_core_1;
volatile static uint16_t ring0_cs;
extern unsigned long __force_order;
volatile static void *gdt_hook_addr;
volatile static void *new_call_gate_addr;
static int major_num;
static int device_open_count = 0;
static struct class *char_class = NULL;
static struct device *char_device = NULL;

__attribute__((naked)) int call_gate_lkm_ep(void)
{
    printk("CALL GATE LKM bitch\n");

    __asm volatile("rex64 lret $0"::: "memory");
}

__attribute__((naked)) int call_gate_loop_far_lkm_ep(void)
{
    __asm volatile("rex64 lret $0"::: "memory");
}


CALL_GATE64_t build_call_gate64(uintptr_t addr, uint16_t selector)
{
    CALL_GATE64_t call_gate = {0};

    printk(KERN_INFO "build call gate 64: 0x%px", addr);

    call_gate.offset_0_15 = (uint16_t)(addr & 0x000000000000FFFF);
    call_gate.offset_16_31 = (uint16_t)((addr >> 16) & 0x000000000000FFFF);
    call_gate.offset_31_63 = (uint32_t)((addr >> 32) & 0x00000000FFFFFFFF);
    call_gate.dpl = 0x3;
    call_gate.type = X64_CALL_GATE_TYPE;
    call_gate.p = 1;
    call_gate.selector = selector;

    printk(KERN_INFO "done: 0x%08X%04X%04X\n",
           call_gate.offset_31_63,
           call_gate.offset_16_31,
           call_gate.offset_0_15);

    return call_gate;
}

static inline void force_write_cr0(unsigned long value)
{
    asm volatile("mov %0,%%cr0": "+r"(value), "+m"(__force_order));
}

static inline void disable_readonly_memory(void)
{
    force_write_cr0(read_cr0() & ~0x10000);
}

static inline void enable_readonly_memory(void)
{
    force_write_cr0(read_cr0() | 0x10000);
}

void inject_call_gate64(CALL_GATE64_t *call_gate_gdt_entry, CALL_GATE64_t *call_gate_desc)
{
    printk("injecting call gate 64 at: 0x%px\n", call_gate_gdt_entry);

    asm volatile("cli"::: "memory");
    disable_readonly_memory();
    *call_gate_gdt_entry = *call_gate_desc;
    enable_readonly_memory();
    asm volatile("sti"::: "memory");
}

static int device_open(struct inode *inode, struct file *file)
{
    if (device_open_count)
    {
        return -EBUSY;
    }
    device_open_count++;
    try_module_get(THIS_MODULE);

    return 0;
}

static int device_release(struct inode *inode, struct file *file)
{
    device_open_count--;
    module_put(THIS_MODULE);

    return 0;
}

static inline void cpu_flags_set_ac(void) {
    __asm__ volatile ("stac" ::: "cc");
}

static inline void cpu_flags_clear_ac(void) {
    __asm__ volatile ("clac" ::: "cc");
}
 

long int device_ioctl(struct file *file, unsigned int ioctl_num, unsigned long ioctl_param)
{
    if (ioctl_num == IOCTL_SET_MSG)
    {
        char *temp = (char *)ioctl_param;
        printk("ioctl_param 0x%px\n", ioctl_param);
        new_call_gate_addr = ioctl_param;
    }
    return 0;
}

int inot(void)
{
    major_num = register_chrdev(0, DEVICE_NAME, &file_ops);
    if (major_num < 0)
    {
        printk(KERN_ALERT DEVICE_NAME ": could not register device: %d\n", major_num);
        return major_num;
    }
    printk(KERN_INFO DEVICE_NAME ": module loaded with device major number %d\n", major_num);

    char_class = class_create(THIS_MODULE, CLASS_NAME);
    if (IS_ERR(char_class))
    {
        unregister_chrdev(major_num, DEVICE_NAME);
        printk(KERN_ALERT DEVICE_NAME ": Failed to register device class\n");
        return PTR_ERR(char_class);
    }
    printk(KERN_INFO DEVICE_NAME ": class registered correctly\n");

    char_device = device_create(char_class, NULL, MKDEV(major_num, 0), NULL, DEVICE_NAME);
    if (IS_ERR(char_device))
    {
        class_destroy(char_class);
        unregister_chrdev(major_num, DEVICE_NAME);
        printk(KERN_ALERT DEVICE_NAME "Failed to create the device\n");
        return PTR_ERR(char_device);
    }
    printk(KERN_INFO DEVICE_NAME ": device class created correctly\n");

    return 0;
}

void hook_idt64_entry_1(unsigned char *addr_to_insert, int restore)
{
    unsigned int i;
    unsigned char hook_code[] = {
        0x56,             // push rsi = user mode ss
        0x52,             // push rdx = user mode rsp
        0x50,             // push rax = rflags
        0x53,             // push rbx = user mode ring3 CS
        0x51,             // push rcx = ret addr (ring3)
        0x49, 0xff, 0xc7, // inc r15 (output for user mode)
        0x48, 0xCF        // iretq
    };
    static unsigned char original_code[sizeof(hook_code)]; // wtf very crappy design xD
    unsigned char* new_bytes = hook_code;

    printk("patching idt 1 code...\n");

    if (restore)
    {
        new_bytes = original_code;
    }
    else
    {
        memcpy(original_code, addr_to_insert, sizeof(original_code));
    }

    asm volatile("cli"::: "memory");
    disable_readonly_memory();
    for (i = 0; i < sizeof(hook_code); i++)
    {
        addr_to_insert[i] = new_bytes[i];   
    }
    enable_readonly_memory();
    asm volatile("sti"::: "memory");

    printk("new code: %02X %02X %02X %02X ...\n", 
        addr_to_insert[0],
        addr_to_insert[1],
        addr_to_insert[2],
        addr_to_insert[3]
        );
}

uint64_t get_cr4(void)
{
    uint64_t cr4_val = 0;

    asm volatile( "mov %%cr4, %0": "=r"(cr4_val));

    return cr4_val;
}

#define SMEP_BIT 20
#define SMAP_BIT 21

static int kthread_worker_core_1(void *data)
{
    CALL_GATE64_t *call_gate_gdt_entry;
    CALL_GATE64_t call_gate_desc = {0};
    GIDTR_t gdtr = {0};
    GIDTR_t original_gdtr = {0};
    GIDTR_t idtr = {0};
    IDT_DESC64_t *idt_base = NULL;
    void* idt_1_addr = NULL;
    int i;
    int smep_enabled = 0;
    int smap_enabled = 0;
    uint64_t cr4 = get_cr4();

    printk("kthread_worker_core_1\n");

    asm volatile("cli"::: "memory");

    cr4 = get_cr4();

    smep_enabled = ((cr4 & (1<<SMEP_BIT)) != 0);
    smap_enabled = ((cr4 & (1<<SMAP_BIT)) != 0);

    printk("CR4: 0x%llx , SMEP: %d - SMAP: %d\n", cr4, smep_enabled, smap_enabled);

    printk("disabling SMEP and SMAP if enabled\n");

    cr4 &= ~((1<<SMEP_BIT) | (1<<SMAP_BIT));

    printk("new CR4: 0x%llx\n", cr4);

    asm volatile("mov %0, %%cr4" : "+r"(cr4));

    asm volatile("sidt %0": "=m"(idtr));

    idt_base = (IDT_DESC64_t *)idtr.addr;
    printk("idt base addr: 0x%px\n", idt_base);

    idt_1_addr =
        (void *)(idt_base[1].offset_0_15 | idt_base[1].offset_16_31 << 16 | ((uintptr_t)(idt_base[1].offset_31_63 << 32)));
    printk("idt 1 addr: 0x%px\n", idt_1_addr);

    printk("hooking idt 1 code\n");
    hook_idt64_entry_1(idt_1_addr, 0);

    asm volatile("sgdt %0": "=m"(gdtr));
    original_gdtr = gdtr;
    gdtr.size = 0x400;
    asm volatile("lgdt %0": "=m"(gdtr));
    asm volatile("sti"::: "memory");

    printk("gdt addr: 0x%px gdt size: %d\n", gdtr.addr, gdtr.size);
    gdt_hook_addr = (void *)(gdtr.addr + (100 * 8));
    printk(KERN_INFO "&(gdt[100]) addr == 0x%px\n", gdt_hook_addr);

    asm volatile("mov %%cs, %0": "=m"(ring0_cs)::PROREGS);
    printk("ring0 cs: 0x%04X\n", ring0_cs);

    printk(KERN_INFO "call gate LKM ep addr: 0x%px\n", call_gate_lkm_ep);

    if (0 == loopfar)
    {
        printk(KERN_INFO "call far from ring0 page to ring0 page, secure because cli -> call far -> sti in 3 secs....\n");
        call_gate_desc = build_call_gate64(call_gate_lkm_ep, ring0_cs);
    }
    else
    {
        printk(KERN_ALERT "call far from ring0 page to ring0 page, with interruptions=on call far infinite loop in 3 secs....\n");
        call_gate_desc = build_call_gate64(call_gate_loop_far_lkm_ep, ring0_cs);
    }
    inject_call_gate64((CALL_GATE64_t *)gdt_hook_addr, &call_gate_desc);

    msleep(3000);

    if (0 == loopfar)
    {
        asm volatile("cli"::: "memory");
        asm volatile("mov %0, %%rdi" ::"r"(far_data):PROREGS);
        asm volatile("rex64 lcall *(%%rdi)" ::: PROREGS);
        asm volatile("sti"::: "memory");

        printk(KERN_INFO "call gate executed! :D\n");
    }
    else
    {
        while (1)
        {
            asm volatile("mov %0, %%rdi" ::"r"(far_data):PROREGS);
            asm volatile("rex64 lcall *(%%rdi)" ::: PROREGS);

            if (i++ % 100000 == 0)
            {
                schedule();
                printk(KERN_ALERT "call far with ints=on executed a lot of times...\n");
            }
        }
    }

    while (1)
    {
        schedule();

        if (thread_end_flag)
        {
            goto kexf;
        }

        if (0 != new_call_gate_addr)
        {
            call_gate_desc = build_call_gate64(new_call_gate_addr, ring0_cs);
            inject_call_gate64((CALL_GATE64_t *)gdt_hook_addr, &call_gate_desc);
            printk("call gate changed to: 0x%px\n", new_call_gate_addr);
            new_call_gate_addr = 0;
            break;
        }
    }

    while (1)
    {
        schedule();

        if (thread_end_flag)
        {
            goto kexf;
        }

        if (0 != new_call_gate_addr)
        {
            call_gate_desc = build_call_gate64(idt_1_addr, ring0_cs);
            inject_call_gate64((CALL_GATE64_t *)gdt_hook_addr, &call_gate_desc);
            printk("call gate changed to idt 1 addr 0x%px\n", idt_1_addr);
            new_call_gate_addr = 0;
        }
    }

    kexf:
    asm volatile("cli"::: "memory");

    cr4 = get_cr4();

    if (smep_enabled)
    {
        printk("restoring SMEP\n");
        cr4 |= 1<<SMEP_BIT;
    }

    if (smap_enabled)
    {
        printk("restoring SMAP\n");
        cr4 |= 1<<SMAP_BIT;
    }

    asm volatile("mov %0, %%cr4" : "+r"(cr4));

    printk("restoring GDTR\n");
    asm volatile("lgdt %0": "=m"(original_gdtr));
    printk("restoring IDT 1 code\n");
    hook_idt64_entry_1(idt_1_addr, 1);
    printk("i am too lazy to fill-0 call gate descriptor, gdtr size is fixed now so... who cares\n");
    asm volatile("sti"::: "memory");

    while (1)
    {
        if (kthread_should_stop())
        {
            do_exit(0);
        }
        schedule();
    }

    return 0;
}

static int hello_init(void)
{
    printk(KERN_INFO "\n\nlkmdregatux 1.0 by Dreg https://github.com/therealdreg/dregate\n");

    inot();

    printk(KERN_INFO "device_ioctl 0x%px\n", device_ioctl);

    thread_core_1 = kthread_create(kthread_worker_core_1, NULL, "kthread_worker_core_1");
    kthread_bind(thread_core_1, 0);
    if (!IS_ERR(thread_core_1))
    {
        wake_up_process(thread_core_1);
    }
    else
    {
        printk(KERN_ERR "Failed to bind thread to first CPU\n");
    }

    return 0;
}

void ined(void)
{
    device_destroy(char_class, MKDEV(major_num, 0));
    class_unregister(char_class);
    unregister_chrdev(major_num, DEVICE_NAME);
    printk(KERN_INFO DEVICE_NAME ": Module unloaded\n");
}

void thread_cleanup(void) 
{
    int ret;
    if (NULL != thread_core_1)
    {
        ret = kthread_stop(thread_core_1);
        if(!ret)
        {
            printk(KERN_INFO "Thread in core 1 stopped!");
        }
    }
}

static void hello_exit(void)
{
    ined();
    printk(KERN_ALERT "unloading in 4 secs\n");
    // I know, I know... very crap, and wtf bro xD
    thread_end_flag = 1;
    msleep(2000);
    thread_cleanup();
    msleep(2000);
    printk(KERN_INFO "bye world!\n");
}

module_init(hello_init);

module_exit(hello_exit);
