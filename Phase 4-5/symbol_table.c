#include "symbol_table.h"

symbol_T *symbol_table = NULL;  /*2d array with rows representing scope and columns containing the symbol of each scope*/
unsigned int TotalScopes = 1;

char *lib_funcs[12] = {
    "print", "input", "objectmemberkeys", "objecttotalmembers",
    "objectcopy", "totalarguments", "argument", "typeof", "strtonum", "sqrt", "cos", "sin"};


/*returns 1 if the argument is a library function name, otherwise 0 */
int is_lib_func(char *funcName)
{
    for(int i = 0; i < 12; i++)
    {
        if(strcmp(lib_funcs[i], funcName) == 0)
            return 1;
    }

    return 0;
}

void init_lib_funcs()
{
    symbol_T elem = NULL, tmp = NULL;
    int i;

    if(symbol_table == NULL)
    {
        fprintf(stderr, "Error in init_lib_funcs(), symbol table is not initialized...\n");
        exit(-1);
    }
    

    tmp = symbol_table[0];
    for(i = 0; i < 12; i++)
    {
        elem = malloc(sizeof(symbol));
        if(elem == NULL)
        {
            fprintf(stderr, "Error in init_lib_funcs(), not enough memory...\n");
            exit(0);
        }

        elem->varName = strdup(lib_funcs[i]);   /*maybe no need for strdup? just assign pointer*/
        elem->category = library_function;
        elem->active = 1;
        elem->scope = 0;
        elem->line = 0;
        elem->totalargs = 0;
        elem->iaddress = 0;
        elem->totallocals = 0;
        elem->taddress = 0;
        elem->returnList = NULL;
        elem->nextSym = NULL;

        if(symbol_table[0] == NULL)
        {
            symbol_table[0] = elem;
            tmp = elem;
        }
        else
        {
            tmp->nextSym = elem;
            tmp = elem;
        }
    }
}

void init_symbol_table()
{
    symbol_table = (symbol_T *) malloc(TotalScopes * sizeof(symbol_T ));
    if(symbol_table == NULL)
    {
        fprintf(stderr, "Error : not enough memory to initialize symbol table. Exiting...\n");
    }
    symbol_table[0] = NULL; /*init memory*/
    init_lib_funcs();
}

/*returns the struct with varName == name and same scope, otherwise null*/
symbol_T getElement(char *name, int scope)
{
    symbol_T tmp = NULL, tmpSubList = NULL;

    if(TotalScopes < scope + 1) /*if the scope doesn't exist, e.g. : There are scopes 0, 1 and 2 and i ask for scope 3*/
        return NULL;

    tmp = symbol_table[scope];
    while(tmp != NULL && strcmp(tmp->varName, name) != 0)
    {
        tmp = tmp->nextSym;
    }

    return tmp;
}

/*the search is performed outwards starting from the given scope, returns the first to encounter active function symbol*/
symbol_T getActiveFunctionFromScopeOut(int scope)
{
    symbol_T tmp = NULL;
    int tmpscope = scope;

    if(TotalScopes < scope + 1)
    {
        tmpscope = TotalScopes-1;
    }

    
    while(tmpscope >= 0)
    {
        tmp = symbol_table[tmpscope];
        while(tmp != NULL && tmp->category != user_func)
        {
            tmp = tmp->nextSym;
        }
        if(tmp != NULL && tmp->category == user_func && tmp->active == 1)
            break;
        tmpscope--;
    }
    
    return tmp;
}

/*the search is performed outwards starting from the given scope, returns only active symbols*/
symbol_T search_from_scope_out(char *name, int scope)
{
    symbol_T tmp = NULL;
    int tmpscope = scope;

    if(TotalScopes < scope + 1)
    {
        tmpscope = TotalScopes-1;
    }

    
    while(tmpscope >= 0)
    {
        tmp = symbol_table[tmpscope];
        while(tmp != NULL && strcmp(tmp->varName, name) != 0)
        {
            tmp = tmp->nextSym;
        }
        if(tmp != NULL && strcmp(tmp->varName, name) == 0 && tmp->active == 1)
            break;
        tmpscope--;
    }
    
    return tmp;
}

/*on success return the pointer of the new symbol, otherwise NULL*/
/*isws spasto se addID kai addFunction?*/
symbol_T addSymbol(char * symbol_name, enum SymbolCategory category, int scope, int line, int offset, enum scopespace_t space)
{
    symbol_T elem = NULL, tmp = NULL, prev = NULL;
    int i = 0;


    if(is_lib_func(symbol_name) == 1)   /*if lib function then no need to add it again to the table*/
    {
        fprintf(stderr, ANSI_COLOR_RED"Syntax error in line <%d> : Shadowing of library functions is not allowed."ANSI_COLOR_RESET"\n", line);
        exit(-1);
    }
    if(symbol_table == NULL)
    {
        fprintf(stderr, "Error : Symbol table is not initialized.\n");
        exit(-1);
    }
    if(TotalScopes < scope+1) /*scope + 1 because if i call from syntax.y with scope 0 but that means there is a total of 1 scopes*/
    {
        /*e.g. Table is initialized for scope 0, i want to preserve order so i check the size of the array if previous scopes exist*/
        symbol_table = realloc(symbol_table, (scope + 1) * sizeof(symbol_T *));
        if(symbol_table == NULL)
        {
            fprintf(stderr, "Error : Realloc for symbol table failed.\n");
            exit(-1);
        }
        TotalScopes = scope + 1;
        /*printf("reallocated memory, Total scopes : %d\n", TotalScopes);*/
    }


    
    if(symbol_table[scope] == NULL)   /*first symbol in this scope*/
    {
        elem = malloc(sizeof(symbol));
        if(elem == NULL)
        {
            fprintf(stderr, "Error in addSymbol, not enough memory...\n");
            exit(0);
        }

        elem->varName = strdup(symbol_name);
        elem->category = category;
        elem->active = 1;
        elem->scope = scope;
        elem->line = line;
        elem->offset = offset;
        elem->space = space;
        elem->totalargs = 0;
        elem->iaddress = 0;
        elem->totallocals = 0;
        elem->taddress = 0;
        elem->returnList = NULL;
        elem->nextSym = NULL;

        symbol_table[scope] = elem;

        return elem;
    }

    tmp = symbol_table[scope];
    while(tmp != NULL) /*go to the end and add the new symbol, while checking if it already exists in this scope*/
    {
        if(strcmp(tmp->varName, symbol_name) == 0)
        {
            if(tmp->category == category) /*if it already exists create a new one*/
            {
                if(tmp->active == 1)
                {
                    /*printf("symbol %s exists and is already active\n", tmp->varName);*/
                    return NULL;
                }
                /*there is a symbol that has the same category and scope, but we add a new one*/
                elem = malloc(sizeof(symbol));
                if(elem == NULL)
                {
                    fprintf(stderr, "Error in addSymbol, can't create new symbol, not enough memory...\n");
                    exit(0);
                }
                elem->varName = strdup(symbol_name);
                elem->category = category;
                elem->active = 1;
                elem->scope = scope;
                elem->line = line;
                elem->offset = offset;
                elem->space = space;
                elem->nextSym = tmp->nextSym;
                tmp->nextSym = elem;
                printf("Added(Activated) symbol %s and changed line from %d to %d\n", tmp->varName, tmp->line, line);
                /*tmp->line = line;*/   /*keep the line where the symbol was first encountered*/
                return tmp;
            }
            else
            {
                /*printf("Symbol redefinition? Symbol recorded %s in line %d, new symbol in line %d\n", tmp->varName, tmp->line, line);*/
                /*exit(-1);*/
                /*same name different category, in that case i'll create a new symbol. only example for this case that i found was
                function g(x,y) { //random code }
                {
                    local x;  <- matches with the func arg "x" in scope 1, leading to symbol redefinition
                }*/
            }
        }
        prev = tmp;
        tmp = tmp->nextSym;
    }
   
    
    /*didnt find a record of the symbol so we add it to the end of the scope list*/
    elem = malloc(sizeof(symbol));
    if(elem == NULL)
    {
        fprintf(stderr, "Error in addSymbol, can't create new symbol, not enough memory...\n");
        exit(0);
    }
    elem->varName = strdup(symbol_name);
    elem->category = category;
    elem->active = 1;
    elem->scope = scope;
    elem->line = line;
    elem->offset = offset;
    elem->space = space;
    elem->nextSym = NULL;

    prev->nextSym = elem;   /*add it to the end of the scope*/

    
    return elem;
}

symbol_T add_anonymus_func(int scope, int line, int offset, enum scopespace_t space)
{
    symbol_T elem = NULL;
    int i = 0;
    char buf[5] = {0};  /*_f and \0 are 3 chars leaving us with 2 chars for digits allowing up to 100 anonymus functions*/

    snprintf(buf, 5, "_f%d", i);
    elem = search_from_scope_out(buf, scope);
    while(elem != NULL && i < 100)
    {
        i++;
        snprintf(buf, 5, "_f%d", i);
        elem = search_from_scope_out(buf, scope);
    }
    
    elem = addSymbol(buf, user_func, scope, line, offset, space);

    return elem;
}

void print_symbol_table()
{
    symbol_T tmp = NULL;

    for(int i = 0; i < TotalScopes; i++)
    {
        printf("-------------- Scope #%d --------------\n", i);
        tmp = symbol_table[i];
        while(tmp != NULL)
        {
            printf("%-18s ", tmp->varName);
            if(tmp->category == library_function)
                printf("[library function] ");
            else if(tmp->category == global_var)
                printf("[global variable] ");
            else if(tmp->category == func_arg)
                printf("[function argument] ");
            else if(tmp->category == local_var)
                printf("[local variable] ");
            else if(tmp->category == user_func)
                printf("[user function] ");
            else
                printf("[unknown] ");

            printf("(line %d)  (active %d)\n", tmp->line, tmp->active);

            tmp = tmp->nextSym;
        }
    }
}

/*Mark all symbols in the given scope as not syntactically active*/
void hide_in_scope(int scope)
{
    symbol_T tmp = NULL;

    if(symbol_table == NULL)
    {
        printf("Error in hide_in_scope() : Symbol table is not initialized.\n");
        return;
    }
    if(scope >= TotalScopes)    /*a block doesn't have to declare new variables so that scope might not exist in the symbol table*/
    {
        return;
    }
    if(scope == 0)   /*can't hide global scope(lib funcs would be affected as well)*/
        return;
    


    tmp = symbol_table[scope];
    while(tmp != NULL)
    {
        tmp->active = 0;
        tmp = tmp->nextSym;
    }
}

unsigned int getTotalGlobals()
{
    symbol_T tmp = NULL;
    unsigned int total = 0;
    
    for(int i = 0; i < TotalScopes; i++)
    {
        tmp = symbol_table[i];
        while(tmp != NULL)
        {
           if(tmp->space == programVar)
            {
                total++;
            }

            tmp = tmp->nextSym;
        }
    }
                
    return total;

}