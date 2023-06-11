#ifndef Dispatcher_h
#define Dispatcher_h

#define _GNU_SOURCE
#include "../phase5.h"

#define ANSI_COLOR_RED      "\x1b[31m"
#define ANSI_COLOR_GREEN   "\x1b[32m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_RESET "\033[0m"

void execute_cycle(void);

typedef void (*execute_func_t) (instruction*);
#define  AVM_MAX_INSTRUCTIONS 	20
 
#define execute_add execute_arithmetic
#define execute_sub execute_arithmetic
#define execute_mul execute_arithmetic
#define execute_div execute_arithmetic
#define execute_mod execute_arithmetic

#define execute_jle execute_comparison
#define execute_jge execute_comparison
#define execute_jgt execute_comparison
#define execute_jlt execute_comparison

void execute_add				(instruction* instr); 
void execute_sub				(instruction* instr);
void execute_mul				(instruction* instr);
void execute_div				(instruction* instr);
void execute_mod				(instruction* instr);
void execute_assign				(instruction* instr);
void execute_call				(instruction* instr);
void execute_pusharg			(instruction* instr);
void execute_funcenter			(instruction* instr);
void execute_funcexit			(instruction* instr);
void execute_jeq				(instruction* instr);
void execute_jne				(instruction* instr);
void execute_jle				(instruction* instr);
void execute_jge				(instruction* instr); 
void execute_jlt				(instruction* instr);
void execute_jgt				(instruction* instr);
void execute_newtable			(instruction* instr);
void execute_tablegetelem		(instruction* instr);
void execute_tablesetelem		(instruction* instr);
void execute_nop				(instruction* instr);
void execute_jump				(instruction* instr);

void execute_arithmetic			(instruction* instr);

void execute_comparison			(instruction* instr);

#endif