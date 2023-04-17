```
+=-----------------------------------------------------------------------=+
|=[call gates as stable comunication channel for NT x86 and Linux x86_64]=|
|=-----[ David Reguera aka Dreg - Dreg@fr33project.org @therealdreg]=-----|
|=--=[ https://www.fr33project.org/  https://github.com/therealdreg/ ]=--=|
+=--------------------=[ v13: Aug 2022 - Sep 2022 ]=---------------------=+

Phrack Staff is still reviewing my paper from Aug 2022...
So my patience ran out


Thx to Yarden Shafir (@yarden_shafir https://github.com/yardenshafir) for
her technical review + comments. It's a great honor for me :D


------[  First of all

WARNING: This paper and POCs are just for fun and just to enjoy x86_64 +
ring0 Linux/Windows internals.

*** I don't think anyone will ever use this shit for anything useful.

After paper publication all POCs + Bochs instrumentation will be available:

https://github.com/therealdreg/dregate

All POCs should work with: UMIP, NX, KASLR, SMEP, KPTI/PTI/KAISER, SMAP...
But you need to be able to load unsigned drivers on guest OS (or use an
exploit/bypass/...).

NOTE: If you don't know what these things are, you won't understand this
paper, go back to your home :D

All NT POCs presented in this paper, were tested from Windows 2000 x86 to
Windows 10 x86 10.0.19044 (with default OS protections enabled).

All Linux x86_64 POCs were tested on (with default OS protections enabled):
- Debian 11 bullseye 5.10.0-17-amd64 SMP x86_64 (last Aug 2022)
- Ubuntu 22.04.1 LTS jammy 5.15.0-46-generic SMP x86_64 (last Aug 2022)

Linux & Windows POCs Tested on (HW Tiger Lake, i7 11th GEN):
- Bochs 2.7 cpu=corei3_cnl (Cannonlake UMIP...). Host: Windows 10 x86_64.
- VirtualBox 6.1.36 r152435. Host: Windows 10 x86_64.
- Qemu/KVM 6.2.0 (q35 + host-passthrough). Host: Ubuntu 22.04.1 x86_64.
- Native OS installation: Ubuntu 22.04.1 x86_64 & Windows 10 x86 10.0.19044

Thx to Duncan Ogilvie (x64dbg owner: @mrexodia https://github.com/mrexodia)
for proofreading, I love you bro :D

Thx to micronn for their test/comments/time .... :***

Thx to ZwClose for his feedback


<<<<<<<<<<<<<<<
Only one prerequisite for understanding this paper:

- Have an OSCP certification... xDDDDDDDDDDDDDDDDDDDD


------[  NT x86 call gates: Introduction

Well... It has been 14+ years since my last publication on Phrack (#65)

At that time I was ~17 years old, I was young and stupid. Today is much
better because I am no longer young :-(

By the way, phook had a lot of stupid and wrong things xD, but it was
just a dirty POC idea.

Let's get started with Windows part:

"x86 call gates as stable comunication channel for NT"

First, a little background:

x86 chips offer several ways of performing system calls. A few Examples
are: SYSCALL, SYSENTER, Software interrupts and Call gates.

A call gate allows the kernel to call to user mode and vice versa.

Call gates were rarely used because of portability issues. NT does not use
them, but they have been used in exploits and malware like Gurong.A

<<<<<<<<<<<<<<<
If you have not understood anything so far, I'm sorry flag-hunter but this
paper is not for you. Just run back to TryHackMe/HackTheBox.

The reason for this paper is that there is a little problem with call
gates (YES, in 2022!):

AFAIK, all public sources have some race conditions because this mechanism
is not compatible with the NT design. As a result you get random BSODs.

Just for fun, I developed a tricky way to give it stability.

First of all, a bit of lore/gossip:

January 2010, Mateusz "j00ru" Jurczyk and Gynvael Coldwind present a new
paper: "GDT and LDT in Windows kernel vulnerability exploitation"

Btw, we worked for the "same" company at the time (Hispasec/Virustotal),
What a coincidence! Small world :D

Their paper explains how to use a write-what-where condition to convert a
custom LDT entry into a call gate and then use this call gate to elevate
the privilige mode from ring3 to ring0.

Before this paper, I made some changes to the "Call gate" chapter in the
2nd edition of "The Rootkit Arsenal". Bill Blunden accepted my corrections
and they were published (thx for the credit bro! :-D). But as I said, race
conditions/BSODs can happen with our code :-(

After j00ru and Gynvael's publication, my reaction as a Rootkit Unhooker
contributor was to add some features: detecting GDT/LDT call gates, LDT
forward attacks, etc. AFAIK, it has been the only tool that detects things
like LDT forward attack. Rku was the best anti rootkit tool by far, don't
you think? :D

btw, thanks to EP_X0FF for taking my crap POCs and making it decent.

** I miss the kernelmode/rootkit.com era. Btw, one of my childhood dreams
was to collaborate with Rku/29a/phrack/uninformed. So, I can die in peace

At that moment (2009) we were all happy with our buggy call gate POCs,
but...

A fast and furious Indy appeared!!! (woodmann.com/forum, 2009):
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
https://web.archive.org/web/20181222042324/
http://www.woodmann.com/forum/showthread.php
?13355-quot-Descriptor-tables-in-kernel-exploitation-quot-a-new-article
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Indy to j00ru & Gynvael:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
...
Using the descriptor table is not desirable for the escalation of
privileges. Callgate has many drawbacks (high probability of crash, it is
better to use IDT), such as:
o Do not reset TF and IF.
o Do not formed a trap frame(this is a great disadvantage).
Should use the mechanism that lead to the call target code after the change
of the CPL, the already formed trap frame and unmask interrupts
...
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Gynvael:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
...
You are correct about the drawback, however, let me comment on the issues
you stated:
1. The TF is controllable - if one does not explicitly set the TF flag with
a POPF one instruction between the CALL FAR to the call gate, then the TF
flag is neglectable in my opionion

2. The IF flag is not reset, which creates a small but existing race
condition Windows - after the CALL FAR, but before explicitly disabling the
IF (cli). I admit that it is possible, but I would judge that the
probability is rather small.

3. The trap frame is not formed indeed, but it can be emulated on demand by
the shellcode writer.
...
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Indy:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
...
1. If there is a call to the gateway with TF = 1, then it will lead to the
emergence of the trace exception (#DB) in the kernel. Accordingly, the
handler is not installed, that will cause crash. Of course this is not a
critical situation, but can cause problems. But you can ignore this.

2, 3.

While not formed trap frame interrupts can not be unmasked. Although the
stack will be switched to kernel from TSS, but the context of the problem
is not formed, ie the problem does not exist, it will lead to crash.
Of course you can reduce the probability of crash - after crossing the
gateway to mask interrupts, and then manually create trap frame.
Also all user memory is discharged(to swap), the page may be loaded from
drive(swap) only if the interrupt unmasked and only on the first two IRQL.

Yet formed trap frame not available any kernel runtine. You can use the
exception, for example - registration of a handler in the kernel, with
subsequent generation of exception, or any mechanism that formed trap
frame. For hand building trap frame(macro ENTER_TRAP, although it is not
necessary) - the best way to morph handlers in the memory (transfer).
...
Masked interrupts are equivalent to the highest level of IRQL (0xff). It is
forbidden:
- Use memory is pumping. In particular the process address space.
- Apply to other modules and subsystems.
- Use a scheduler runtime. Waiting at the objects, working with threads,
service calls, I/O operations, APC (and others, the context has not been
formed  ), etc., that is, in fact, we can not do anything.
Exploit's for a privilege escalation are too valuable to work with some
probability of crash experienced by the coder
This possibility exists because of memory paging and context switching
(hardware interrupts can do after passing through the gateway, but to mask
interrupts manually (cli), and hardware interrupts are completed by calling
the scheduler).
All this is just my imho. I think the mechanism callgates not suitable for
use in the NT, as a special case in exploit's
...
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Years later (rohitab.com, 2014), zwclose7 post about a own call gate code:

http://www.rohitab.com/discuss/topic/40765-installing-call-gate-on-Windows/

And of course, Indy strikes again x-)

Indy to zwclose7:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Transition through the gateway does not change Eflags. Ie not masked IF and
is not reset TF. Therefore technology is not compatible with NT. When
tracing is bugcheck. On the IF - instability.
__asm
{
push ebp
mov ebp,esp
push fs // Save the value of FS
mov ax,0x30 // Set FS to kernel mode value
mov fs,ax
}
Where you copied the code ?
I'm here for you. Do you want to invite. You burned on to this code.

You do not know segmentation and protected mode.
You do not see a vulnerability in your code.
You stole the code by MsRem(Delphy, crap; 2006).
You not VX.
You pretend.

I was wrong.
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Well, as you can see, Indy is a hard call gate hater xD, but mentions
several true and interesting things.


------[  Call Gate Problems in NT

1- BSOD when stepping into (TF=1) a CALL FAR (usually during debugging).

2- BSOD when an interrupt happens inside the call gate (after executing
the) CALL FAR instruction. CALL FAR does not disable interrupts, so you
need to execute the CLI instruction to disable interrupts. In short: there
is a race condition between the CALL FAR -> CLI execution.

3- After the CLI instruction the CPU executes at roughly the highest IRQL,
or in Indy's words: "in fact, we can not do anything."

Even when we avoid a BSOD and we reach the instruction after CLI we are
very limited and we need create a TRAP FRAME+STI or something to execute
code at PASSIVE_LEVEL.


------[  My tricky solution

How did I solve these problems for my own rootkit?

My first thought was hooking all possible parts, Something like:

Hooking clock interrupts, keyboard interrupts, ...

Then, when an interrupt happens between CALL FAR -> CLI keep the control
and fix the TRAP FRAME part, etc.

Nah, pure crap. This idea is stupid and sounds like a lot of work +
problems/performance impact...

After a few days thinking on it, I had a simple idea:

Use the instability that Indy mentioned to make it stable.

How? Windows configures IDT[1] (confusingly named KiTrap01) as an interrupt
gate, which means IF=0 while executing the handler.

So, bingo! I don't need execute CLI (which means: no race condition)

I just need to force TF=1 just before the CALL FAR. High level steps:

1. Hook the IDT 1 (KiTrap01) Single-step interrupt
2. Create a CALL GATE in GDT
2. POPF to force TF just before CALL FAR
3. Our KiTrap01 executes (another one) CALL/JMP far to execute our
call gate, why not? :D

IMPORTANT: First, CALL FAR is executed (EIP=CALL_GATE_EP), just after that
the call gate code is interrupted by KiTrap01 because TF=1 and this sets
IF=0 (auto CLI). Hooray!

NOTE: (call gates) ring3-->ring0 its only possible using a CALL FAR.
inter-privilege-level control transfer is not possible with a JMP FAR (GP).
So, my code only executes a JMP FAR (call gate) from ring0-->ring0 (driver)

Basic idea:

  RING3
  ++++++++++++++++++
  pushf
  or word ptr[esp], 0100h
  popf
  CALL FAR --+        (* a JMP FAR dont works from ring3-->ring0)
  ++++++++++ | +++++
             |
             |
  RING0      |
  ========== | ==========================================================
             v  TF=1 Step interrupt (auto CLI IF=0)
   CALL GATE EP ----------------------> KiTrap01 hooked call/jmp far --+
      ^                                                                |
      +----------------------------------------------------------------+
                         JMP/CALL FAR
  =======================================================================

EIP flow:

1. EIP=popf (TF=1)

2. EIP=CALL FAR

3. EIP=CALL GATE EP (then CALL FAR pushes some info on the kernel stack)

4. EIP=KiTrap01 hooked (interrupts auto-off thx to Step interrupt) IF=0

CPU pushes some info on the kernel stack when this interrupt happens.

5. EIP=CALL GATE EP (KiTrap01 hooked executes another call/jmp far)

If this is a communication channel... how to pass data from user mode to
kernel mode? Easy, when a call gate it's created it's possible specify a
numbers of arguments (GDT entry).

For example, calling a call gate with 5 arguments:

  push arg5
  push arg4
  push arg3
  push arg2
  push arg1
  pushf
  or word ptr[esp], 0100h
  popf
  CALL FAR

And yes! these arguments are automatically copied to the kernel stack by
the CPU before the KiTrap01 interrupt.

Stack changes:

(1)

  push arg5
  push arg4
  push arg3
  push arg2
  push arg1
  *EIP:

          User Mode Stack
          ==============
          arg1
          arg2
          arg3
          arg4
          arg5

(2)

  pushf
  or word ptr[esp], 0100h
  popf
  CALL FAR ---+
              |
              v
  *EIP=CALL GATE EP

  Kernel Mode Stack
  =================
  ret_addr_for_call_far <- pushed by CALL FAR
  usermode_cs           <- pushed by CALL FAR
  arg1                  <- pushed by CALL FAR
  arg2                  <- pushed by CALL FAR
  arg3                  <- pushed by CALL FAR
  arg4                  <- pushed by CALL FAR
  arg5                  <- pushed by CALL FAR
  usermode_esp          <- pushed by CALL FAR
  user_mode_ss          <- pushed by CALL FAR

  * User Mode Stack unchanged

(3)

  *EIP=KiTrap01 hooked <- because TF=1 (POPF)
  IF = 0 <- because Windows configures IDT 1 as an interrupt gate

  Kernel Mode Stack
  =================
  trap_call_gate_ep_addr (last EIP) <- pushed by CPU because of interrupt 1
  trap_cs (last CS)                 <- pushed by CPU because of interrupt 1
  trap_eflags (last eflags)         <- pushed by CPU because of interrupt 1
  ret_addr_for_call_far             <- pushed by CALL FAR
  usermode_cs                       <- pushed by CALL FAR
  arg1                              <- pushed by CALL FAR
  arg2                              <- pushed by CALL FAR
  arg3                              <- pushed by CALL FAR
  arg4                              <- pushed by CALL FAR
  arg5                              <- pushed by CALL FAR
  usermode_esp                      <- pushed by CALL FAR
  user_mode_ss                      <- pushed by CALL FAR

    * User Mode Stack unchanged


At the end of the call gate code pushing EFLAGS with IF=1 and IRETD allows
us to return to user mode with interrupts enabled again, 100% safe!

To summarize, we can:

1. Use a call gate without BSODs/races, hooray!
2. Pass data from user to kernel mode using call gate arguments
3. Return to user mode in a safe way, just like a legal interrupt (IRETD)

The next problem:

Our call gate is now secure because interrupts are disabled without races,
but as Indy said IF=0 means: "in fact, we can not do anything."

Gynvael and Indy mention some possible solutions:

- Creating a manual trap frame + lower IRQL

- Jumping to an existent Windows function to create a valid trap frame +
lower IRQL ...

Nah, I don't like it. Just for fun, let's find another way.

Why not use an NT work item?

With IF=0 we can queue a work item to request a callback into our driver
later. This work item callback occurs at PASSIVE_LEVEL in the context of
a worker thread owned by the operating system.

So, it's perfect! In a work item callback we can do everything we need.

This is the big picture:

1. From user mode: POPF TF=1 + CALL FAR passing info to kernel via call
gate arguments

2. Hooked KiTrap01 (IF=0) performs another CALL/JMP FAR to our call gate
(just for fun)

3. CALL GATE code copies call gate arguments for a work item callback

4. CALL GATE code queues a work item

5. CALL GATE returns to user mode with an IRETD (enabling interrupts)

6. Later, our work item callback is executed at PASSIVE_LEVEL

So our driver can receive info from user mode, but how can the driver send
info to back to user mode?

There are two simple ways:

- Using some registers as data out

- Using memory addresses sent via call gate arguments.

WARNING: User mode memory accesses must be happen in the work item.
The call gate code only can use Non-paged memory since we are not
executing at PASSIVE_LEVEL (IF=0 + PAGE FAULT = BSOD).

So... why not queue a usermode APC from our work item callback? It is 100%
safe because our work item is executed at PASSIVE_LEVEL.

The data travel:

  +---------------+                    +-------------------+
  | USER MODE     |      (1)           | KERNEL MODE IF=0  |
  | arg5, arg4...-----------------------> arg5, arg4..     |
  +-- ^ ----------+                    +- | ---------------+
      |                                   |
      |                                   |
   +++++++++++++       +----------------- V -------------------+
   | APC + data|       | KERNEL MODE WORK ITEM CREATION IF=0   |
   +-----------+       |    COPY of arg5, arg4..               |
      |                +----------------- | -------------------+
      |                                   |
      |     +---------------------------- V ----------------+
      |     | KERNEL MODE                    IF=1           |
      |     | WORK ITEM CALLBACK (PASSIVE_LEVEL)            |
      |     | work with arg5, arg4... and returns info via: |
      +------- queue an usermode-APC + data                 |
            +-----------------------------------------------+


Done! We now have a stable comunication channel between user mode
and kernel mode. Pure Asynchronous I/O Programming NT style, haha.

All very nice, but wait a moment! I am using a POPF TF=1, So A furious
Indy might think: "this is cheating!"

IMO NO! In fact, the CALL FAR is executed completely and just after that
the call gate is interrupted because TF=1 (this interrupt cause an IF=0).

So call gate don't need execute an explicit CLI :-) win-win

So, EIP has been on CALL GATE ENTRY POINT before KiTrap01 interruption.

What do you think? Please Indy, don't blame me for this shit :D


------[  dregate 1.0

Sources: dregate\dregate\files

Our final POC: dregate, consist in two components.

drvdregate.sys (driver), high level overview:
1. Hooks IDT KiTrap01
2. Installs a call gate
3. call gate code: Creates a work item (passing call gates args)
4. work item call back: Queues a usermode APC at a TID + address

dregate.exe (usermode), high level overview:
1. Executes a call gate from user mode via the method described above
2. Sends info to the kernel via call gate arguments (target TID + address)
3. Receives info from driver via usermode-APC arguments

Someday I'll port it to Winx64, but PatchGuard is a pain in the ass.
Hooking the GDT+IDT is easy to detect and it will trigger a BSOD.

How to test it?

Just execute
""""""""""""
dregate.bat
"""""""""""

===========================================================================
C:\dregate>C:\dregate\w2k_load.exe
C:\dregate\\files\objfre_wxp_x86\i386\drvdregate.sys

// w2k_load.exe
// SBS Windows 2000 Driver Loader V1.00
// 08-27-2000 Sven B. Schreiber
// sbs@orgon.com

Loading "C:\dregate\\files\objfre_wxp_x86\i386\drvdregate.sys" ... OK

dregate by Dreg https://github.com/therealdreg/dregate

Input Buffer Pointer = 0012FCC8, Buf Length = 100
Output Buffer Pointer = 0012FD34 Buf Length = 100

Calling DeviceIoControl METHOD_BUFFERED:
Out Buffer (38): This String is from Device Driver !!!

waiting for APC....

ioctl APC executed! arg1: 0x67337264 arg2: 0x67457244 arg3: 0x36455264

arg1 -> dr3g

arg2 -> DrEg

arg3 -> dRE6

waiting 5 secs to continue....

executing CALL FAR with bad key nothing will be happen
PID: 112 0x70
TID: 332 0x14c

executing CALL FAR with good key, a msgbox (from APC queued from a
work item) is coming

APC (C part) executed! arg1: 0x67337264 arg2: 0x67457244 arg3: 0x36455264

arg1 -> dr3g

arg2 -> DrEg

arg3 -> dRE6
===========================================================================

What happened here?? a lot of things, the most important:

1. dregate.exe sends an IOCTL to drvdregate.sys

2. drvdregate.sys queue a user mode APC to caller thread dregate.exe

3. User mode APC recvs 3 args from driver

Ok, the previous part check if APC Injection works, Next:

4. dregate.exe executes a CALL FAR with an invalid key (one of call gate
arguments) to test if call gate mechanism works:

  POPF (TF=1) + CALL FAR -> CALL GATE EP -> KiTrap01 hooked ---+
                                                               |
                                                               v
                                                            JMP/CALL FAR
                                                               |
                                                               |
                                                               v
                                                           CALL GATE EP

The call gate returns to eax passed by dregate.exe in CALL FAR. It doesn't
return to the address pushed by CALL FAR, because... why not? xD

So, this previous part checks if our call gate way works as expected, Next:

6. dregate.exe executes a CALL FAR with a correct key

7. drvdregate.sys queues a work item using the call gate arguments, storing
information like target TID, target APC address, etc.

8. drvdregate.sys returns to user mode with IRETD (eax == eip)

9. The work item (executing at PASSIVE_LEVEL) queues an user mode APC

10. The user mode APC is executed and dregate.exe get 3 APC arguments from
kernel mode :D

In summary, the comunication channel looks like this:

  +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  | drvdregate.exe sends info to ring0 using call gates arguments |
  +++++++++++++++++++|++++++++++++++++++++ ^ ++++++++++++++++++++++
                     |                     |
           [call gate arguments]   [3 APC arguments]
                     |                     |
                     |                     |
 +++++++++++++++++++ V ++++++++++++++++++++|+++++++++++++++++++++++++++++++
 | drvdregate.sys sends info to ring3 via APC injection + 3 APC arguments |
 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

dregate.exe can also inject user mode APCs into another process:

''''''''''''''''''
dregate.exe PID
''''''''''''''''''

 * create a remote thread to target process and send to driver: remote TID
     |                                    + remote target address (for APC)
     |
     V
 * call gate EP *
     |
     |
     V
 * KiTrap01 *
     |
     |
     V
 * call gate EP *
     |
     |
     V
 [work item -> queue APC to the remote thread (MessageBox)]


dregate.exe can do the same technique to a notepad.exe, just type:
'''''''''''''''
dregate.exe -t
'''''''''''''''

NOTE: to execute dregate.exe the driver must be loaded. So, execute
dregate.bat first to load the driver.

WARNING: idt[0x2d](nt!KiDebugService) can happen inside my call gate code
(with IF=0) because I am using DbgPrint. This is not a risk, no worries.
When caller is kernel mode (with IF=0), KiTrap03DebugService keeps IF=0.


------[  cgateloop 1.1

Sources: dregate\Bochs\Bochs_own_files\ins_cgateloop\instrument\example0

As Gynvael said:
" The IF flag is not reset, which creates a small but existing race
condition Windows - after the CALL FAR, but before explicitly disabling the
IF (cli). I admit that it is possible, but I would judge that the
probability is rather small "

This is right, but I created a project called cgateloop to check/force
the race condition.

cgateloop is very simple:

************************
while (1)
{
    CALL FAR from user mode --> RETF from the call gate (kernel mode)
                      ^              |
                      |______________|
}
************************

So, EIP makes the following trip:
while(1)
{
 EIP=CALL FAR <- (ring3) an interrupt at this point is not dangerous
 EIP=RETF <- (ring0) if this instruction is interrupted the system can BSOD
}

How to test it?

Just execute inside Bochs:
""""""""""""""""""""""
cgateloop_silence.bat
""""""""""""""""""""""

cgateloop execution will cause a BSOD in 1-2 minutes.

Note: If you want force the race condition early, just use the PC while
cgateloop is running: open browser, notepad, press keys on keyboard ....

1-2 minutes for a BSOD... So, As Gynvael said: "it's rather small" :D

Why the BSOD? When EIP is at the call gate RETF the call gate code can be
interrupted (because CALL FAR doesn't disable interrupts).

For example it can be interrupted by:
*********************************************
d1: hal!HalpClockInterrupt
a3: i8042prt!I8042MouseInterruptService
62: atapi!IdePortInterrupt
93: i8042prt!I8042KeyboardInterruptService
...
*********************************************

As I said, the call gate code is executing in ring0, but not in a legal
way, so chaotic things can happen. There is no trap frame, maybe bad
segment values, registers with ring3 info, etc.

Result: a nice BSOD in your face, Indy is happy!

To research the crash reason I coded an instrumentation for Bochs

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bochs is a highly portable open source IA-32 (x86) PC emulator written in
C++, that runs on most popular platforms. It includes emulation of the
Intel x86 CPU, common I/O devices, and a custom BIOS. Bochs can be compiled
to emulate many different x86 CPUs, from early 386 to the most recent
x86-64 Intel and AMD processors which may even not reached the market yet.
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Why not QEMU? well, Bochs is a pure emulator, so we have more control.

Trust me, we have more control in Bochs vs QEMU.

Bochs is very powerful and easy to use/instrument but it's slow as hell.

Btw! Bochs is now on Github! We will be glad to see your contribution:

https://github.com/bochs-emu/Bochs

My instrumentation for cgateloop detects when a interrupts happens between

CALL FAR <---> RETF

It will then break into the debugger for inspection (it also prints some
useful contextual information)

Example of use:

1. Copy cgateloop project to a Windows XP Bochs machine (MUST use only 1
core)

2. Copy Windows XP Bochs machine to Bochs-cgateloop\winxp.img

3. Run Bochs-cgateloop\Bochs.bat

This runs my own Bochs version (for a x64 Windows host) with debugger
support + cgateloop instrumentation

when Debugger breaks on Start just type: c

4. Run cgateloop_silence.bat

5. Wait for the Bochs Debugger to break


------[  cagrackme 1.1

Sources: dregate\Bochs\Bochs_own_files\ins_cagrackme\instrument\example0

Based on my old cagrackme 1.0 for x32 WinXP SP3:

https://github.com/therealdreg/cagrackme

This was my first crackme using my concept of "stable call gate"

To test it just execute:
""""""""""""""""""""""""
cagrackme.bat
""""""""""""""""""""""""

Of course the cagrackme source code will be published with this paper

After you enter a bad code/password, this POC is like cgateloop but with
our stable call gate method:

***************************************************************************
while (1)
{
 [ usermode ]   [ kernel mode                                         ]
  CALL FAR    -> call gate EP -> KiTrap01 CALL/JMP FAR -> call gate EP
      ^                                                     |
      |_____________________________________________________|
}
***************************************************************************

This POC never crashes/BSODs the system. I promise, I tested it for 1 week
without any crash (I was using the OS at same time).

My instrumentation for cagrackme detects when an interrupts happens
between (never):

CALL FAR <---> IRETD

just execute inside Bochs:
""""""""""""""""""""""
cagrackme_silence.bat
""""""""""""""""""""""

Remember: cagrackme executes some instructions from CALL FAR to IRETD and
it don't need an explicit CLI because of the KiTrap01 trick.

If an interrupt happens (never), the instrumentation would break in the
debugger for inspection. You can test by running it in Bochs as described
above (look cgateloop instrumentation part).


------[  cagrackme solution

For the first time I publish the solution:

code1: 0x69696969
code2: 0xFFFFFF00

I will not give more details, send me your write-up

The best community write-up will be published in cagrackme github:

https://github.com/therealdreg/cagrackme


------[  Quantum physics

When you look at the experiment you alter it.

Because I need to hook KiTrap01 to make the call gate stable when you debug
dregate/cagrackme/cgateloop a weird thing can happen xD

This is not an anti-debug trick as some people thought. Instead it's just a
side effect, so we have 2x1 :-D

For this reason, I recommend debugging it with an emulator like Bochs or
just use the VirtualBox debugger or VMWare GDB stub. I made some projects
to help you with symbols.

If you want to use VMWare STUB + IDA:
Helper script for Windows kernel debugging with
IDA Pro on VMWare + GDB stub (including PDB symbols):
https://github.com/therealdreg/ida_VMWare_Windows_gdb

If you want to use Bochs + IDA (the previously-mentioned instrumentation
doesn't work well with this):
Helper script for Windows kernel debugging with
IDA Pro on native Bochs debugger (including PDB symbols):
https://github.com/therealdreg/ida_Bochs_Windows

If you want pure Bochs native debugging:
Helper scripts for Windows debugging with symbols for
Bochs and IDA Pro (PDB files).
Very handy for user mode <--> kernel mode:
https://github.com/therealdreg/symseghelper

The Bochs native debugger is very limited... I am developing a new debugger
inspired by GDB-GEF:
Bochs Enhaced Debugger (Bochs-bed). A modern console debug experience:
https://github.com/therealdreg/Bochs-bed
Btw, it's very crap so far, PRs are welcome.

NOTE: ida_VMWare_Windows_gdb and ida_Bochs_Windows are based on
IDA-VMWare-GDB by Oleksiuk Dmytro (aka Cr4sh):

https://github.com/Cr4sh/IDA-VMWare-GDB


------[  x86 NT conclusion & challenge for you

A lot of weeks wasted on this project, POCs, debugging, IDAPython plugins,
Bochs instrumentation, symbol helpers, etc.

I hope you had fun reading this paper and experimenting with the tools

No one in their right mind uses call gates as a communication channel x-)

As a challenge to the reader:

- Why does cgateloop bsod?

I mean... what exactly is the reason? Are there different scenarios? x-)

- Why do some interrupts not immediately cause a BSOD in cgateloop?
(Clock ... )

Send me your explanation and I will publish it in the dregate repo
(including your credits etc.)

It's fun and easy!

I've done all the dirty work for you and you have all the tools here.


------[  BONUS TRACK!! Linux x86_64 call gates: dregatux 1.0

Sources: dregate\dregatux

There aren't many public POCs that use call gates on Linux x86_64...

Also on Linux there is no PatchGuard.

*** I love Linux Kernel Runtime Guard (LKRG) by @Adam_pi3:

https://lkrg.org/

It's an awesome work, but who the hell uses this? just me? :-D

So, here we go. The same stable-call-gate-thing but for Linux x86_64.


x86_NT_POC vs x86_64_Linux_POC:
===============================
- x86_64 means no args for call gates. So I use registers as data out.

- 64 bit addresses everywhere: descriptors, stack etc.

- call gate 64 desc size == 2 entries GDT

- call far/iretq/retfq with REX64 prefix

- call far using a [register]

- GDTR and IDTR has 64 bit addresses

- increase GDTR size to insert a call gate

- GDTR address is read only, so cr0 trick :D (write a read-only PAGE)

- Don't modify IDT table. It overwrites original IDT 1 code (cr0 trick).
Why? because I'm too lazy to flip the KPTI bit + JMP to my driver code. its
just a POC, this way is simple and works fine with KPTI/PTI/KAISER.

- RETFQ & IRETQ POCs.

- CALL GATE execution on ring3 NON PAGED AREA with KERNEL PRIVS (CS:RING0).
For this reason (and others), my LKM disables on-load some protections like
SMEP and SMAP from cr4.

- when IDT 1 is patched don't use a debugger. A simple step -> kenel panic!

- swapgs (if necessary)

- KPTI + KASLR + user mode ASLR + UMIP + NX should not be a problem.

- ... check my code, intel manuals, Linux kernel code, osdev ... :-D

The following three(3) POCs should works with: KPTI, UMIP, NX, SMAP, SMEP..

1. call far + retfq (ring0-page to ring0-page), so call far is executed on
a ring0 NON PAGED area and the call gate entry point is executed on a ring0
NON paged area. It's 100% safe because ring0 code can execute
CLI + CALL/JMP FAR + STI:

  | RING0 NON PAGED AREA |          | RING0 NON PAGED AREA |
  +----------------------+          +----------------------+
  |  cli                 |          | call_gate_ep:        |
  |                  IF=0                                  |
  |  call far [rdi] ----------------> retfq --+            |
  |                                           |            |
  |  sti <------------------------------------+            |
  |  ...                 |           |                     |


2. Race condition call far + retfq (ring3-page to ring3-page). Thx to Linux
mlockall, call far + call gate code is executed on a ring3 NON PAGED AREA.
So, NO problems with page faults, but still unsafe because if an interrupt
occurs in call gate code (when IF=1)---> (maybe) kernel panic in your face.

Like in x86 cgateloop NT POC, the window is little, but it exist:

                            | RING3 NON PAGED AREA |
                            +----------------------+
  | RING3 NON PAGED AREA |  |                      |
  +----------------------+  | call_gate_ep:        |
  |  (CS:ring3)         IF=1  (CS:ring0)
  |  call far [rdi] ---------> retfq (* INTERRUPT)---> IDT Code
     (CS:ring3)                                        *At this point: Indy
  |  xor rax, rbx        |  |                      |   thinks you're an
  |  .....               |  |                      |   asshole :D


*OR if you are lucky:

                            | RING3 NON PAGED AREA |
  | RING3 NON PAGED AREA |  +----------------------+
  +----------------------+  | call_gate_ep:        |
  | (CS:ring3)     IF=1       (CS:ring0)           |
  | call far [rdi] ----------> retfq --+           | *At this point Indy
  | (CS:ring3)                         |           | still thinks you're a
  | xor rax, rbx <---------------------+           | lucky idiot :D
  | ...                                            |
  |                      |   |                     |


3. Stable call gate thing: popf (TF=1) + call far + iretq (ring3-page to
ring0-page). Similar to dregate or cagrackme, BUT:

- call gate code EP also points to IDT 1 code ... wtf, wait! whaat? Because
this way its simple and works fine with KPTI (its just a POC :D)

 [GDT]
 0:                                                     [IDT]
 ...                                                    0: ...
 100: call gate addr ------> SAME RING0 CODE <--------- 1: debug int addr
 ...                      (**Original IDT 1 code)          .........

RIP flow:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
// It should not crash because it is stable like my dregate x86 NT POC.
while (1) // <----- INFINITE SAFE LOOP :D
{
 [ CS:ring3 AREA       ] [ CS:ring0 AREA (IF=0)                           ]
 +++++++++++++++++++++++ ++++++++++++++++++++++++++++++++++++++++++++++++++
                                          (4) RIP: CALL GATE EP by CPU
 (1)(by user mode code)                    +---------+
  RIP: popf   (TF=1)                       |         |
 (2)(by user mode code)  (3) by CPU (IF=0) v         |
  RIP: call far (IF=1)-----> RIP: CALL GATE EP -> interrupt 1 by CPU (TF=1)
                                           |
                                           |
             (IF=1)                        v
 (6?) RIP: ring3 code <-------- (5?) RIP: IRETQ (by call gate code) (IF=0)
}
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

** Clarification:

In (3), CPU sets RIP=CALL_GATE_EP + CPU push call far data (ret addr...)

in (4), CPU re-sets RIP=CALL_GATE_EP + CPU push interrupt 1 data

After (4) call gate code is executed.

WARNING: Kernel Mode Stack is not 100% like dregate/cagrackme because
no call gate args, 64 bit addresses ... just check the code/docs :-D

How to test all POCs (from 1 to 3)?

Execute:
---------------------
dregatux/dregatux.sh
---------------------

This script executes all 3 POCs in seq-order: 1, 2, 3

WARNING: POC 2 is a call far unsecure and can cause a kernel panic, just
reboot, cross your fingers and re-run ./dregatux.sh

WARNING: NEVER execute ./dregatux directly, it's necessary reload LKM each
time. So, you should use ./dregatus.sh script

SURPISE: VMWARE bug (16.2.4 build-20089737). You must use dregatux with a
real computer / VirtualBox 6.1.36 r152435 / bochs 2.7 or Qemu/KVM: 6.2.0.

NOTE: if you hunt a vmware-0day/escaping using my hint give me some money
moth**f*cker :D

**** dregatux is still a big dirty/alpha/crapcode/hell POC ****

I've only tested it in last Debian & last Ubuntu. Look my github for news.

Deps (Debian/Ubuntu):
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
sudo apt-get install build-essential linux-headers-`uname -r`
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Just for your information, my crappy-way to build a call gate for x86_64:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
#pragma pack(push, 1)
typedef struct
{
    uint16_t offset_0_15;
    uint16_t selector;
    uint8_t  zeroes;
    uint8_t  type : 4;
    uint8_t  zero : 1;
    uint8_t  dpl : 2;
    uint8_t  p : 1;
    uint16_t offset_16_31;
    uint32_t offset_31_63;
    uint32_t reserved : 8;
    uint32_t type2 : 4;
    uint32_t reserved2 : 20;

} CALL_GATE64_t;
#pragma pack(pop)

#define I386_CALL_GATE_TYPE 0xC
#define X64_CALL_GATE_TYPE  I386_CALL_GATE_TYPE

CALL_GATE64_t build_call_gate64(uintptr_t addr, uint16_t selector)
{
    CALL_GATE64_t call_gate = {0}; // IMPORTANT?! ;-D
                    // shhh I know... just things to catch copy-pasters ;-)
    call_gate.offset_0_15  = (uint16_t)(addr & 0x000000000000FFFF);
    call_gate.offset_16_31 = (uint16_t)((addr >> 16) & 0x000000000000FFFF);
    call_gate.offset_31_63 = (uint32_t)((addr >> 32) & 0x00000000FFFFFFFF);
    call_gate.dpl          = 0x3; // RING3
    call_gate.type         = X64_CALL_GATE_TYPE;
    call_gate.p            = 1;
    call_gate.selector     = selector; //RING0? :D

    return call_gate;
}
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


------[  Bochs instrumentation for dregatux (Linux x86_64)

Sources: dregate\bochs\bochs-dregatux

It's like my cgateloop instrumentation but for 64 bits + dregatux.

My dregatux Bochs instrumentation detects when interrupts happens between:

CALL FAR <---> RETFQ/IRETQ

It will then break into the debugger for inspection (it also prints some
useful contextual information)

Example of use (race condition):

1. Copy dregatux project to a "Debian 5.10.136-1 (2022-08-13) x86_64"
Bochs machine (MUST use only 1 core). Install dregatux deps (listed in
previous chapter).

2. Copy Linux Bochs machine to Bochs-dregatux\linux.img

3. Run Bochs-dregatux\Bochs.bat

This runs my own Bochs version (for a x64 Windows host) with debugger
support + dregatux instrumentation

when Debugger breaks on Start just type: c

4. Run (as root):
""""""""""""""""""""""""""""""
./dregatux.sh -loopcrash
""""""""""""""""""""""""""""""

5. Wait for the Bochs Debugger to break

Wait a few secs and... if you continue execution after Debug break:
A kernel panic in your face! Indy enjoy this moment

-

To check my stable-call-gate-thing for 64 bit Linux, follow the same steps
but execute dregatux.sh script without args:
""""""""""""""""""""""""""""""
./dregatux.sh
""""""""""""""""""""""""""""""

And... Wait forever the Bochs Debugger will not break, it's stable with 0
race conditions (100% safe) :D

my tools for Linux kernel debugging on Bochs (including symbols, native
Bochs debugger and IDA PRO, notes...):

https://github.com/therealdreg/bochs_linux_kernel_debugging

WARNING: IDA PRO Local Bochs Debugger + own Bochs instrumentation can have
problems. So, you should use Bochs Native Debugger.

btw, Bochs 2.7 Native debugger dont show correct info when process 64 bit
entries on GDT (long mode). I fixed this on Master, but there is not a new
release yet (Aug 2022). So, just use 2.7 buggy or clone + compile the last
master from:

https://github.com/bochs-emu/Bochs


------[  The end

WARNING: It is possible that there is some stupid mistake, I am a clueless

Sorry for my English,

Thanks to all the sites/people who inspire me:

Gynvael, j00ru, Indy, Cr4sh, GriYo, Yago Jesus, EP_X0FF, tandasat, homs,
Fyyre, Jorge Valencia, micronn, Silvio Cesare, richinseattle, PAX Team, DS,
openwall, Bill Blunden, Brad Spangler, avrfreaks, shearer, David Melendez,
Hector Martin, Pavel Yosifovich, Paul Stoffregen, hugsy, pancake, mrexodia,
mrfearless, Axel Souchet, d00rt, skuater, Gadix (TheMida), ReWolf, R136a1,
Ruben Santamarta, thepope, Omar Rodriguez Soto, 48bits, !dSR, Uninformed,
Phrack, blackngel, Overdrive, Alex Ionescu, Mark Russinovich, 29a, WkT!, L,
openrce, arteam, Yarden Shafir, Joxean Koret, tarako, romansoft, jpalanco,
Jusepe, at4r, raise, Dmitry vostokov, Crg, Fermin J Serna, Bochs, OSR, dab,
pluf, sha0, rootedcon: Roman Ramirez, Arantxa Sanz, chencho, omarbv, snurf,
Angel Prado Montes, osdev, Gonzalo Batchdrake, Panda: danigargu, arrizen...

Big thanks to (my boss) Luis Fernando Regel Ruiz for his infinite patience.
My productivity is not the best (health issues) ;-D

#virus, #crackers & #hackers IRC-HISPANO (2000 era)

I always leave someone, bad luck :-(

feedback are welcome and don't be polite!


<<<< last words
EP_X0FF, Please, come back to Twitter! We miss you :-(

<<<<
Btw, is the current community full of assholes or is it just my feeling?
Authoritative, political correctness and fanatics of any kind everywhere.

<<<<
Some @vxunderground monkeys tagging my company on Twitter to make me fire
because I sound rude/condescending! Lol, I love these justice warriors.

<<<<
@hasherezade is still looking for an omnipresent kernel32.dll, maybe the
@rizinorg clowns can help her x-)

<<<<
Finally, the biggest shit I've ever read in my life:
Maximum Security in Windows: Technical Secrets ISBN: 978-84-09-14089-3
by Sergio de los Santos @ssantosv. But it works very well as a toilet paper
-

Dear reader, If my tone sounds you rude/condescending/aggressive then
f**k off! :D

Thx for watching, see u in next.

Sincerely, Dreg


------[  Some References

- Intel 64 and IA-32 Architectures Software Developer's Manual Combined
Volumes: 1, 2A, 2B, 2C, 2D, 3A, 3B, 3C, 3D, and 4

- Windows 2003 source code leak, WRK, CRK ...

- Undocumented Windows NT book by Prasad Dabak, Sandeep Phadke &
Milind Borate

- Windows Kernel Programming book by Pavel Yosifovich

- Windows Internals books by Mark Russinovich, David A. Solomon & others

- (book) The Rootkit Arsenal 2nd by Bill Blunden

- (book) What Makes It Page?: The Windows 7 (x64) Virtual Memory Manager by
Enrico Martignetti

- Linux kernel source code, Linux kernel mailing list & lwn.net

- osdev (community for those people interested in OS development)

- random github/gist, OSR, phrack, uninformed, openrce, kernelmode,
rootkit.com, arteam...

- internet?? xD, I always leave someone :(
```
