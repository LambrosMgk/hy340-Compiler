#include "executors/Dispatcher.h"

avm_memcell ax, bx, cx;		//registers
avm_memcell retval;
unsigned int top, topsp;

unsigned char	executionFinished;
unsigned int 	pc;
unsigned int 	currLine;

double* numConstsTable;
unsigned int totalNumConsts;

char** strConstsTable;
unsigned int totalStrConsts;

char** libFuncsTable;
unsigned int totalLibFuncs;

userfunc* userFuncsTable;
unsigned int totalUserFuncs;

instruction* code;
unsigned int codeSize;

//antistoixish vmarg se memory cell
avm_memcell* avm_translate_operand(vmarg* arg, avm_memcell* reg)
{
	if(arg->type == -1 || arg->type == 11)
		return reg;
	
	switch(arg->type)
	{
		case global_a :	return &stack[AVM_STACKSIZE - 1 - arg->val];
		case local_a  :	return &stack[topsp - arg->val];
		case formal_a :	return &stack[topsp + AVM_STACKENV_SIZE + 1 + arg->val];

		case retval_a:	return &retval;

		case number_a:	{
							reg->type = number_m;
							reg->data.numVal = consts_getnumber(arg->val);
							return reg;
						}

		case string_a:	{
							reg->type = string_m;
							reg->data.strVal = strdup(consts_getstring(arg->val));
							return reg;
						}

		case bool_a:	{
							reg->type = bool_m;
							reg->data.boolVal = arg->val;
							return reg;
						}

		case nil_a:		reg->type = nil_m; return reg;

		case userfunc_a:	{

								reg->type = userfunc_m;
								userfunc* func = avm_getfuncinfo(arg->val);
								reg->data.funcVal = func->address;
								return reg;
							}

		case libfunc_a:		{	
								reg->type = libfunc_m;
								reg->data.libfuncVal = libfuncs_getfunc(arg->val);
								return reg;
							}

		default:			assert(0);
		}
}

double consts_getnumber(unsigned int index)
{
	assert(index >= 0 && index < totalNumConsts);
	return numConstsTable[index];
}

char* consts_getstring(unsigned int index)
{
	assert(index >= 0 && index < totalStrConsts);
	return strConstsTable[index];
}

char* libfuncs_getfunc(unsigned int index)
{
	assert(index >= 0 && index < totalLibFuncs);
	return libFuncsTable[index];
}

void initPhase5(void)
{
	executionFinished = 0;
	pc = 0;
	currLine = 0;
	top = AVM_STACKSIZE - 1 - totalGlobals;
}

int main(int argc, char **argv)
{
	char* customName = strdup("");
	int printFlag = 0, i = 1, customFlag = 0; 

	
	while(i <= argc && argv[i] != NULL)
	{
		
		if(strcmp(argv[i], "-i") == 0)
		{ 
			printf("| ------------------------------------------ |\n"); 
			printf("| Compiler by Magiakos Labros				 |\n"); 
			printf("| ------------------------------------------ |\n"); 
			printf("| Compiler for Alpha (still in alpha testing)|\n"); 
			printf("| ------------------------------------------ |\n"); 
		}
		if(strcmp(argv[i], "-p") == 0)
		{
			printFlag = 1; 
		}
		if(strcmp(argv[i], "-n") == 0)
		{
			strcat(customName,argv[i+1]);
			customFlag = 1;
		}

		i++;
	}

	if(customFlag == 0) 
	{
		strcat(customName, "AlphaCode.bin"); 
	}

	DataTables* tables;
	tables = decoder(printFlag, customName);

	numConstsTable = tables->numConstsTable;
	totalNumConsts = tables->totalNumConsts;

	strConstsTable = tables->strConstsTable;
	totalStrConsts = tables->totalStrConsts;

	libFuncsTable = tables->libFuncsTable;
	totalLibFuncs = tables->totalLibFuncs;

	userFuncsTable = tables->userFuncsTable;
	totalUserFuncs = tables->totalUserFuncs;

	code = tables->code;
	codeSize = tables->codeSize;

	initPhase5();
	avm_initialize();

	while(executionFinished == 0)
	{
		if(printFlag)
			printf("Executing instruction %d\n", pc);
		execute_cycle();
	}
}