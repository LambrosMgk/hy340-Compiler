#include "quads.h"

QuadNode_T BreakStack = NULL;
QuadNode_T BreakCounterStack = NULL;
QuadNode_T ContinueStack = NULL;
QuadNode_T ContinueCounterStack = NULL;
QuadNode_T JumpStackTop = NULL;
QuadNode_T QueueHead = NULL;

QuadNode_T create_QuadNode(int label)
{
    QuadNode_T new = (QuadNode_T) malloc(sizeof(struct QuadNode_));
    if (new == NULL)
    {
        fprintf(stderr, "Error with malloc in breakList.c : create_QuadNode()\n");
        exit(-1);
    }

    new->quadLabel = label;
    new->next = NULL;
    new->prev = NULL;

    return new;
}

QuadNode_T QuadNode_Stack_push(QuadNode_T StackHead, int label)
{
    QuadNode_T elem = create_QuadNode(label);

    printf("----------------------------------------pushing(Stack) %d\n", label);
    if(StackHead == NULL)
        return elem;
    else
    {
        StackHead->next = elem;
        elem->prev = StackHead;
        return elem;
    }
}

QuadNode_T QuadNode_Stack_pop(QuadNode_T StackHead, int *res) 
{
    QuadNode_T tmp = NULL, prev = NULL;

    if(StackHead == NULL)
    {    
        *res = 0;
        return NULL;
    }

    
    *res = StackHead->quadLabel;
    prev = StackHead->prev;
    free(StackHead);
    if(prev != NULL)
        prev->next = NULL;
    printf("----------------------------------------popping(Stack) %d\n", *res);

    return prev;
}

QuadNode_T QuadNode_Queue_push(QuadNode_T head, int label)
{
    QuadNode_T elem = create_QuadNode(label);
    QuadNode_T tmp = head;
    printf("----------------------------------------pushing(Queue) %d\n", label);
    if(head == NULL)
    { 
        return elem;    /*new head*/
    }

    while(tmp->next != NULL)
        tmp = tmp->next;
    
    tmp->next = elem;
    return head;        /*head stays the same*/
}

QuadNode_T QuadNode_Queue_pop(QuadNode_T head, int *res)
{
    QuadNode_T tmp = head;

    if(head == NULL)
    {
        *res = 0;
        return NULL;
    }
    
    head = head->next;
    *res = tmp->quadLabel;
    free(tmp);
    if(head != NULL)
        head->prev = NULL;
    printf("----------------------------------------popping(Queue) %d\n", *res);

    return head;
}