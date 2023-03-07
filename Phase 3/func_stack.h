#ifndef func_stack_h
#define func_stack_h

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*this will store function symbols as the parser reads the function definitions 
to determine the visibility of variables*/

typedef struct stack
{
    char *name;
    int scope;  /*scope of func definition*/
    struct stack *next, *prev;
} *stack_T;

void func_push(char *name, int scope);

stack_T func_pop();

void func_free_stack();

#endif