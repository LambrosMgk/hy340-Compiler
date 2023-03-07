#ifndef symbol_table_h
#define symbol_table_h

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct symbol_
{
    char * varName;
    int category;   /*0 library functions, 1 global var(scope 0), 2 arguments,
    3 local vars (scope >= 0) not arguments, 4 user functions*/
    int active, scope, line;
    struct symbol_ *nextSym, *nextSublist;
} symbol, *symbol_T;

int is_lib_func(char *funcName);

void init_symbol_table();

symbol_T getElement(char *name, int scope);

symbol_T addElement(char * varName, int category, int scope, int line);

symbol_T add_anonymus_func(int scope, int line);

void print_symbol_table();

void hide_in_scope(int scope);

#endif