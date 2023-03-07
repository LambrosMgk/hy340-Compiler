#ifndef symbol_table_h
#define symbol_table_h

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum scopespace_t { programmVar, functionLocal, formalArg };

typedef struct symbol_  /*maybe add a type*/
{
    char * varName;
    int category;   /*0 library functions, 1 global var(scope 0), 2 arguments,
    3 local vars (scope >= 0) not arguments, 4 user functions*/
    int active, scope, line, offset;
    enum scopespace_t space;
    struct symbol_ *nextSym, *nextSublist;  /*nextSym takes you to the next symbol(varName is different)
    and nextSublist hold the sublist of symbols with the same name ordered by decrementing scope*/
} symbol, *symbol_T;

int is_lib_func(char *funcName);

void init_symbol_table();

symbol_T search_from_scope_out(char *name, int scope);

symbol_T getElement(char *name, int scope);

symbol_T addElement(char * varName, int category, int scope, int line, int offset, enum scopespace_t space);

symbol_T add_anonymus_func(int scope, int line, int offset, enum scopespace_t space);

void print_symbol_table();

void hide_in_scope(int scope);

#endif