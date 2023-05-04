#ifndef stack_h
#define stack_h

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct stack
{
    char *name;
    int scope;
    struct stack *next, *prev;
} *stack_T;

void push_loop(char *name, int scope);

stack_T pop_loop();

/*void free_stacks(); shouldn't be needed because at the end of the program all stacks should be popped*/

#endif