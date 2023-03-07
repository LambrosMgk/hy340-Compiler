#ifndef funcs_h
#define funcs_h

#include "quads.h"


expr_P member_lvalue_dot_ID(expr_P a1, char * a3);

expr_P member_lvalue_LSqBr_expr_RSqBr(expr_P a1, expr_P a3, int scope);

#endif