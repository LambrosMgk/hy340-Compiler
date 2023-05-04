#include "stack.h"

stack_T loop_stack = NULL;

void push_loop(char *name, int scope)
{
    stack_T elem = (stack_T) malloc(sizeof(struct stack));

    if(elem == NULL)
    {
        fprintf(stderr, "Error with malloc in func_stack.c : push()\n");
        exit(-1);
    }
    
    if(name == NULL)
        elem->name = NULL;
    else
        elem->name = strdup(name);
    elem->scope = scope;
    elem->next = NULL;
    elem->prev = NULL;


    if(loop_stack == NULL)
        loop_stack = elem;
    else
    {
        loop_stack->next = elem;
        elem->prev = loop_stack;
        loop_stack = elem;
    }
}

stack_T pop_loop()
{
    stack_T tmp = NULL;
    if(loop_stack == NULL)
        return NULL;

    tmp = loop_stack;
    loop_stack = loop_stack->prev;

    return tmp;
}