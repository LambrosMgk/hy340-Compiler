#include "quads.h"

#define EXPAND_SIZE 1024
#define CURR_SIZE (total*sizeof(quad))
#define NEW_SIZE (EXPAND_SIZE*sizeof(quad) + CURR_SIZE)

char *iopToString[] = {"iop_assign", "iop_add", "iop_sub", "iop_mul", "iop_div", "iop_mod", "iop_uminus", "iop_AND", 
    "iop_OR", "iop_NOT", "if_eq", "if_noteq", "if_lesseq", "if_geatereq", "if_less", "if_greater", "jump", "call",
    "param", "ret", "getretval", "funcstart", "funcend", "tablecreate", "tablegetelem", "tablesetelem"};

quad *quads = (quad_T) 0;
unsigned int total = 0;
unsigned int currQuad = 0;
unsigned int tmpcounter = 0, totaltmp = 0;

void expand(void)
{
    assert(total == currQuad);
    quad_T p = (quad_T) malloc(NEW_SIZE);
    if(quads)
    {
        memcpy(p, quads, CURR_SIZE);
        free(quads);
    }
    quads = p;
    total += EXPAND_SIZE;
}

void emit(enum iopcode op, expr* result, expr* arg1, expr* arg2, unsigned int label, unsigned int line)
{
    if(currQuad == total)
        expand();

    quad *p = quads + currQuad++;   /*pointer arithmetic for quads array*/
    p->op = op;
    p->result = result;
    p->arg1 = arg1;
    p->arg2 = arg2;
    p->label = label;
    p->line = line;
}

int nextQuadLabel()
{
    return currQuad;
}

logicList* makelist(int quadno)
{

	logicList* list = (logicList*) malloc(sizeof(logicList));
	memset(list,0,sizeof(logicList));
	list->quadNum = quadno;
	list->next = NULL;
	return list;

}

logicList* mergeLocicLists(logicList* list1, logicList* list2)
{
	logicList* tmp = NULL;

	if(list1 == NULL && list2 == NULL)
		return NULL;
	else if(list1 == NULL && list2 != NULL)
		return list2;
	else if(list1 != NULL && list2 == NULL)
		return list1;
	else
    {
		tmp = list1;
		while(tmp->next != NULL)
        {
			tmp = tmp->next;
		}
		tmp->next = list2;
		return list1;
	}

    return NULL;
}

void backPatchList(logicList* list, int quadno)
{
	logicList* tmp = list;

	while(tmp != NULL)
    {
		patchLabel(tmp->quadNum,quadno);
		tmp = tmp->next;
	}
}

void patchLabel(unsigned int quadnumber, unsigned int label)
{
    if(quadnumber >= currQuad)
    {
        printf("patchLabel call with wrong arguments, quadnum : %d, label : %d\n", quadnumber, label);
        exit(-1);
    }
    
    expr_P expr = newExpr(constnum_e, NULL);
    expr->numConst = label;
	quads[quadnumber].arg2 = expr;
}

void emit_param_recursive(expr_P elist, int line)
{
    expr_P tmp = elist;
    
    if(tmp == NULL || elist->type == nil_e)
        return;

    emit_param_recursive(tmp->next, line);

    emit(param, tmp, NULL, NULL, nextQuadLabel(), line);
}

expr_P rule_call(expr_P lvalue, expr_P elist, int *offset, enum scopespace_t space, int scope, int line)
{
    expr_P func = lvalue;
    expr_P result = newExpr(var_e, newTemp(offset, space));

    
    if(lvalue->type == tableitem_e)
    {
        func = newExpr(var_e, newTemp(offset, space));
        emit(tablegetelem, func, lvalue, lvalue->index, nextQuadLabel(), line);
    }

    emit_param_recursive(elist, line);
   
    emit(call, func, NULL, NULL, nextQuadLabel(), line);
    emit(getretval, result, NULL, NULL, nextQuadLabel(), line);

    return result;
}

expr_P newExpr(enum expr_t type, symbol* sym)
{
    expr_P expr = (expr_P) malloc(sizeof(struct expr_));

    if(expr == NULL)
    {
        fprintf(stderr, "Error : not enough memory to create new expression\n");
        exit(-1);
    }

    expr->type = type;
    expr->sym = sym;
    expr->index = NULL;
    expr->indexedVal = NULL;
    expr->next = NULL;
    expr->truelist = NULL;
    expr->falselist = NULL;

    return expr;
}

/*returns either a new temporary var or an available one (will increase offset)*/
symbol* newTemp(int *offset, enum scopespace_t space)
{
    symbol_T elem = NULL;
    char buf[5] = {0};
    char *name = NULL;


    if(tmpcounter == totaltmp)  /*create new temporary var*/
    {
        if(totaltmp == 99)
        {
            printf("reached max names for temp vars\n");
            exit(-1);
        }
        name = malloc(5*sizeof(char));/*_t and \0 are 3 chars and 2 chars for digits allowing up to 100 temporary variables*/
        snprintf(name, 5, "_t%d", totaltmp);/*gives a new name for a temporary variable every time it is called based on a global counter*/
        elem = addSymbol(name, global_var, 0, 0, *offset, space);
        *offset++;
        totaltmp++;
        tmpcounter++;
    }
    else    /*search symbol table and return*/
    {
        snprintf(buf, 5, "_t%d", tmpcounter);
        elem = getElement(buf, 0);
        tmpcounter++;
    }

    return elem;
}
/*resets counter for active temporary variables*/
void resetTemp()
{
    tmpcounter = 0;
}

/*creates a file named quads.txt and writes the array of the quads*/
void writeQuadsToFile()
{
    FILE* out = fopen("quads.txt", "w");
    quad *p = quads;

    if(out == NULL)
    {
        fprintf(stderr, "Error creating or opening file quads.txt\n");
        exit(-1);
    }

    fprintf(out, "quad#     opcode              result                      arg1                arg2                \n");
    fprintf(out, "----------------------------------------------------------------------------------------------------------------\n");
    for(int i = 0; i < currQuad; i++)
    {
        fprintf(out, "<%d>:   op: %12s,    ", p->label, iopToString[p->op]);
        //printf("now emitting %s\n", iopToString[p->op]);
        
        if(p->result == NULL)
            fprintf(out, "  result: ----------,      ");
        else if(p->result->type == constnum_e)
            fprintf(out, "  result: %10f,     ", p->result->numConst);
        else if(p->result->type == constbool_e || p->result->type == boolexpr_e)
        {
            if(p->result->sym != NULL)  /*first check if i gave it a temp varable*/
                fprintf(out, "  result: %10s,    ", p->result->sym->varName);
            else if(p->result->boolConst == 0)
                fprintf(out, "  result: %10s,    ", "FALSE");
            else
                fprintf(out, "  result: %10s,    ", "TRUE");
        }
        else if(p->result->type == conststring_e)
            fprintf(out, "  result: %10s,    ", p->result->strConst);
        else if(p->result->sym != NULL || p->result->type == tableitem_e)/* p->result->sym != NULL, result must always be a variable*/
            fprintf(out, "  result: %10s,     ", p->result->sym->varName);
        else
            fprintf(out, "  result: ???????????");


        if(p->arg1 == NULL)
        {
            fprintf(out, "  arg1: ----------,    ");
        }
        else
        {
            if(p->arg1->sym != NULL || p->arg1->type == programfunc_e)
            {
                fprintf(out, "  arg1: %10s,   ", p->arg1->sym->varName);
            }
            else if(p->arg1->type == constnum_e)
                fprintf(out, "  arg1: %10f,    ", p->arg1->numConst);
            else if(p->arg1->type == constbool_e || p->arg1->type == boolexpr_e)
            {
                if(p->arg1->boolConst == 0)
                    fprintf(out, "  arg1: %10s,    ", "FALSE");
                else
                    fprintf(out, "  arg1: %10s,    ", "TRUE");
            }
            else if(p->arg1->type == conststring_e || p->arg1->type == tableitem_e)
                fprintf(out, "  arg1: %10s,    ", p->arg1->strConst);
            else if(p->arg1->type == nil_e)
                fprintf(out, "  arg1:        NIL,    ");
            else
                fprintf(out, "  arg1: ???????????");
        }


        if(p->arg2 != NULL)
        {
            if(p->arg2->sym != NULL)
                fprintf(out, "  arg2: %10s,   ", p->arg2->sym->varName);
            else if(p->arg2->type == constnum_e)
                fprintf(out, "  arg2: %10f,    ", p->arg2->numConst);
            else if(p->arg2->type == constbool_e || p->arg2->type == boolexpr_e)
            {
                if(p->arg2->boolConst == 0)
                    fprintf(out, "  arg2: %10s,    ", "FALSE");
                else
                    fprintf(out, "  arg2: %10s,    ", "TRUE");
            }
            else if(p->arg2->type == conststring_e || p->arg2->type == tableitem_e)
                fprintf(out, "  arg2: %10s,    ", p->arg2->strConst);
            else if(p->arg2->type == nil_e)
                fprintf(out, "  arg1:        NIL,    ");
            else
                fprintf(out, "  arg2: ???????????");
        }
        else
            fprintf(out, "  arg2: ----------,    ");
        
        fprintf(out, "  from line %d\n", p->line);

        p++;
    }
    fclose(out);
}