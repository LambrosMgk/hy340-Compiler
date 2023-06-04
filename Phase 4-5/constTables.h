#ifndef constTables_h
#define constTables_h

#include "targetCode.h"

#define EXPAND_SIZE 		1024

#define CURR_SIZE_NUM (totalNumConsts * sizeof(double))
#define NEW_SIZE_NUM (EXPAND_SIZE * sizeof(double) + CURR_SIZE_NUM)

#define CURR_SIZE_STR (totalStringConsts * sizeof(char*))
#define NEW_SIZE_STR (EXPAND_SIZE * sizeof(char*) + CURR_SIZE_STR)

#define CURR_SIZE_LIBFUNC (totalNamedLibFuncs * sizeof(char*))
#define NEW_SIZE_LIBFUNC (EXPAND_SIZE * sizeof(char*) + CURR_SIZE_LIBFUNC)

#define CURR_SIZE_USERFUNC (totalUserFuncs * sizeof(userfunc))
#define NEW_SIZE_USERFUNC (EXPAND_SIZE * sizeof(userfunc) + CURR_SIZE_USERFUNC)

#define CURR_SIZE_INSTR_ARR	(totalInstrSize * sizeof(instruction))
#define NEW_SIZE_INSTR_ARR	(EXPAND_SIZE * sizeof(instruction) + CURR_SIZE_INSTR_ARR)

typedef enum TYPER { NUMBER_T, STRING_T, LIBFUNC_T, USERFUNC_T, INSTRUCT_T} TYPER;

extern int totalNumSize;
extern int totalStringSize;
extern int totalLibFuncSize;
extern int totalUserFuncSize;
extern int totalInstrSize;

void EXPANDER (TYPER type);

int INSERT_NUM (double val);
int INSERT_STRING (char* val);
int INSERT_LIBFUNC (char* val);
int INSERT_USERFUNC (unsigned int address, unsigned int localSize, unsigned int totalargs, char* id); 

int emitInstr(instruction t);

void PRINT_USERFUNC();
void PRINT_STR();
void PRINT_NUM();
void PRINT_LIB();

#endif