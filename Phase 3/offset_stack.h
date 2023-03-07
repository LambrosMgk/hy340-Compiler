#ifndef offset_stack_h
#define offset_stack_h

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*this will store offsets as we enter different function definitions*/

typedef struct offset_stack
{
    int offset;
    struct offset_stack *next, *prev;
} *offset_stack_T;

void offset_push(int offset);

offset_stack_T offset_pop();

void offset_free_stack();

#endif