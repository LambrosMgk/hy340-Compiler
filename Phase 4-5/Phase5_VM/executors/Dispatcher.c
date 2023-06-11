#include "Dispatcher.h"

execute_func_t	executeFuncs[] = {

	execute_assign,	
	execute_add,
	execute_sub,
	execute_mul,
	execute_div,
	execute_mod,
	execute_jump,
	execute_jeq,
	execute_jne,
	execute_jle,
	execute_jge,
	execute_jlt,
	execute_jgt,
	execute_call,
	execute_pusharg,
	execute_funcenter,
	execute_funcexit,
	execute_newtable,
	execute_tablegetelem,
	execute_tablesetelem,
	execute_nop

};


void execute_cycle(void)
{
	if(executionFinished)
		return;

	if(pc == AVM_ENDING_PC)
	{
		executionFinished = 1;
		return ;
	}
	else
	{
		assert(pc < AVM_ENDING_PC);
		instruction* instr = code + pc;
		unsigned int oldPC;

		if(!(instr->opcode >= 0 && instr->opcode <= AVM_MAX_INSTRUCTIONS))
		{
			printf(ANSI_COLOR_RED"Error in execute_cycle() : instruction opcode out of bounds"ANSI_COLOR_RESET"\n");
			exit(-1);
		}

		if(instr->srcLine)
			currLine = instr->srcLine;

		oldPC = pc;

		//printf("Executing opcode : %d\n", instr->opcode);
		(*executeFuncs[instr->opcode]) (instr);
		if(pc == oldPC)
			++pc;
	}
}