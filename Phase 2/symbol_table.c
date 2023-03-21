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
    symbol_T elem = NULL, tmp;
    int i;

    for(i = 0; i < 12; i++)
    {
        elem = malloc(sizeof(symbol));
        if(elem == NULL)
        {
            fprintf(stderr, "Error in addElement, not enough memory...\n");
            exit(0);
        }

        elem->varName = strdup(lib_funcs[i]);   /*maybe no need for strdup? just assign pointer*/
        elem->category = 0;
        elem->active = 1;
        elem->scope = 0;
        elem->line = 0;
        elem->nextSym = NULL;

        if(symbol_table != NULL)
        {
            tmp = symbol_table;
            while(tmp->nextSym != NULL)
            {
                tmp = tmp->nextSym;
            }
            tmp->nextSym = elem;
        }
        else
            symbol_table = elem;
        }
}

void init_symbol_table()
{
    symbol_table = (symbol_T **) malloc(TotalScopes * sizeof(symbol_T *));
    if(symbol_table == NULL)
    {
        fprintf(stderr, "Error : not enough memory to initialize symbol table. Exiting...\n");
    }
    init_lib_funcs();
}

symbol_T search_from_scope_out(char *name, int scope)
{

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

/*on success return the pointer of the new symbol, otherwise NULL*/
/*isws spasto se addID kai addFunction?*/
symbol_T addElement(char * symbol_name, enum SymbolCategory category, int scope, int line)
{
    symbol_T elem = NULL, tmp = NULL, prev = NULL;
    int i = 0;


    if(is_lib_func(symbol_name) == 1)   /*if lib function then no need to add it again to the table*/
    {
        fprintf(stderr, "Error : Shadowing of library functions is not allowed.\n");
        return NULL;
    }
    if(symbol_table == NULL)
    {
        fprintf(stderr, "Error : Symbol table is not initialized.\n");
        return NULL;
    }
    if(TotalScopes < scope+1) /*scope + 1 because if i call from syntax.y with scope 0 but that means there is a total of 1 scopes*/
    {
        /*e.g. Table is initialized for scope 0, i want to preserve order so i check the size of the array if previous scopes exist*/
        symbol_table = realloc(symbol_table, (scope + 1) * sizeof(symbol_T *));
        if(symbol_table == NULL)
        {
            fprintf(stderr, "Error : Realloc for symbol table failed.\n");
            return NULL;
        }
        TotalScopes = scope + 1;
    }


    
    if(symbol_table[scope] == NULL)   /*first symbol in this scope*/
    {
        elem = malloc(sizeof(symbol));
        if(elem == NULL)
        {
            fprintf(stderr, "Error in addElement, not enough memory...\n");
            exit(0);
        }

        elem->varName = strdup(symbol_name);
        elem->category = category;
        elem->active = 1;
        elem->scope = scope;
        elem->line = line;
        elem->nextSym = NULL;

        symbol_table[scope] = elem;

        return elem;
    }

    tmp = symbol_table[scope];
    while(tmp != NULL) /*go to the end and add the new symbol, while checking if it already exists in this scope*/
    {
        if(strcmp(tmp->varName, symbol_name) == 0)
        {
            if(tmp->category == category) /*if it already exists don't create a new one*/
            {
                if(tmp->active == 1)
                {
                    printf("symbol %s exists and is already active\n", tmp->varName);
                    return NULL;
                }
                /*else tmp->active == 0*/
                tmp->active = 1;    /*there is a symbol that has the same category and scope, so we activate it again*/
                printf("Activated symbol %s and changed line from %d to %d\n", tmp->varName, tmp->line, line);
                tmp->line = line;
                return tmp;
            }
            else
            {
                printf("Symbol redefinition? Symbol recorded %s in line %d, new symbol in line %d\n", tmp->varName, tmp->line, line);
                return NULL;
            }
            break;
        }
        prev = tmp;
        tmp = tmp->nextSym;
    }
   
    
    /*didnt find a record of the symbol so we add it to the end of the scope list*/
    elem = malloc(sizeof(symbol));
    if(elem == NULL)
    {
        fprintf(stderr, "Error in addElement, can't create new symbol, not enough memory...\n");
        exit(0);
    }
    elem->varName = strdup(symbol_name);
    elem->category = category;
    elem->active = 1;
    elem->scope = scope;
    elem->line = line;
    elem->nextSym = NULL;

    prev->nextSym = elem;   /*add it to the end of the scope*/

    
    return elem;
}

symbol_T add_anonymus_func(int scope, int line)
{
    symbol_T elem = NULL;
    int i = 0;
    char buf[5] = {0};  /*_f and \0 are 3 chars and 2 chars for digits allowing up to 100 anonymus functions*/

    snprintf(buf, 5, "_f%d", i);
    elem = addElement(buf, 4, scope, line);
    while(elem == NULL && i < 100)
    {
        i++;
        snprintf(buf, 5, "_f%d", i);
        elem = addElement(buf, 4, scope, line);
    }


    return elem;
}

void print_symbol_table()
{
    symbol_T tmp = NULL;

    for(int i = 0; i < TotalScopes; i++)
    {
        tmp = symbol_table[i];
        printf("-------------- Scope #%d --------------\n", i);
        while(tmp != NULL)
        {
            printf("%s ");
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

void hide_in_scope(int scope)
{
    symbol_T tmp = NULL, tmpSubList = NULL;

    if(tmp == NULL)
    {
        printf("Error in hide_in_scope() : Symbol table is not initialized.\n");
        return;
    }
    if(scope >= TotalScopes)
    {
        printf("Error in hide_in_scope() : invalid scope %d compared to the currect number of scopes %d.\n", scope, TotalScopes);
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
