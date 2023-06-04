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
		funcStack *newTop = (funcStack*) malloc (sizeof(funcStack));
		newTop->info = mem;
		newTop->next = NULL;

		functionStackTarget = newTop;
	}
    else
    {
		funcStack *newTop = (funcStack*) malloc (sizeof(funcStack));
		newTop->info = mem;

		newTop->next = functionStackTarget;
		functionStackTarget = newTop;
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

void appendFuncStackTarget(symbol* f, unsigned int instrLabel)
{
	returnList* newNode = f->returnList;

	if(newNode == NULL)
    {
		newNode = (returnList*) malloc (sizeof(returnList));	
		newNode->instrLabel = instrLabel;
		newNode->next = NULL;
		f->returnList = newNode;
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