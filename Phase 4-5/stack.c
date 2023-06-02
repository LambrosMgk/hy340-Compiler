#include "stack.h"

stack_T func_stack = NULL;

offset_stack_T offset_stack_head = NULL;
int offset_stack_size = 0;

loopStack* loopTop; //kathe node tou stack einai gia ena loop, to kathe loop exei diko tou break/continue list

int isLoopStackEmpty()
{
	if(loopTop == NULL)
		return 1;

	return 0;
}


int isBreakListEmpty()
{
	if(loopTop->breaklist == NULL)
		return 1;

	return 0;
}


int isContListEmpty()
{
	if(loopTop->continuelist == NULL)
		return 1;

	return 0;
}


void push_loop()
{
	if(isLoopStackEmpty())
    {
		loopTop = (loopStack*)malloc(sizeof(loopStack));
		loopTop->next = NULL;
		loopTop->breaklist = NULL;
		loopTop->continuelist = NULL;
	}
	else
    {
		loopStack* tmp = (loopStack*)malloc(sizeof(loopStack));
		tmp->next = loopTop;
		tmp->breaklist = NULL;
		tmp->continuelist = NULL;
		loopTop = tmp;
	}
}


void breakPush(int quadNum)
{
	if(isBreakListEmpty())
    {
		loopTop->breaklist = (logicList*)malloc(sizeof(logicList));
		loopTop->breaklist->next = NULL;
		loopTop->breaklist->quadNum = quadNum;
	}
	else
    {
		logicList* tmp = (logicList*)malloc(sizeof(logicList));
		tmp->next = loopTop->breaklist;
		tmp->quadNum = quadNum;
		loopTop->breaklist = tmp;
	}
}


void contPush(int quadNum)
{
	if(isContListEmpty())
    {
		loopTop->continuelist = (logicList*)malloc(sizeof(logicList));
		loopTop->continuelist->next = NULL;
		loopTop->continuelist->quadNum = quadNum;
	}
	else
    {
		logicList* tmp = (logicList*)malloc(sizeof(logicList));
		tmp->next = loopTop->continuelist;
		tmp->quadNum = quadNum;
		loopTop->continuelist = tmp;
	}
}


loopStack* pop_loop()
{
	if(isLoopStackEmpty())
    {
		printf(ANSI_COLOR_RED"Error: Trying to pop from empty stack(LoopStack). Exiting..."ANSI_COLOR_RESET"\n");
        return NULL;
	}
	else
    {
		loopStack* tmp = loopTop;
		loopTop = loopTop->next;
		tmp->next = NULL;
		return tmp;
	}
}

//functions for functions....

void push_func(char *name, int scope, int startLabel)
{
    stack_T elem = (stack_T) malloc(sizeof(struct stack));

    if(elem == NULL)
    {
        fprintf(stderr, "Error with malloc in stack.c : push()\n");
        exit(-1);
    }
    
    if(name == NULL)
        elem->name = NULL;
    else
        elem->name = strdup(name);
    elem->scope = scope;
    elem->startLabel = startLabel;
    elem->next = NULL;
    elem->prev = NULL;


    if(func_stack == NULL)
        func_stack = elem;
    else
    {
        func_stack->next = elem;
        elem->prev = func_stack;
        func_stack = elem;
    }
}

/*Don't forget to free the object after you call this function*/
stack_T pop_func()
{
    stack_T tmp = NULL;
    if(func_stack == NULL)
        return NULL;

    tmp = func_stack;
    func_stack = func_stack->prev;

    return tmp;
}

//functions for offset stack

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