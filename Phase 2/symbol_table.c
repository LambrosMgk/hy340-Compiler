#include "symbol_table.h"

symbol_T symbol_table = NULL;

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
        elem->nextSublist = NULL;

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
    init_lib_funcs();
}

symbol_T search_from_scope_out(char *name, int scope)
{

}

/*returns the struct with varName == name and same scope, otherwise null*/
symbol_T getElement(char *name, int scope)
{
    symbol_T tmp = symbol_table, tmpSubList = NULL;


    while(tmp != NULL && strcmp(tmp->varName, name) != 0)
    {
        tmp = tmp->nextSym;
    }

    if(tmp != NULL)
    {
        if(tmp->scope == scope)
            return tmp;
        else
        {
            tmpSubList = tmp->nextSublist;
            while(tmpSubList != NULL && tmpSubList->scope != scope)
            {
                tmpSubList = tmpSubList->nextSublist;
            }
            return tmpSubList;
        }
    }

    return NULL;
}

/*on success return the pointer of the new symbol, otherwise NULL*/
symbol_T addElement(char * varName, int category, int scope, int line)
{
    symbol_T elem = NULL, tmp = NULL, prev = NULL;


    if(is_lib_func(varName) == 1)   /*if lib function then no need to add it again to the table*/
    {
        return NULL;
    }
    if(symbol_table == NULL)/*this shouldn't execute because there are already library functions in the table*/
    {
        fprintf(stderr, "Error : Symbol table empty, should have at least library functions\n");
        return NULL;
    }


    tmp = getElement(varName, scope);
    if(tmp != NULL && tmp->category == category) /*if it already exists don't create a new one*/
    {
        if(tmp->active == 1)
        {
            printf("symbol %s already exists\n", tmp->varName);
            return NULL;  
        }
        /*else tmp->active == 0*/
        tmp->active = 1;    /*there is a symbol that has the same category and scope, so we activate it again*/
        printf("Changed line in symbol %s from %d to %d\n", tmp->varName, tmp->line, line);
        tmp->line = line;
        return tmp;
    }
    

    elem = malloc(sizeof(symbol));
    if(elem == NULL)
    {
        fprintf(stderr, "Error in addElement, not enough memory...\n");
        exit(0);
    }

    elem->varName = strdup(varName);
    elem->category = category;
    elem->active = 1;   /*symbol is created so its active*/
    elem->scope = scope;
    elem->line = line;
    elem->nextSym = NULL;
    elem->nextSublist = NULL;


    
    tmp = symbol_table;
    while(tmp->nextSym != NULL && strcmp(tmp->varName, varName) != 0)
    {
        prev = tmp;
        tmp = tmp->nextSym;
    }

    if(tmp->nextSym == NULL && strcmp(tmp->varName, varName) != 0)    /*first symbol with that name on the table*/
    {
        tmp->nextSym = elem;    /*append at the end of the list*/
    }
    else/*symbol already exists with that name but with different category*/
    {
        printf("symbol already exists with that name but with different category(line %d)\n", line);
        if(tmp->scope > scope)  /*order by increasing scope, 0 (global) first then 1,2,...*/
        {
            prev->nextSym = elem;   /*previous symbol now points to the new symbol*/
            elem->nextSym = tmp->nextSym;   /*new symbol gets the next symbol*/
            elem->nextSublist = tmp;    /*tmp is now next in the symbol sublist*/
        }
        else
        {
            prev = NULL;
            while(tmp->nextSublist != NULL && tmp->scope < scope)
            {
                prev = tmp;
                tmp = tmp->nextSublist;
            }
            
            if(tmp->scope > scope)
            {
                prev->nextSublist = elem;
                elem->nextSublist = tmp;
            }
            else /*if(tmp->nextSublist == NULL)*/
            {
                tmp->nextSublist = elem;
            }
        }
    }

    
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
    symbol_T tmp = symbol_table, tmpSubList = NULL;

    while(tmp != NULL)
    {
        printf("Symbol: %s, scope %d, active %d, category %d, in line %d\n", tmp->varName, tmp->scope, tmp->active, tmp->category, tmp->line);
        tmpSubList = tmp->nextSublist;
        while(tmpSubList != NULL)
        {
            printf("Symbol: %s, scope %d, active %d, category %d, in line %d\n", tmpSubList->varName, tmpSubList->scope, tmpSubList->active, tmpSubList->category, tmpSubList->line);
            tmpSubList = tmpSubList->nextSublist;
        }
        tmp = tmp->nextSym;
    }
}

void hide_in_scope(int scope)
{
    symbol_T tmp = symbol_table, tmpSubList = NULL;

    if(tmp == NULL || scope == 0)   /*can't hide global scope(lib funcs would be affected as well)*/
        return;
    
    while(tmp != NULL)
    {
        if(tmp->scope == scope)
            tmp->active = 0;
        else
        {
            tmpSubList = tmp->nextSublist;
            while(tmpSubList != NULL)
            {
                if(tmpSubList->scope == scope)
                tmpSubList->active = 0;
                tmpSubList = tmpSubList->nextSublist;
            }
        }
        tmp = tmp->nextSym;
    }
}
