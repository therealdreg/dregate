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


#include <assert.h>

#include "bochs.h"
#include "cpu/cpu.h"

// maximum size of an instruction
#define MAX_OPCODE_LENGTH 16

// maximum physical addresses an instruction can generate
#define MAX_DATA_ACCESSES 1024

#define NDBG

// Use this variable to turn on/off collection of instrumentation data
// If you are not using the debugger to turn this on/off, then possibly
// start this at 1 instead of 0.
static bool active = 1;


static unsigned int next_ins_after_call_far = 0;
static bool call_far_join = false;
static bool ret_join_addr = 0;
static bool callfaraddr_printed = false;
static bx_address last_ret_join_addr = 0;
static bx_address last_call_far_join_addr = 0;
static bool tidt[0x200];


static struct instruction_t {
  bool  ready;         // is current instruction ready to be printed
  unsigned opcode_length;
  Bit8u    opcode[MAX_OPCODE_LENGTH];
  bool  is32, is64;
  unsigned num_data_accesses;
  struct {
    bx_address laddr;     // linear address
    bx_phy_address paddr; // physical address
    unsigned rw;          // BX_READ, BX_WRITE or BX_RW
    unsigned size;        // 1 .. 64
    unsigned memtype;
  } data_access[MAX_DATA_ACCESSES];
  bool is_branch;
  bool is_taken;
  bx_address target_linear;
  bx_address rip;
  bx_address rsp;
} *instruction;

static logfunctions *instrument_log = new logfunctions ();
#define LOG_THIS instrument_log->

void bx_instr_init_env(void) {}
void bx_instr_exit_env(void) {}

void bx_instr_initialize(unsigned cpu)
{
  assert(cpu < BX_SMP_PROCESSORS);

  if (instruction == NULL)
      instruction = new struct instruction_t[BX_SMP_PROCESSORS];

  fprintf(stderr, "instrument for dregatux by Dreg https://github.com/therealdreg/dregate (only works with 1 cpu 1 core)... cpu %u\n", cpu);
}

void bx_instr_reset(unsigned cpu, unsigned type)
{
  memset(tidt, 0, sizeof(tidt));
  instruction[cpu].ready = 0;
  instruction[cpu].num_data_accesses = 0;
  instruction[cpu].is_branch = 0;
  next_ins_after_call_far = 0;
  call_far_join = false;
  ret_join_addr = false;
  callfaraddr_printed = false;
  last_ret_join_addr = 0;
  last_call_far_join_addr = 0;
}


void bx_forceprint_instruction(unsigned cpu, const instruction_t *i)
{
  char disasm_tbuf[512];	// buffer for instruction disassembly
  unsigned length = i->opcode_length, n;
  bx_dbg_disasm_wrapper(i->is32, i->is64, 0, 0, i->opcode, disasm_tbuf);

  if(length != 0)
  {
    fprintf(stderr, "----------------------------------------------------------\n");
    fprintf(stderr, "CPU %u: %s\n", cpu, disasm_tbuf);
    fprintf(stderr, "rip -> 0x" FMT_ADDRX " - rsp -> 0x" FMT_ADDRX "\n", i->rip, i->rsp);
    fprintf(stderr, "LEN %u\tBYTES: ", length);
    for(n=0;n < length;n++) fprintf(stderr, "%02x", i->opcode[n]);
    if(i->is_branch)
    {
      fprintf(stderr, "\tBRANCH ");

      if(i->is_taken)
        fprintf(stderr, "TARGET " FMT_ADDRX " (TAKEN)", i->target_linear);
      else
        fprintf(stderr, "(NOT TAKEN)");
    }
    fprintf(stderr, "\n");
    for(n=0;n < i->num_data_accesses;n++)
    {
      fprintf(stderr, "MEM ACCESS[%u]: 0x" FMT_ADDRX " (linear) 0x" FMT_PHY_ADDRX " (physical) %s SIZE: %d\n", n,
                    i->data_access[n].laddr,
                    i->data_access[n].paddr,
                    i->data_access[n].rw == BX_READ ? "RD":"WR",
                    i->data_access[n].size);
    }
    fprintf(stderr, "\n");
  }
}

void bx_print_instruction(unsigned cpu, const instruction_t *i)
{
	#ifdef NDBG
	return;
	#endif
  bx_forceprint_instruction(cpu, i);
}


void bx_instr_before_execution(unsigned cpu, bxInstruction_c *bx_instr)
{
  static unsigned char call_far_sig[] = { 0x48, 0xff, 0x1f };
  static unsigned char iretq_sig[] = { 0x48, 0xcf };
  static unsigned char retfq_sig[] = { 0x48, 0xca, 0x00, 0x00 };
  instruction_t *i = &instruction[cpu];
  static unsigned int call_times = 0;
  static unsigned int j = 0;
  bool breakn = false;
  
  if (!active) return;
  
  if (!call_far_join && bx_instr->ilen() == sizeof(call_far_sig))
  {
	  if (memcmp(bx_instr->get_opcode_bytes(), call_far_sig, sizeof(call_far_sig)) == 0)
	  {
      if (last_call_far_join_addr != BX_CPU(cpu)->gen_reg[BX_64BIT_REG_RIP].rrx)
      {
        next_ins_after_call_far = 0;
        callfaraddr_printed = 0;
        call_times = 0;
        last_call_far_join_addr = BX_CPU(cpu)->gen_reg[BX_64BIT_REG_RIP].rrx;
        breakn = true;
        last_ret_join_addr = 0;
      }
		  if (call_times++ % 5000 == 0)
		  {
			  fprintf(stderr, "same call far executed 5000 times(x %u) addr: 0x" FMT_ADDRX " last_ret_join_addr: 0x" FMT_ADDRX "\n", j++, BX_CPU(cpu)->gen_reg[BX_64BIT_REG_RIP].rrx, last_ret_join_addr);
		  }
		  #ifndef NDBG
		  fprintf(stderr, "call far execution\n");
		  #endif
		  call_far_join = true;
      last_call_far_join_addr = BX_CPU(cpu)->gen_reg[BX_64BIT_REG_RIP].rrx;
	  }
  }
  else if (call_far_join && (bx_instr->ilen() == sizeof(iretq_sig) || bx_instr->ilen() == sizeof(retfq_sig)))
  {
	  if (memcmp(bx_instr->get_opcode_bytes(), iretq_sig, sizeof(iretq_sig)) == 0
        || memcmp(bx_instr->get_opcode_bytes(), retfq_sig, sizeof(retfq_sig)) == 0)
	  {
		  #ifndef NDBG
		  fprintf(stderr, "iretq or retfq execution\n");
		  #endif
		  call_far_join = false;
		  ret_join_addr = true;
		  if (last_ret_join_addr != BX_CPU(cpu)->gen_reg[BX_64BIT_REG_RIP].rrx)
		  {
			  last_ret_join_addr = BX_CPU(cpu)->gen_reg[BX_64BIT_REG_RIP].rrx;
			  fprintf(stderr, "iretq/retfq addr: 0x" FMT_ADDRX "\n", BX_CPU(cpu)->gen_reg[BX_64BIT_REG_RIP].rrx);
			  fprintf(stderr, "trace will not be shown again if ret addr is the same\n");
		  }
	  }
  }

  if (call_far_join || ret_join_addr)
  {
	  if (i->ready) bx_print_instruction(cpu, i);

	  // prepare instruction_t structure for new instruction
	  i->ready = 1;
	  i->num_data_accesses = 0;
	  i->is_branch = 0;
    i->rip = BX_CPU(cpu)->gen_reg[BX_64BIT_REG_RIP].rrx;
    i->rsp =  BX_CPU(cpu)->gen_reg[BX_64BIT_REG_RSP].rrx;
	  i->is32 = BX_CPU(cpu)->sregs[BX_SEG_REG_CS].cache.u.segment.d_b;
	  i->is64 = BX_CPU(cpu)->long64_mode();
	  i->opcode_length = bx_instr->ilen();
	  memcpy(i->opcode, bx_instr->get_opcode_bytes(), i->opcode_length);
	  if (next_ins_after_call_far > 0 && next_ins_after_call_far < 10)
	  {
		  bx_forceprint_instruction(cpu, i);
		  next_ins_after_call_far++;
		  if (next_ins_after_call_far == 10)
		  {
			  fprintf(stderr, "....\n\n");
		  }
	  }
	  if (!callfaraddr_printed)
	  {
		  next_ins_after_call_far++;
		  callfaraddr_printed = true;
		  fprintf(stderr, "call far addr: 0x" FMT_ADDRX "\n", i->rip);
		  bx_forceprint_instruction(cpu, i);
	  }
  }

  if (breakn)
  {
    //bx_debug_break();
  }
}

void bx_instr_after_execution(unsigned cpu, bxInstruction_c *bx_instr)
{
  if (!active) return;
  
  if (call_far_join || ret_join_addr)
  {
	if (ret_join_addr) 
	{
	  ret_join_addr = false;
	}
	instruction_t *i = &instruction[cpu];
	if (i->ready) 
	{
		bx_print_instruction(cpu, i);
		i->ready = 0;
	}
  }
}

static void branch_taken(unsigned cpu, bx_address new_eip)
{
  if (!active || !instruction[cpu].ready) return;

  instruction[cpu].is_branch = 1;
  instruction[cpu].is_taken = 1;

  // find linear address
  instruction[cpu].target_linear = BX_CPU(cpu)->get_laddr(BX_SEG_REG_CS, new_eip);
}

void bx_instr_cnear_branch_taken(unsigned cpu, bx_address branch_eip, bx_address new_eip)
{
	if (call_far_join)
	{
		branch_taken(cpu, new_eip);
	}
}

void bx_instr_cnear_branch_not_taken(unsigned cpu, bx_address branch_eip)
{
  if (!active || !instruction[cpu].ready) return;

  if (call_far_join)
  {
	instruction[cpu].is_branch = 1;
	instruction[cpu].is_taken = 0;
  }
}

void bx_instr_ucnear_branch(unsigned cpu, unsigned what, bx_address branch_eip, bx_address new_eip)
{
  if (call_far_join)
  {
	branch_taken(cpu, new_eip);
  }
}

void bx_instr_far_branch(unsigned cpu, unsigned what, Bit16u prev_cs, bx_address prev_eip, Bit16u new_cs, bx_address new_eip)
{
  if (call_far_join)
  {
	branch_taken(cpu, new_eip);
  }
}

void bx_instr_interrupt(unsigned cpu, unsigned vector)
{
  if(!active)
  {
	  return;
  }
  
  if (call_far_join)
  {
	  #ifndef NDBG
    fprintf(stderr, "CPU %u: interrupt %02xh\n", cpu, vector);
	#endif
    if (vector != 1)
    {
       fprintf(stderr, "CPU %u: interrupt %02xh\n", cpu, vector);
        fprintf(stderr, "prev rip: 0x" FMT_ADDRX " prev rsp: 0x" FMT_ADDRX "\n", BX_CPU(cpu)->prev_rip, BX_CPU(cpu)->prev_rsp);
        fprintf(stderr, "prev instruction disas:\n");
        bx_dbg_disassemble_command(NULL, BX_CPU(cpu)->prev_rip, BX_CPU(cpu)->prev_rip);
        fprintf(stderr,  "curr rip -> 0x" FMT_ADDRX "\n",  BX_CPU(cpu)->gen_reg[BX_64BIT_REG_RIP].rrx);
        fprintf(stderr, "prev stack:\n");
        bx_dbg_print_stack_command(13);
        fprintf(stderr, "race happens :-(, type continue (this interrupt number will never break again)\n");
        call_far_join = false;
        ret_join_addr = false;
        if (!tidt[(unsigned char)vector])
        {
          fprintf(stderr, ", break!\n");
          tidt[(unsigned char)vector] = true;
          bx_debug_break();
        }
    }
  }
}

void bx_instr_exception(unsigned cpu, unsigned vector, unsigned error_code)
{
  if(!active)
  { 
	return;
  }
  if (call_far_join)
  {
	  #ifndef NDBG
    fprintf(stderr, "CPU %u: exception %02xh, error_code = %x\n", cpu, vector, error_code);
	#endif
  }
}

void bx_instr_hwinterrupt(unsigned cpu, unsigned vector, Bit16u cs, bx_address eip)
{
  if(!active)
  {
	  return;
  }
  if (call_far_join)
  {
    fprintf(stderr, "CPU %u: hardware interrupt %02xh\n", cpu, vector);
  }
}

void bx_instr_lin_access(unsigned cpu, bx_address lin, bx_phy_address phy, unsigned len, unsigned memtype, unsigned rw)
{
  if(!active || !instruction[cpu].ready) return;
  if (call_far_join)
  {
	  unsigned index = instruction[cpu].num_data_accesses;

	  if (index < MAX_DATA_ACCESSES) {
		instruction[cpu].data_access[index].laddr = lin;
		instruction[cpu].data_access[index].paddr = phy;
		instruction[cpu].data_access[index].rw    = rw;
		instruction[cpu].data_access[index].size  = len;
		instruction[cpu].data_access[index].memtype = memtype;
		instruction[cpu].num_data_accesses++;
		index++;
	  }
  }
}

void bx_instr_debug_promt()
{

}

void bx_instr_debug_cmd(const char *cmd)
{
  if (strcmp(cmd, "start") == 0)
  {
    fprintf(stderr, "starting :-)\n");
    active = true;
  }
  else if (strcmp(cmd, "stop") == 0)
  {
    fprintf(stderr, "stopping ...\n");
    active = false;
    bx_instr_reset(0, 0);
  }
  else
  {
    fprintf(stderr, "wrong command, wtf\n");
  }
}