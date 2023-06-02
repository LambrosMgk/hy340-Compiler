#ifndef quads_h
#define quads_h

#include "symbol_table.h"
#include <assert.h>

enum iopcode {
    iop_assign, iop_add, iop_sub, iop_mul, iop_div, iop_mod, iop_uminus, iop_AND, iop_OR, iop_NOT, if_eq, 
    if_noteq, if_lesseq, if_greatereq, if_less, if_greater, jump, call, param, ret, getretval, funcstart, funcend, 
    tablecreate, tablegetelem, tablesetelem
};

enum expr_t {
    var_e, tableitem_e, programfunc_e, libraryfunc_e, arithexpr_e, boolexpr_e, assignexpr_e, newtable_e,
    constnum_e, constbool_e, conststring_e, nil_e
};

typedef struct loopStack loopStack;
typedef struct logicList logicList;

struct logicList {
	int quadNum;
	logicList* next;
};

struct loopStack {
	logicList* breaklist;
	logicList* continuelist;
	loopStack* next;
};

struct forLoopStruct {
	int condition;
	int enter;
};

typedef struct expr_ {
    enum expr_t type;
    symbol* sym;
    struct expr_* index;
    struct expr_* indexedVal;
    double numConst;
    char* strConst;
    unsigned char boolConst;

    logicList* truelist;
	logicList* falselist;

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


typedef struct method_call {
	int isMethod;
	expr* elist;
	char* name;
}method_call, *method_call_T;


void emit(enum iopcode op, expr* result, expr* arg1, expr* arg2, unsigned int label, unsigned int line);

int nextQuadLabel();

logicList* makelist(int quadno);

logicList* mergeLocicLists(logicList* list1, logicList* list2);

void backPatchList(logicList* list, int quadno);

void patchLabel(unsigned int quadnumber, unsigned int label);

expr_P newExpr(enum expr_t type, symbol* sym);

void emit_param_recursive(expr_P elist, int line);

expr_P rule_call(expr_P lvalue, expr_P elist, int *offset, enum scopespace_t space, int scope, int line);

symbol* newTemp(int *offset, enum scopespace_t space);

void resetTemp();

void writeQuadsToFile();

#endif