#ifndef stack_h
#define stack_h

#include "quads.h"

typedef struct stack
{
    char *name;
    int scope;
    int startLabel;
    struct stack *next, *prev;
} *stack_T;

/*this will store offsets as we enter different function definitions*/
typedef struct offset_stack
{
    int offset;
    struct offset_stack *next, *prev;
} *offset_stack_T;


//in file stack.c
int isLoopStackEmpty();

int isBreakListEmpty();

int isContListEmpty();

void push_loop();

void breakPush(int quadNum);

void contPush(int quadNum);

loopStack* pop_loop();


void push_func(char *name, int scope, int startLabel);

stack_T pop_func();



void offset_push(int offset);

offset_stack_T offset_pop();

void offset_free_stack();

/*void free_stacks(); shouldn't be needed because at the end of the program all stacks should be popped*/

#endif