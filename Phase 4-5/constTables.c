#include "constTables.h"

int totalNumSize;
int totalStringSize;
int totalLibFuncSize;
int totalUserFuncSize;
int totalInstrSize;

double*	numConsts;
unsigned int totalNumConsts;

char** stringConsts;
unsigned int totalStringConsts;

char** namedLibFuncs;
unsigned int totalNamedLibFuncs;

userfunc* userFuncs;
unsigned int totalUserFuncs;

instruction* instructions;
unsigned int totalInstructions; 

void EXPANDER (TYPER type) 
{
	switch(type)
    {
		case NUMBER_T:
                assert(totalNumConsts == totalNumSize);

                double* p = (double*) malloc (NEW_SIZE_NUM);

                if(numConsts)
				{
                    memcpy(p, numConsts, CURR_SIZE_NUM);	//realloc?
                    free(numConsts);
                }
                numConsts = p;
                totalNumSize += EXPAND_SIZE;
                break;

		case STRING_T:
                assert(totalStringConsts == totalStringSize);

                char** p1 = (char**) malloc (NEW_SIZE_STR);

                if(stringConsts)
				{
                    memcpy(p1, stringConsts, CURR_SIZE_STR);
                    free(stringConsts);
                }
                stringConsts = p1;
                totalStringSize += EXPAND_SIZE;
                break;

		case LIBFUNC_T:
                assert(totalLibFuncSize == totalNamedLibFuncs);

                char** p2 = (char**) malloc (NEW_SIZE_LIBFUNC);

                if(namedLibFuncs)
				{
                    memcpy(p2, namedLibFuncs, CURR_SIZE_LIBFUNC);
                    free(namedLibFuncs);
                }
                namedLibFuncs = p2;
                totalLibFuncSize += EXPAND_SIZE;
                break;

		case USERFUNC_T:
                assert(totalUserFuncs == totalUserFuncSize);

                userfunc* p3 = (userfunc*) malloc (NEW_SIZE_USERFUNC);

                if(userFuncs)
				{
                    memcpy(p3, userFuncs, CURR_SIZE_USERFUNC);
                    free(userFuncs);
                }
                userFuncs = p3;
                totalUserFuncSize += EXPAND_SIZE;
                break;

		case INSTRUCT_T:
                assert(totalInstructions == totalInstrSize);

                instruction* p4 = (instruction*) malloc (NEW_SIZE_INSTR_ARR);

                if(instructions)
				{
                    memcpy(p4, instructions, CURR_SIZE_INSTR_ARR);
                    free(instructions);
                }
                instructions = p4;
                totalInstrSize += EXPAND_SIZE;
                break;

		default : 		
            assert(0);
	}
}

int INSERT_NUM (double val) 
{
	int i, position; 
    
    for(i = 0; i < totalNumConsts; i++)
    { 
        if(numConsts[i] == val)
        { 
            return i;
        } 
    }

	if (totalNumSize == totalNumConsts)
		EXPANDER(NUMBER_T); 

	position = totalNumConsts;

	numConsts[totalNumConsts++]	= val;

	return position;
}

int INSERT_STRING (char* val) 
{
	int i, position; 
	
	for(i = 0; i < totalStringConsts; i++)
	{
		if(strcmp(stringConsts[i], val) == 0)
		{
			return i;
		} 
	}

	if (totalStringSize == totalStringConsts)
		EXPANDER(STRING_T); 

	position = totalStringConsts;

	stringConsts[totalStringConsts++] = (char*) strdup(val);

	return position;
}

int INSERT_LIBFUNC (char* val)
{
	int i = 0, position; 
	
	for(i = 0; i < totalNamedLibFuncs; i++)
	{
		if(strcmp(namedLibFuncs[i],val) == 0)
		{
			return i;
		}
	}

	if (totalLibFuncSize == totalNamedLibFuncs)
		EXPANDER(LIBFUNC_T); 

	position = totalNamedLibFuncs;

	namedLibFuncs[totalNamedLibFuncs++]	= (char*) strdup(val);

	return position;
}

int INSERT_USERFUNC (unsigned int address, unsigned int localSize, unsigned int totalargs, char* id)
{
	int i, position; 

	for(i = 0; i < totalUserFuncs; i++)
	{ 
		if(strcmp(userFuncs[i].id, id) == 0 && userFuncs[i].address == address)
		{
			 return i;
		} 
	}

	if(totalUserFuncSize == totalUserFuncs)
		EXPANDER(USERFUNC_T);

	position = totalUserFuncs;

	userfunc* p = userFuncs + totalUserFuncs++;

	p -> address = address;
	p -> localSize = localSize;
	p -> totalargs = totalargs;
	p -> id = id;
	
	return position;

}

int emitInstr (instruction t)
{
	if(totalInstrSize == totalInstructions)
		EXPANDER(INSTRUCT_T);

	int position = totalInstructions;

	instruction* p = instructions + totalInstructions++;
	
	p -> opcode = t.opcode;
	p -> result = t.result;
	p -> arg1 = t.arg1;
	p -> arg2 = t.arg2;
	p -> srcLine = t.srcLine;

	return totalInstructions;
}

void PRINT_NUM(void)
{
	int i = 0;

	printf(ANSI_COLOR_RED"PINAKAS ARITHMITIKON STATHERON"ANSI_COLOR_RESET"\n");
	for(i = 0; i < totalNumConsts; i++)
	{
		printf("[%d] %lf\n", i, numConsts[i]);
	}
	printf("\n");
} 

void PRINT_STR(void)
{
	int i = 0;

	printf(ANSI_COLOR_RED"PINAKAS STATHERON STRINGS"ANSI_COLOR_RESET"\n");
	for(i = 0; i < totalStringConsts; i++)
	{
		printf("[%d] %s\n", i, stringConsts[i]);
	}
	printf("\n");
}

void PRINT_USERFUNC(void)
{
	int i = 0;

	printf(ANSI_COLOR_RED"PINAKAS SUNARTISEWN XRHSTH"ANSI_COLOR_RESET"\n");
	for(i = 0; i < totalUserFuncs; i++)
	{
		printf("[%d] address %d, localSize %d, id %s\n", i, userFuncs[i].address, userFuncs[i].localSize, userFuncs[i].id);
	}
	printf("\n");
}

void PRINT_LIB(void)
{
	int i = 0;

	printf(ANSI_COLOR_RED"PINAKAS SUNARTISEWN BIBLIOTHIKIS"ANSI_COLOR_RESET"\n");
	for(i = 0; i < totalNamedLibFuncs; i++)
	{
		printf("[%d] %s\n", i, namedLibFuncs[i]);
	}
	printf("\n");
}