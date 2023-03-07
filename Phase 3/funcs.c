#include "funcs.h"


expr_P member_lvalue_dot_ID(expr_P a1, char * a3)
{
    expr_P lvalexpr = a1, exprPtr = NULL;
    /*the ID that i'll get is not an actual var but an index of the array so dont look it up in the sym table*/
    
    
    exprPtr = newExpr(tableitem_e, NULL);    /*new expr holding the table_item name*/
    exprPtr->strConst = a3;

    if(lvalexpr->type == var_e)  /*(the table)the first id has type of var_e*/
    {
        lvalexpr->next = exprPtr;
        lvalexpr->index = NULL;
        exprPtr->index = lvalexpr;  /*index to the first table element*/
    }
    else
    {
        lvalexpr->next = exprPtr;   /*connect it to the item list*/
        exprPtr->index = lvalexpr->index;   /*all index point to the first elem, so its easier to produce the quads*/
    }

    return exprPtr;
}


expr_P member_lvalue_LSqBr_expr_RSqBr(expr_P a1, expr_P a3, int scope)
{
    expr_P lvalexpr = a1, exprPtr = NULL;
    symbol_T sym = NULL;
    
    
    if(a3->type == var_e)   /*checking if sym == NULL*/
    {
        sym = search_from_scope_out(a3->sym->varName, scope);
        exprPtr = newExpr(tableitem_e, sym);   /*check if sym is null*//*new expr holding the table_item sym*/
    }
    
    if(sym == NULL && a3->type == constnum_e)
    {
        //printf("error or dynamic allocate for expr type(enum) : %d?\n", a3->type);
        //printf("It a constNum : %f\n", a3->numConst);
        exprPtr = a3;
    }
        

    if(lvalexpr->type == var_e)  /*the first id has type of var_e*/
    {
        lvalexpr->next = exprPtr;
        lvalexpr->index = NULL;
        exprPtr->index = lvalexpr;  /*index to the first table element*/
    }
    else
    {
        lvalexpr->next = exprPtr;   /*connect it to the item list*/
        exprPtr->index = lvalexpr->index;   /*all index point to the first elem, so its easier to produce the quads*/
    }

    return exprPtr;
    /*expr_P tmp = exprPtr->index;
    for(; tmp != NULL; tmp = tmp->next)
        printf("LIST CHECK : type %s\n", tmp->strConst);*/
}