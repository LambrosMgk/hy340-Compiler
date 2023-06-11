#include "targetCode.h"

funcStack* functionStackTarget = NULL;

int isFuncStackTargetEmpty()
{
    if(functionStackTarget == NULL) 
        return 1;

    return 0; 
}

void pushFuncStackTarget(symbol* mem)
{
	if(functionStackTarget == NULL)
    {
		funcStack *new = (funcStack*) malloc (sizeof(funcStack));
		new->info = mem;
		new->next = NULL;

		functionStackTarget = new;
	}
    else
    {
		funcStack *new = (funcStack*) malloc (sizeof(funcStack));
		new->info = mem;

		new->next = functionStackTarget;
		functionStackTarget = new;
	}
}

symbol* popFuncStackTarget()
{
    symbol* sym = NULL;

	if(!isFuncStackTargetEmpty())
    {
		funcStack *tmp = functionStackTarget;
		sym = tmp->info;

		functionStackTarget = functionStackTarget->next;

		tmp->next = NULL;
		//free(tmp); //isws na petaei segmentation
	}

    return sym;
}

symbol* topFuncStackTarget()
{
    symbol* sym = NULL;

	if(!isFuncStackTargetEmpty())
    {
		funcStack *tmp = functionStackTarget;
		sym = tmp->info;
	}
    
    return sym;
}

void appendFuncStackTarget(symbol* func, unsigned int instrLabel)
{
	returnList* newNode = func->returnList;

	if(newNode == NULL)
    {
		newNode = (returnList*) malloc (sizeof(returnList));	
		newNode->instrLabel = instrLabel;
		newNode->next = NULL;
		func->returnList = newNode;
	}
    else
    {
		returnList* tmp = (returnList*) malloc (sizeof(returnList));	
		tmp->instrLabel = instrLabel;
		tmp->next = NULL;

		returnList* reader = newNode;
		while(reader->next != NULL)
        {
            reader = reader->next;
        }

		reader->next = tmp;
	}
}