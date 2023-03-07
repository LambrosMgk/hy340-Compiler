#include "func_stack.h"

stack_T func_stack_head = NULL;
int func_stack_size = 0;

void func_push(char *name, int scope)
{
    stack_T elem = malloc(sizeof(struct stack));

    if(elem == NULL)
    {
        fprintf(stderr, "Error with malloc in func_stack.c : push()\n");
        exit(-1);
    }
    
    elem->name = strdup(name);
    elem->scope = scope;
    elem->next = NULL;
    elem->prev = NULL;

    func_stack_size++;
    if(func_stack_head == NULL)
        func_stack_head = elem;
    else
    {
        func_stack_head->next = elem;
        elem->prev = func_stack_head;
        func_stack_head = elem;
    }
}

stack_T func_pop()
{
    stack_T tmp = NULL;
    if(func_stack_size == 0)
        return NULL;

    func_stack_size--;
    tmp = func_stack_head;
    func_stack_head = func_stack_head->prev;

    return tmp;
}

void func_free_stack()
{
    stack_T tmp = func_stack_head;
    while(func_stack_head != NULL)
    {
        tmp = func_stack_head;
        func_stack_head = func_stack_head->prev;
        free(tmp);
        func_stack_size--;
    }
}
