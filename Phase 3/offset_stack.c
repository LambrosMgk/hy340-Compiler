#include "offset_stack.h"

offset_stack_T offset_stack_head = NULL;
int offset_stack_size = 0;

void offset_push(int offset)
{
    offset_stack_T elem = malloc(sizeof(struct offset_stack));

    if(elem == NULL)
    {
        fprintf(stderr, "Erro with malloc in func_stack.c : push()\n");
        exit(-1);
    }
    
    elem->offset = offset;
    elem->next = NULL;
    elem->prev = NULL;

    offset_stack_size++;
    if(offset_stack_head == NULL)
        offset_stack_head = elem;
    else
    {
        offset_stack_head->next = elem;
        elem->prev = offset_stack_head;
        offset_stack_head = elem;
    }
}

offset_stack_T offset_pop()
{
    offset_stack_T tmp = NULL;
    if(offset_stack_size == 0)
        return NULL;

    offset_stack_size--;
    tmp = offset_stack_head;
    offset_stack_head = offset_stack_head->prev;

    return tmp;
}

void offset_free_stack()
{
    offset_stack_T tmp = offset_stack_head;
    while(offset_stack_head != NULL)
    {
        tmp = offset_stack_head;
        offset_stack_head = offset_stack_head->prev;
        free(tmp);
        offset_stack_size--;
    }
}
