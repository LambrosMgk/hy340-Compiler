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

void emit_rel_op(enum iopcode op, expr* result, expr* arg1, expr* arg2, unsigned line)
{
    quad *p = quads + currQuad++;   /*if condition true jump 3 quads*/
    p->op = op;
    p->result = arg1;
    p->arg1 = arg2;
    p->arg2 = newExpr(constnum_e, NULL);
    p->arg2->numConst = currQuad + 3;
    p->label = currQuad;
    p->line = line;

    if(currQuad == total)
        expand();
    p = quads + currQuad++;     /*else assign false*/
    p->op = iop_assign;
    p->result = result;         /*result will already have a var expr*/
    p->arg1 = newExpr(constbool_e, NULL);
    p->arg1->boolConst = 0;
    p->arg2 = NULL;
    p->label = currQuad;
    p->line = line;

    if(currQuad == total)
        expand();
    p = quads + currQuad++;
    p->op = jump;               /*and jump away!*/
    p->result = newExpr(constnum_e, NULL);
    p->result->numConst = currQuad + 2;
    p->arg1 = NULL;
    p->arg2 = NULL;
    p->label = currQuad;
    p->line = line;

    if(currQuad == total)
        expand();
    p = quads + currQuad++;
    p->op = iop_assign;
    p->result = result;         /*result will already have a var expr*/
    p->arg1 = newExpr(constbool_e, NULL);
    p->arg1->boolConst = 1;
    p->arg2 = NULL;
    p->label = currQuad;
    p->line = line;
}

void emit(enum iopcode op, expr* result, expr* arg1, expr* arg2, unsigned line)
{
    if(currQuad == total)
        expand();

    quad *p = quads + currQuad++;   /*pointer arithmetic for quads array*/
    p->op = op;
    p->arg1 = arg1;
    p->arg2 = arg2;
    p->result = result;
    p->label = currQuad;   /*currQuad will be used as label*/
    p->line = line;
}

void mark_quad()
{
    JumpStackTop = QuadNode_Stack_push(JumpStackTop, currQuad);   /*-1 depends if you call mark_quad() before emit() or after*/
}
/*exists to help me with the false jump on for loop*/
void mark_next_quad()
{
    JumpStackTop = QuadNode_Stack_push(JumpStackTop, currQuad+1);
}

void mark_queue_quad()
{
    QueueHead = QuadNode_Queue_push(QueueHead, currQuad);
}

void mark_break_quad()
{
    BreakStack = QuadNode_Stack_push(BreakStack, currQuad);
}

void push_break_count(int breakNum)
{
    BreakCounterStack = QuadNode_Stack_push(BreakCounterStack, breakNum);
}

int pop_break_count(void)
{
    int result = 0;
    BreakCounterStack = QuadNode_Stack_pop(BreakCounterStack, &result);
    return result;
}

void patchBreakLabel()
{
    int quadNum = -1;
    BreakStack = QuadNode_Stack_pop(BreakStack, &quadNum);
    quad *p = quads + quadNum;
    expr_P expr = newExpr(constnum_e, NULL);
    expr->numConst = currQuad+1;
    p->result = expr;
}

void mark_continue_quad()
{
    ContinueStack = QuadNode_Stack_push(ContinueStack, currQuad);
}

void push_continue_count(int breakNum)
{
    ContinueCounterStack = QuadNode_Stack_push(ContinueCounterStack, breakNum);
}

int pop_continue_count(void)
{
    int result = 0;
    ContinueCounterStack = QuadNode_Stack_pop(ContinueCounterStack, &result);
    return result;
}

void patchContinueLabel(int ExprStartQuad)
{
    int quadNum = -1;
    ContinueStack = QuadNode_Stack_pop(ContinueStack, &quadNum);
    quad *p = quads + quadNum;
    expr_P expr = newExpr(constnum_e, NULL);
    expr->numConst = ExprStartQuad;
    p->result = expr;
}

/*returns the label it patched in case we have an "else" afterwards so "else" will fix it*/
int patchArg2Label()
{
    int quadNum = -1;
    JumpStackTop = QuadNode_Stack_pop(JumpStackTop, &quadNum);
    quad *p = quads + quadNum;
    expr_P expr = newExpr(constnum_e, NULL);
    expr->numConst = currQuad+1;
    p->arg2 = expr;

    return quadNum;
}

void patchELSEjump(int quadNum)
{
    quad *p = quads + quadNum;
    p->arg2->numConst++;    /*go after the "jump" to execute the stmts of ELSE (otherwise else won't be executed it'll jump away)*/
}
/*patch the quad you just emitted to jump to the +2 quad*/
void patchEmittedResult()
{
    quad *p = quads + currQuad-1;
    expr_P expr = newExpr(constnum_e, NULL);
    expr->numConst = currQuad+2;
    p->result = expr;
}

/*patch the jump quad (that you just emitted) of a loop with the help of a queue*/
int patch_loop_label()
{
    int quadNum = -1;
    QueueHead = QuadNode_Queue_pop(QueueHead, &quadNum);
    quad *p = quads + currQuad-1;
    expr_P expr = newExpr(constnum_e, NULL);
    expr->numConst = quadNum+1;
    p->result = expr;

    return quadNum+1;
}

int patch_thisResult_FromStack()
{
    int quadNum = -1;
    JumpStackTop = QuadNode_Stack_pop(JumpStackTop, &quadNum);
    quad *p = quads + currQuad-1;
    expr_P expr = newExpr(constnum_e, NULL);
    expr->numConst = quadNum+1;
    p->result = expr;

    return quadNum+1;
}

/*with the use of jumpStack_pop() (and jumpStack_push() in emit()) recognizes an empty jump quad and patches it (used in funcdef and ELSE)*/
void patchLabel()
{
    int quadNum = -1;
    JumpStackTop = QuadNode_Stack_pop(JumpStackTop, &quadNum);
    quad *p = quads + quadNum;
    expr_P expr = newExpr(constnum_e, NULL);
    expr->numConst = currQuad+1;
    p->result = expr;
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
    expr->next = NULL;

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
        elem = addElement(name, 1, 0, 0, *offset, space);
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

    fprintf(out, "quad#     opcode              result                      arg1                arg2                label\n");
    fprintf(out, "----------------------------------------------------------------------------------------------------------------\n");
    for(int i = 0; i < currQuad; i++)
    {
        fprintf(out, "<%d>:   op: %12s,    ", p->label, iopToString[p->op]);
        printf("now emitting %s\n", iopToString[p->op]);
        
        if(p->result == NULL)
            fprintf(out, "  result: ----------,      ");
        else if(p->result->type == constnum_e)
            fprintf(out, "  result: %10f,     ", p->result->numConst);
        else if(p->result->type == constbool_e)
            fprintf(out, "  result: %10d,     ", p->result->boolConst);
        else if(p->result->type == conststring_e || p->result->type == tableitem_e)
            fprintf(out, "  result: %10s,    ", p->result->strConst);
        else   /* p->result->sym != NULL, result must always be a variable*/
            fprintf(out, "  result: %10s,     ", p->result->sym->varName);

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
            else if(p->arg1->type == constbool_e)
                fprintf(out, "  arg1: %10d,    ", p->arg1->boolConst);
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
            else if(p->arg2->type == constbool_e)
                fprintf(out, "  arg2: %10d,    ", p->arg2->boolConst);
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