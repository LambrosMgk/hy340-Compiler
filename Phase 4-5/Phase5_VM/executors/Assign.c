#include "Dispatcher.h"

void execute_assign(instruction* instr)
{
	avm_memcell* lv = avm_translate_operand(&instr->result, (avm_memcell*) 0);
	avm_memcell* rv = avm_translate_operand(&instr->arg1, &ax);
	
	if(!(lv && (&stack[AVM_STACKSIZE-1] >= lv && lv > &stack[top] || lv == &retval)))
	{
		avm_print_error("Error in execute assign : bad lv pointer", NULL, NULL);
	}
	assert(rv);

	avm_assign(lv, rv);
}