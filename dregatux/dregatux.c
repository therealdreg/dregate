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

#define _GNU_SOURCE

#define FSTDNI
#include "com.h"

#include <fcntl.h>
#include <sched.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>

#define DEV_FILE "/dev/" DEVICE_NAME

volatile static uint16_t cs_before;
volatile static uint64_t cs_after;
volatile static uint64_t rsi;
volatile static void* rsp_to_restore;
volatile static unsigned int nr_times_call_gate_called;
volatile static void* r15;

void sleep_ms(int milliseconds)
{
    struct timespec ts = {0};
    
    ts.tv_sec = milliseconds / 1000;
    ts.tv_nsec = (milliseconds % 1000) * 1000000;
    nanosleep(&ts, NULL);
}

__attribute__((naked)) void call_gate_unstable_ep(void)
{
    asm volatile("mov $0x6969696969696969, %%rsi" ::: PROREGS);
    asm volatile("xor %%rcx, %%rcx" ::: PROREGS);
    asm volatile("mov %%cs, %%cx" ::: PROREGS);
    asm volatile("rex64 lret $0" ::: "memory");
}

__attribute__((naked)) void call_gate_unstable_loopcrash_ep(void)
{
    asm volatile("rex64 lret $0" ::: "memory");
}

void* threadw(void* arg)
{
   unsigned nr_times = nr_times_call_gate_called;
// I am too lazy to use locks, its just a crappy POC haha
   puts("thradw started!");
    do
    {
        if (nr_times != nr_times_call_gate_called && nr_times_call_gate_called != 0)
        {
            nr_times = nr_times_call_gate_called;

            printf("call gate stable executed, IRETQ from idt 1 :D!! r15 output from kernel: 0x%p loop: %u\n", 
                r15, nr_times_call_gate_called);

            fflush(stdout);
        }
        sleep_ms(100);
    } while (1);

     return NULL;
}

__attribute__((naked)) void call_gate_stable_ep(void)
{
    asm volatile("mov %%r15, %0"
                 : "=m"(r15)::PROREGS);

    if (rsp_to_restore == 0)
    {
        asm volatile("mov %%rsp, %0"
                     : "=m"(rsp_to_restore)::PROREGS);

        asm volatile("": : :"memory");
    }
    else
    {
        asm volatile("mov %0, %%rsp" ::"r"(rsp_to_restore)
                     : PROREGS);

        asm volatile("": : :"memory");

        nr_times_call_gate_called++;
    }

    asm volatile("xor %%rsi, %%rsi" ::: PROREGS);
    asm volatile("mov %%ss, %%si" ::: PROREGS);
    asm volatile("xor %%rbx, %%rbx" ::: PROREGS);
    asm volatile("mov %%cs, %%bx" ::: PROREGS);
    asm volatile("mov %0, %%rcx" ::"r"(call_gate_stable_ep): PROREGS);
    asm volatile("mov %0, %%rdi" ::"r"(far_data): PROREGS);
    asm volatile("pushfq" ::: PROREGS);
    asm volatile("pop %%rax" ::: PROREGS);
    asm volatile("mov %%rsp, %%rdx" ::: PROREGS);
    asm volatile("pushfq" ::: PROREGS);
    asm volatile("mov %%rsp, %%rax" ::: PROREGS);
    asm volatile("orw $0x100,(%%rax)" ::: PROREGS);
    asm volatile("pushfq" ::: PROREGS);
    asm volatile("pop %%rax" ::: PROREGS);
    asm volatile("popfq" ::: PROREGS);
    asm volatile("rex64 lcall *(%%rdi)" ::: PROREGS);

    puts("\nwtf, something is wrong\n");

    exit(1);
}

void ioctl_set_msg(int file_desc, char *message)
{
    int ret_val;

    ret_val = ioctl(file_desc, IOCTL_SET_MSG, message);
    if (ret_val < 0)
    {
        printf("ioctl_set_msg failed: %d", ret_val);
    }
}

int loopcrash = 0;
int first_entry = 0;

void call_far_unstable(void)
{
    if (loopcrash)
    {
        if (first_entry == 0)
        {
            first_entry = 1;
            sleep_ms(100);
        }
        asm volatile("mov %0, %%rdi" ::"r"(far_data): PROREGS);
        asm volatile("rex64 lcall *(%%rdi)" ::: PROREGS);

        return;
    }

    printf("WARNING: this call far can crash the OS :(\n");

    sleep_ms(100);

    asm volatile("mov %%cs, %0": "=m"(cs_before)::PROREGS);
    asm volatile("xor %%rsi, %%rsi" ::: PROREGS);
    asm volatile("mov %0, %%rdi" ::"r"(far_data): PROREGS);
    asm volatile("rex64 lcall *(%%rdi)" ::: PROREGS);
    asm volatile("mov %%rsi, %0": "=m"(rsi)::PROREGS);
    asm volatile("mov %%cx, %0": "=m"(cs_after)::PROREGS);
}

int main(int argc, char* argv[])
{
    cpu_set_t cpuset;
    int cpu = 0;
    uint64_t rdi = 0;
    GIDTR_t gdtr = {0};
    CPU_ZERO(&cpuset);
    CPU_SET(cpu, &cpuset);
    int i;
    pthread_t thr;

    puts("\ndregatux by David Reguera Garcia aka Dreg dreg@fr33project.org - https://github.com/therealdreg/dregate - https://www.fr33project.org\n\n");

    if (argc > 1)
    {
        if (strstr("-loopcrash", argv[1]) != NULL)
        {
            loopcrash = 1;
        }
    }

    printf("locking pages...");
    if (mlockall(MCL_CURRENT | MCL_FUTURE) != 0)
    {
        puts("error locking all pages!\n");
        return 1;
    }
    puts("ok all pages blocked");

    asm volatile("sgdt %0": "=m"(gdtr)::PROREGS);

    printf("gdt addr: 0x%p gdt size: %d\n", gdtr.addr, gdtr.size);

    int file_desc, ret_val;
    char *msg = "Message passed by ioctl\n";
    file_desc = open(DEV_FILE, O_RDWR);
    if (file_desc < 0)
    {
        printf("Can't open file: " DEV_FILE);
        exit(EXIT_FAILURE);
    }
    if (loopcrash)
    {
        ioctl_set_msg(file_desc, (void *)call_gate_unstable_loopcrash_ep);
    }
    else
    {
        ioctl_set_msg(file_desc, (void *)call_gate_unstable_ep);
    }

    puts("waiting 3 secs to conitnue...\n");
    sleep_ms(3000);

    if (sched_setaffinity(0, sizeof(cpuset), &cpuset) == 0)
    {
        asm volatile("sgdt %0": "=m"(gdtr)::PROREGS);

        printf("gdt addr: 0x%p gdt size: %d\n", gdtr.addr, gdtr.size);

        puts("ok!, set thread affinity to first core");

        printf("call far unsecure to call gate. From ring3 page to ring3 page executed with ring0 privs :D in 3 secs\n");
        sleep_ms(3000);

        do
        {
           if (loopcrash && i++ % 10000 == 0)
           {
               printf("kernel panic is coming, wait and be patient!\n");
               fflush(stdout);
               sleep_ms(50);
           }
           call_far_unstable();
        } while (loopcrash);

        printf("\n\nrsi: 0x%p\ncs before call gate: 0x%04X\ncs in call gate: 0x%04X\n", rsi, cs_before, cs_after);
        if (rsi = 0x6969696969696969)
        {
            puts("\n\ncongratz! your call was executed!\n\n");
        }

        printf("call far secure and stable  (popf=TF1, IF=0) in 3 secs\n");
        ioctl_set_msg(file_desc, (void *)call_gate_unstable_ep); // <--- yes, this is right dont change it!

        sleep_ms(3000);

        pthread_create(&thr, NULL, threadw, NULL);

        call_gate_stable_ep();
    }

    return 0;
}
