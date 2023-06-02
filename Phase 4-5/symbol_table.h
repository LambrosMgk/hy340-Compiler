#ifndef symbol_table_h
#define symbol_table_h

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ANSI_COLOR_RED      "\x1b[31m"
#define ANSI_COLOR_GREEN   "\x1b[32m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_RESET "\033[0m"

#define ANSI_COLOR_RED_BACKGROUND     "\x1b[41m"
#define ANSI_COLOR_RESET_BACKGROUND   "\x1b[0m"

/*0 library functions, 1 global var(scope 0), 2 arguments, 3 local vars (scope >= 0) not arguments, 4 user functions*/
enum SymbolCategory {library_function, global_var, func_arg, local_var, user_func};

enum scopespace_t { programVar, functionLocal, formalArg };

typedef struct symbol_
{
    char * varName;
    enum SymbolCategory category;
    int active, scope, line, offset;
    enum scopespace_t space;
    struct symbol_ *nextSym;
} symbol, *symbol_T;

int is_lib_func(char *funcName);

void init_symbol_table();

symbol_T getElement(char *name, int scope);

symbol_T getActiveFunctionFromScopeOut(int scope);

symbol_T search_from_scope_out(char *name, int scope);

symbol_T addSymbol(char * varName, enum SymbolCategory category, int scope, int line, int offset, enum scopespace_t space);

symbol_T add_anonymus_func(int scope, int line, int offset, enum scopespace_t space);

void print_symbol_table();

void hide_in_scope(int scope);

#endif