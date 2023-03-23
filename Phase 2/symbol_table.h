#ifndef symbol_table_h
#define symbol_table_h

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*0 library functions, 1 global var(scope 0), 2 arguments, 3 local vars (scope >= 0) not arguments, 4 user functions*/
enum SymbolCategory {library_function, global_var, func_arg, local_var, user_func};

typedef struct symbol_
{
    char * varName;
    enum SymbolCategory category;
    int active, scope, line;
    struct symbol_ *nextSym;
} symbol, *symbol_T;

int is_lib_func(char *funcName);

void init_symbol_table();

symbol_T getElement(char *name, int scope);

symbol_T search_from_scope_out(char *name, int scope);

symbol_T addSymbol(char * varName, enum SymbolCategory category, int scope, int line);

symbol_T add_anonymus_func(int scope, int line);

void print_symbol_table();

void hide_in_scope(int scope);

#endif