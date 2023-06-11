#ifndef phase5_h
#define phase5_h

#include "MemoryMan.h"

#define AVM_STACKENV_SIZE 4

extern avm_memcell ax, bx, cx;
extern avm_memcell retval;
extern unsigned int top, topsp;

extern unsigned char	executionFinished;
extern unsigned int 	pc;
extern unsigned int 	currLine;

extern double* numConstsTable;
extern unsigned int totalNumConsts;

extern char** strConstsTable;
extern unsigned int totalStrConsts;

extern char** libFuncsTable;
extern unsigned int totalLibFuncs;

extern userfunc* userFuncsTable;
extern unsigned int totalUserFuncs;

extern instruction* code;
extern unsigned int codeSize;

#define AVM_ENDING_PC codeSize

avm_memcell* avm_translate_operand(vmarg* arg, avm_memcell* reg);

double consts_getnumber(unsigned int index);
char*  consts_getstring(unsigned int index);
char*  libfuncs_getfunc(unsigned int index);

void initPhase5(void);

#endif