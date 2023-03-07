#ifndef quads_h
#define quads_h

#include "symbol_table.h"
#include <assert.h>

enum iopcode {
    iop_assign, iop_add, iop_sub, iop_mul, iop_div, iop_mod, iop_uminus, iop_AND, iop_OR, iop_NOT, if_eq, 
    if_noteq, if_lesseq, if_geatereq, if_less, if_greater, jump, call, param, ret, getretval, funcstart, funcend, 
    tablecreate, tablegetelem, tablesetelem
};

enum expr_t {
    var_e, tableitem_e, programfunc_e, libraryfunc_e, arithexpr_e, boolexpr_e, assignexpr_e, newtable_e,
    constnum_e, constbool_e, conststring_e, nil_e
};

typedef struct expr_ {
    enum expr_t type;
    symbol* sym;
    struct expr_* index;
    double numConst;
    char* strConst;
    unsigned char boolConst;
    struct expr_* next;
} expr, *expr_P;

typedef struct quad_ {
    enum iopcode op;
    expr* result;
    expr* arg1;
    expr* arg2;
    unsigned label;
    unsigned line;
} quad, *quad_T;

typedef struct QuadNode_ {
    int quadLabel;
    struct QuadNode_ *next, *prev;
} QuadNode, *QuadNode_T;

extern QuadNode_T BreakStack, BreakCounterStack, JumpStackTop, QueueHead, ContinueStack, ContinueCounterStack;

void emit_rel_op(enum iopcode op, expr* result, expr* arg1, expr* arg2, unsigned line);

void emit(enum iopcode op, expr* result, expr* arg1, expr* arg2, unsigned line);

void mark_quad();

void mark_next_quad();

void mark_queue_quad();

void mark_break_quad();

void push_break_count(int breakNum);

int pop_break_count(void);

void patchBreakLabel();

void mark_continue_quad();

void push_continue_count(int breakNum);

int pop_continue_count(void);

void patchContinueLabel(int ExprStartQuad);

int patchArg2Label();

void patchELSEjump(int quadNum);

void patchEmittedResult();

int patch_loop_label();

int patch_thisResult_FromStack();

void patchLabel();

expr_P newExpr(enum expr_t type, symbol* sym);

symbol* newTemp(int *offset, enum scopespace_t space);

void resetTemp();

void writeQuadsToFile();

QuadNode_T QuadNode_Stack_push(QuadNode_T StackHead, int label);

QuadNode_T QuadNode_Stack_pop(QuadNode_T StackHead, int *res);

QuadNode_T QuadNode_Queue_push(QuadNode_T head, int label);

QuadNode_T QuadNode_Queue_pop(QuadNode_T head, int *res);

#endif