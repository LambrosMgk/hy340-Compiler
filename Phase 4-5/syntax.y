%{
    #include "stack.h"
    #include "phase4.h"

    int alpha_yylex(void);
    int alpha_yyerror(char *yaccProvidedMessage);

    extern int alpha_yylineno;
    extern char* alpha_yytext;
    extern FILE* alpha_yyin;

    int scope = 0, offset = 0;
    int allowReturn = 0;
    int openloops = 0;
    int totalFuncArgs = 0;

     enum scopespace_t getSpace()
    {
        stack_T tmp = pop_func();
        if(tmp == NULL) /*no function symbols in the stack means we are not in a function definition*/
            return programVar;
        /*else*/
        push_func(tmp->name, tmp->scope, tmp->startLabel);
        return functionLocal;
    }

    void  printMessage(char *msg)
    {
        //printf("%s\n", msg);
    }

    void check_for_func_error(symbol_T lval)
    {
        if(lval != NULL && (lval->category == library_function || lval->category == user_func))
        {
            printf(ANSI_COLOR_RED"Syntax error in line <%d>: function %s used as an l-value"ANSI_COLOR_RESET"\n", alpha_yylineno, lval->varName);
            exit(-1);
        }
    }

    void typeCheck(expr_P exp1, expr_P exp2)
    {

    }

    unsigned int ConvertTypeToBoolean(expr_P expr)
    {
        if(expr->type == programfunc_e || expr->type == libraryfunc_e || expr->type == tableitem_e)
            return 1;
        else if(expr->type == constnum_e && expr->numConst != 0)
            return 1;
        else if(expr->type == conststring_e && strcmp(expr->strConst, "") != 0)
            return 1;
        return 0;   /*else if expr->type == nil_e*/
    }
%}

%define api.prefix {alpha_yy}
%define parse.error verbose

%start program

%union {
    int intVal;
    char* strVal;
    double doubleval;
    struct symbol_ *symPtr;
    struct expr_ *exprPtr;
    struct loopStack *loopStackStruct;
    struct forLoopStruct* forLoopStruct;
    struct method_call *method_call;
}


%token<doubleval> NUMBER
%token<strVal> ID STRING
%token<strVal> IF ELSE WHILE FOR FUNCTION RETURN BREAK CONTINUE AND NOT OR local TRUE FALSE NIL
%token<strVal> plus minus mul divide mod greater ge less le equal neq plusplus minusminus assign
%token<strVal> Lparenthesis Rparenthesis LCurlyBracket RCurlyBracket LSquareBracket RSquareBracket Semicolon comma colon coloncolon dot dotdot

%type<exprPtr> lvalue primary term expr const elist objectdef assignexpr member funcdef
%type<exprPtr> call stmt indexed indexedelem
%type<strVal>  block idlist whilestmt forstmt returnstmt
%type<intVal> M N ifstmt ifstmtprefix elseprefix whilestart whilecond

%type<loopStackStruct> loopstmt
%type<forLoopStruct> forprefix
%type<method_call> callsuffix normcall methodcall

%right assign
%left OR
%left AND
%nonassoc equal neq
%nonassoc greater ge less le
%left plus minus
%left mul divide mod
%right NOT plusplus minusminus uminus
%left dot dotdot
%left LSquareBracket RSquareBracket
%left Lparenthesis Rparenthesis


%%



program:    stmts{ printf("program -> stmts\n"ANSI_COLOR_GREEN"Accepted!"ANSI_COLOR_RESET"\n"); writeQuadsToFile(); print_symbol_table();}
    ;

stmts:  stmts stmt { printMessage("stmts -> statement kleene star"); resetTemp();}
        | 
    ;

stmt:   expr Semicolon { 
            $$ = $1;

            if($1->type == boolexpr_e)  // maybe add a check if it came from NOT
            {
                expr_P trueExpr = newExpr(constbool_e, NULL);
                trueExpr->boolConst = '1';
                expr_P falseExpr = newExpr(constbool_e, NULL);
                falseExpr->boolConst = '0';
                $1->sym = newTemp(&offset, getSpace());
                expr_P numExpr = newExpr(constnum_e, NULL);
                

                backPatchList($1->truelist,nextQuadLabel());
                emit(iop_assign, trueExpr, NULL, $1, nextQuadLabel(), alpha_yylineno);
                numExpr->numConst = nextQuadLabel()+2;
                emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);
                backPatchList($1->falselist, nextQuadLabel());
                emit(iop_assign, falseExpr, NULL, $1, nextQuadLabel(), alpha_yylineno);
            } 
            printMessage("stmt -> exp;");
        } |
        ifstmt { printMessage("stmt -> if statement");} |
        whilestmt { printMessage("stmt -> while statement");} |
        forstmt { printMessage("stmt -> for statement");}  |
        returnstmt { printMessage("stmt -> return statement");} |
        BREAK Semicolon { 

            if(isLoopStackEmpty() == 1 || openloops == 0)
            {
                printf(ANSI_COLOR_RED"Syntax error in line <%d>: break usage is not allowed outside of a loop"ANSI_COLOR_RESET"\n", alpha_yylineno);
                exit(-1); 
            }
            else
            {
                breakPush(nextQuadLabel()); //put break label to the currect loop break list
                emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
            }

            printMessage("stmt -> break; statement");
        } |
        CONTINUE Semicolon { 

            if(isLoopStackEmpty() == 1 || openloops == 0)
            {
                printf(ANSI_COLOR_RED"Syntax error in line <%d>: continue usage is not allowed outside of a loop"ANSI_COLOR_RESET"\n", alpha_yylineno);
                exit(-1); 
            }
            else
            {
                contPush(nextQuadLabel()); //put continue label to the currect loop break list
                emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
            }
            
            printMessage("stmt -> continue; statement");
        } |
        block { printMessage("stmt -> block statement");} |
        funcdef { printMessage("stmt -> funcdef statement");} |
        Semicolon { printMessage("stmt -> Semicolon statement");}
    ;

expr:   assignexpr { $$ = $1; printMessage("expr -> assignexpr"); } |
        expr plus expr {
            expr_P result = $1; 
            if(result->type == arithexpr_e && result->sym->varName[0] == '_')   /*optimized code, use the same temp var to store the result*/
            {
                emit(iop_add, $1, $3, result, nextQuadLabel(), alpha_yylineno);
            }
            else
            {
                symbol_T temp = newTemp(&offset, getSpace());   /*gave pointer to offset because i don't know if i'll get a new var or not*/
                result = newExpr(arithexpr_e, temp);
                emit(iop_add, $1, $3, result, nextQuadLabel(), alpha_yylineno);
            }
            
            $$ = result;
            printMessage("expr -> expr + expr");
        } |
        expr minus expr {           
            expr_P result = $1; 
            if(result->type == arithexpr_e && result->sym->varName[0] == '_')   /*optimized code*/
            {
                emit(iop_sub, $1, $3, result, nextQuadLabel(), alpha_yylineno);
            }
            else
            {
                symbol_T temp = newTemp(&offset, getSpace());
                result = newExpr(arithexpr_e, temp);
                emit(iop_sub, $1, $3, result, nextQuadLabel(), alpha_yylineno);
            }
            
            $$ = result;
            printMessage("expr -> expr - expr");
        } |
        expr mul expr {
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(arithexpr_e, temp);
            $$ = result;
            emit(iop_mul, $1, $3, result, nextQuadLabel(), alpha_yylineno); printMessage("expr -> expr * expr");
        } |
        expr divide expr {
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(arithexpr_e, temp);
            $$ = result;
            emit(iop_div, $1, $3, result, nextQuadLabel(), alpha_yylineno); printMessage("expr -> expr / expr");
        } |
        expr mod expr {
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(arithexpr_e, temp);
            $$ = result;
            emit(iop_mod, $1, $3, result, nextQuadLabel(), alpha_yylineno); printMessage("expr -> expr % expr");
        } |
        expr greater expr {
            $$ = newExpr(boolexpr_e, NULL);
            $$->truelist = makelist(nextQuadLabel());
            $$->falselist = makelist(nextQuadLabel()+1);
            emit(if_greater, $1, $3, NULL, nextQuadLabel(), alpha_yylineno);
            emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
            printMessage("expr -> expr > expr");
        } |
        expr ge expr {
            $$ = newExpr(boolexpr_e, NULL);
            $$->truelist = makelist(nextQuadLabel());
            $$->falselist = makelist(nextQuadLabel()+1);
            emit(if_greatereq, $1, $3, NULL, nextQuadLabel(), alpha_yylineno);
            emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
            printMessage("expr -> expr >= expr");
        } |
        expr less expr {
            $$ = newExpr(boolexpr_e, NULL);
            $$->truelist = makelist(nextQuadLabel());
            $$->falselist = makelist(nextQuadLabel()+1);
            emit(if_less, $1, $3, NULL, nextQuadLabel(), alpha_yylineno);
            emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
            printMessage("expr -> expr < expr");
        } |
        expr le expr {
            $$ = newExpr(boolexpr_e, NULL);
            $$->truelist = makelist(nextQuadLabel());
            $$->falselist = makelist(nextQuadLabel()+1);
            emit(if_lesseq, $1, $3, NULL, nextQuadLabel(), alpha_yylineno);
            emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
            printMessage("expr -> expr <= expr");
        } |
        expr equal {

            if($1->type == boolexpr_e)
            {
                expr_P trueExpr = newExpr(constbool_e, NULL);
                trueExpr->boolConst = '1';
                expr_P falseExpr = newExpr(constbool_e, NULL);
                falseExpr->boolConst = '0';
                expr_P numExpr = newExpr(constnum_e, NULL);
                $1->sym = newTemp(&offset, getSpace());

                backPatchList($1->truelist, nextQuadLabel());
                emit(iop_assign, trueExpr, NULL, $1, nextQuadLabel(), alpha_yylineno);
                numExpr->numConst = nextQuadLabel()+2;
                emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);
                backPatchList($1->falselist, nextQuadLabel());
                emit(iop_assign, falseExpr, NULL, $1, nextQuadLabel(), alpha_yylineno);
            }
        } expr {

            if($4->type == boolexpr_e)
            {
                expr_P trueExpr = newExpr(constbool_e, NULL);
                trueExpr->boolConst = '1';
                expr_P falseExpr = newExpr(constbool_e, NULL);
                falseExpr->boolConst = '0';
                expr_P numExpr = newExpr(constnum_e, NULL);

                $4->sym = newTemp(&offset, getSpace());
                backPatchList($4->truelist, nextQuadLabel());
                emit(iop_assign, trueExpr, NULL, $4, nextQuadLabel(), alpha_yylineno);
                numExpr->numConst = nextQuadLabel()+2;
                emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);
                backPatchList($4->falselist,nextQuadLabel());
                emit(iop_assign, falseExpr, NULL, $4, nextQuadLabel(), alpha_yylineno);
            }

            $$ = newExpr(boolexpr_e, NULL);
            $$->truelist = makelist(nextQuadLabel());
            $$->falselist = makelist(nextQuadLabel()+1);
            emit(if_eq, $1, $4, NULL, nextQuadLabel(), alpha_yylineno);
            emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
            printMessage("expr -> expr == expr");
        } |
        expr neq {

            if($1->type == boolexpr_e)
            {
                expr_P trueExpr = newExpr(constbool_e, NULL);
                trueExpr->boolConst = '1';
                expr_P falseExpr = newExpr(constbool_e, NULL);
                falseExpr->boolConst = '0';
                expr_P numExpr = newExpr(constnum_e, NULL);
                $1->sym = newTemp(&offset, getSpace());

                backPatchList($1->truelist, nextQuadLabel());
                emit(iop_assign, trueExpr, NULL, $1, nextQuadLabel(), alpha_yylineno);
                numExpr->numConst = nextQuadLabel()+2;
                emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);
                backPatchList($1->falselist, nextQuadLabel());
                emit(iop_assign, falseExpr, NULL, $1, nextQuadLabel(), alpha_yylineno);
            }

        } expr {

            if($4->type == boolexpr_e)
            {
                expr_P trueExpr = newExpr(constbool_e, NULL);
                trueExpr->boolConst = '1';
                expr_P falseExpr = newExpr(constbool_e, NULL);
                falseExpr->boolConst = '0';
                expr_P numExpr = newExpr(constnum_e, NULL);

                $4->sym = newTemp(&offset, getSpace());

                backPatchList($4->truelist, nextQuadLabel());
                emit(iop_assign, trueExpr, NULL, $4, nextQuadLabel(), alpha_yylineno);
                numExpr->numConst = nextQuadLabel()+2;
                emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);
                backPatchList($4->falselist, nextQuadLabel());
                emit(iop_assign, falseExpr, NULL, $4, nextQuadLabel(), alpha_yylineno);
            }

            $$ = newExpr(boolexpr_e, NULL);
            $$->truelist = makelist(nextQuadLabel());
            $$->falselist = makelist(nextQuadLabel()+1);
            emit(if_noteq, $1, $4, NULL, nextQuadLabel(), alpha_yylineno);
            emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);

            printMessage("expr -> expr != expr");
        } |

        expr AND {
            if($1->type != boolexpr_e)
            {
                expr_P bool_expr = newExpr(constbool_e, NULL);
                bool_expr->boolConst = '1';
                $1->truelist = makelist(nextQuadLabel());
                $1->falselist = makelist(nextQuadLabel()+1);
                emit(if_eq, bool_expr, $1, NULL, nextQuadLabel(), alpha_yylineno);
                emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);

                backPatchList($1->truelist, nextQuadLabel());
	        }
        }
        
        M expr  {

        $$ = newExpr(boolexpr_e, NULL);

        //typecheck for arguments that are not boolean and create logic lists for them
        if($5->type != boolexpr_e)
        {
            expr_P bool_expr = newExpr(constbool_e, NULL);
            bool_expr->boolConst = '1';
            $5->truelist = makelist(nextQuadLabel());
            $5->falselist = makelist(nextQuadLabel()+1);
            emit(if_eq, bool_expr, $5, NULL, nextQuadLabel(), alpha_yylineno);
            emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
        }
        
        if($1->type == boolexpr_e)
        {
            backPatchList($1->truelist, $4);
            printf(ANSI_COLOR_GREEN"Backpatching to %d"ANSI_COLOR_RESET"\n", $4);
        }

        $$->truelist = $5->truelist;
        $$->falselist = mergeLocicLists($1->falselist,$5->falselist);
        printMessage("expr -> expr AND expr");
    } |

    expr OR { 
            if($1->type != boolexpr_e)
            {
                expr_P bool_expr = newExpr(constbool_e, NULL);
                bool_expr->boolConst = '1';
                $1->truelist = makelist(nextQuadLabel());
                $1->falselist = makelist(nextQuadLabel()+1);
                emit(if_eq, bool_expr, $1, NULL, nextQuadLabel(), alpha_yylineno);
                emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);

                backPatchList($1->falselist, nextQuadLabel());
	        }
        } 
    M expr    {   

        $$ = newExpr(boolexpr_e, NULL);

        //typecheck for arguments that are not boolean and create logic lists for them
        if($5->type != boolexpr_e){
            expr_P bool_expr = newExpr(constbool_e, NULL);
            bool_expr->boolConst = '1';
            $5->truelist   = makelist(nextQuadLabel());
            $5->falselist  = makelist(nextQuadLabel()+1);
            emit(if_eq, bool_expr, $5, NULL, nextQuadLabel(), alpha_yylineno);
            emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
        }

        if($1->type == boolexpr_e)
        {
            backPatchList($1->falselist,$4);
        }

        $$->truelist = mergeLocicLists($1->truelist,$5->truelist);
        $$->falselist = $5->falselist;
        printMessage("expr -> expr OR expr");

    } |
        term { $$ = $1; printMessage("expr -> term"); }
    ;

M:  { $$ = nextQuadLabel(); }


term:   Lparenthesis expr Rparenthesis {  
            $$ = $2;
            printMessage("term -> (expr)"); 
        } |
        minus expr %prec uminus {   /*%prec uminus gia na deixw oti exei idia proteraiothta me to dhlwmeno uminus*/
            expr_P numExpr = newExpr(constnum_e, NULL);
            numExpr->numConst = -1;
            
            check_for_func_error($2->sym);

            $$ = newExpr(arithexpr_e, newTemp(&offset, getSpace()));
            emit(iop_mul, numExpr, $2, $$, nextQuadLabel(), alpha_yylineno);

            printMessage("term -> uminus expr");
        } |
        NOT expr    {
            $$ = newExpr(boolexpr_e, NULL);
            $$->sym = $2->sym;

            if($2->type != boolexpr_e)
            {
                expr_P trueExpr = newExpr(constbool_e, NULL);
                trueExpr->boolConst = '1';
                $$->truelist = makelist(nextQuadLabel()+1);
                $$->falselist = makelist(nextQuadLabel());
                emit(if_eq, trueExpr, $2, NULL, nextQuadLabel(), alpha_yylineno);
                emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
            }
            else
            {
                $$->truelist = $2->falselist;
                $$->falselist = $2->truelist;
            }

            printMessage("term -> not expr");
        } |
        plusplus lvalue { 
            $$ = $2;
            expr_P exprPtr = $2, numExpr = newExpr(constnum_e, NULL);
            numExpr->numConst = 1;

            check_for_func_error(exprPtr->sym);

            if($2->type == tableitem_e)
            {
                expr_P result = newExpr(var_e, newTemp(&offset, getSpace()));
                emit(tablegetelem, $2, $2->index, result, nextQuadLabel(), alpha_yylineno);
                $$ = result;

                emit(iop_add, $$, numExpr, $$, nextQuadLabel(), alpha_yylineno);
                emit(tablesetelem, $2, $2->index, $$ ,nextQuadLabel(), alpha_yylineno);
            }
            else
            {
                emit(iop_add, $2, numExpr, $2, nextQuadLabel(), alpha_yylineno);
                $$ = newExpr(arithexpr_e, newTemp(&offset, getSpace()));
                emit(iop_assign, $2, NULL, $$, nextQuadLabel(), alpha_yylineno);
            }

            printMessage("term -> ++lvalue");
        } |
        lvalue plusplus { 
            expr_P exprPtr = $1, numExpr = newExpr(constnum_e, NULL);
            numExpr->numConst = 1;
            $$ = newExpr(var_e, newTemp(&offset, getSpace()));

            check_for_func_error(exprPtr->sym); 

            if($1->type == tableitem_e)
            {
                expr_P value = newExpr(var_e, newTemp(&offset, getSpace()));
                emit(tablegetelem, $1, $1->index, value, nextQuadLabel(), alpha_yylineno);

                emit(iop_assign, value, NULL, $$, nextQuadLabel(), alpha_yylineno);
                emit(iop_add, value, numExpr, value, nextQuadLabel(), alpha_yylineno);
                emit(tablesetelem, $1, $1->index, value, nextQuadLabel(), alpha_yylineno);
            }
            else
            {
                emit(iop_assign, $1, NULL, $$, nextQuadLabel(), alpha_yylineno); /*assign old value to a temp, post increment*/
                emit(iop_add, $1, numExpr, $1, nextQuadLabel(), alpha_yylineno);
            }

            printMessage("term -> lvalue++");
        } |
        minusminus lvalue   { 
            $$ = $2;
            expr_P exprPtr = $2, numExpr = newExpr(constnum_e, NULL);
            numExpr->numConst = 1;

            check_for_func_error(exprPtr->sym);

            if($2->type == tableitem_e)
            {
                expr_P value = newExpr(var_e, newTemp(&offset, getSpace()));
                emit(tablegetelem, $2, $2->index, value, nextQuadLabel(), alpha_yylineno);
                $$ = value;

                emit(iop_sub, $$, numExpr, $$, nextQuadLabel(), alpha_yylineno);
                emit(tablesetelem, $2, $2->index, $$, nextQuadLabel(), alpha_yylineno);
            }
            else
            {
                emit(iop_sub, $2, numExpr, $2, nextQuadLabel(), alpha_yylineno); /*pre decrement*/
                $$ = newExpr(arithexpr_e, newTemp(&offset, getSpace()));
                emit(iop_assign, $2, NULL, $$, nextQuadLabel(), alpha_yylineno);
            }

            printMessage("term -> --lvalue");
        } |
        lvalue minusminus   { 
            expr_P exprPtr = $1, numExpr = newExpr(constnum_e, NULL);
            numExpr->numConst = 1;

            $$ = newExpr(var_e, newTemp(&offset, getSpace()));

            check_for_func_error(exprPtr->sym);

            if($1->type == tableitem_e)
            {
                expr_P value = newExpr(var_e, newTemp(&offset, getSpace()));
                emit(tablegetelem, $1, $1->index, value, nextQuadLabel(), alpha_yylineno);

                emit(iop_assign, value, NULL, $$, nextQuadLabel(), alpha_yylineno);
                emit(iop_sub, value, numExpr, value, nextQuadLabel(), alpha_yylineno);
                emit(tablesetelem, $1, $1->index, value, nextQuadLabel(), alpha_yylineno);
            }
            else
            { 
                emit(iop_assign, $1, NULL, $$, nextQuadLabel(), alpha_yylineno); /*assign old value to a temp, post decrement*/
                emit(iop_sub, $1, numExpr, $1, nextQuadLabel(), alpha_yylineno);
            }

            printMessage("term -> lvalue--");
        } |
        primary { $$ = $1; printMessage("term -> primary");}
    ;

assignexpr:     lvalue assign expr  {

            expr_P trueExpr = newExpr(constbool_e, NULL);
            trueExpr->boolConst = '1';
            expr_P falseExpr = newExpr(constbool_e, NULL);
            falseExpr->boolConst = '0';

            check_for_func_error($1->sym);

            if($3->type == boolexpr_e)
            {
                expr_P numExpr = newExpr(constnum_e, NULL);
                
                $3->sym = newTemp(&offset, getSpace());
                
                backPatchList($3->truelist, nextQuadLabel());
                emit(iop_assign, trueExpr, NULL, $3, nextQuadLabel(), alpha_yylineno);

                numExpr->numConst = nextQuadLabel()+2;
                emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);
                backPatchList($3->falselist, nextQuadLabel());
                emit(iop_assign, falseExpr, NULL, $3, nextQuadLabel(), alpha_yylineno);
            }

            if($1->type == tableitem_e)
            {
                emit(tablesetelem, $1, $1->index, $3, nextQuadLabel(), alpha_yylineno);
                printf(ANSI_COLOR_GREEN"$1->index->numConst : %d, $3 numConst : %d\n"ANSI_COLOR_RESET, $1->index->numConst, $3->numConst);
                expr* lvalue = $1;
                if($1->type == tableitem_e)
                {
                    lvalue = newExpr(var_e, newTemp(&offset, getSpace()));
                    emit(tablegetelem, $1, $1->index, lvalue, nextQuadLabel(), alpha_yylineno);
                }
                $$ = lvalue;
                $$->type = assignexpr_e;
            }
            else
            {
                $1 = newExpr(var_e, $1->sym);
                emit(iop_assign, $3, NULL, $1, nextQuadLabel(), alpha_yylineno);

                $$ = newExpr(assignexpr_e, newTemp(&offset, getSpace()));
                emit(iop_assign, $1, NULL, $$, nextQuadLabel(), alpha_yylineno);
            }

            
            printMessage("assignexpr -> lvalue = expr");}
    ;

primary:    lvalue  {
                if($1->type == tableitem_e)
                {
                    $$ = newExpr(var_e, newTemp(&offset, getSpace()));
                    emit(tablegetelem, $1, $1->index, $$, nextQuadLabel(), alpha_yylineno);
                }
                else
                    $$ = $1;

                printMessage("primary -> lvalue"); 
            }    |
            call    { $$ = $1; printMessage("primary -> call"); }    |
            objectdef   { $$ = $1; printMessage("primary -> objectdef"); }   |
            Lparenthesis funcdef Rparenthesis { $$ = $2; printMessage("primary -> (funcdef)"); } |
            const   { $$ = $1; printMessage("primary -> const"); }
    ;

lvalue:     ID  {
                    symbol_T sym = search_from_scope_out($1, scope);
                    enum SymbolCategory category;
                    expr_P exprPtr = NULL;

                    if(sym == NULL) /*if you can't find anything add new symbol*/
                    {
                        if(scope == 0)
                            category = global_var;
                        else
                            category = local_var;

                        sym = addSymbol($1, category, scope, alpha_yylineno, offset, getSpace());
                        offset++;
                        printf("Added symbol\n");
                    }
                    /*else sym != NULL*/
                    else if(sym->scope != 0) /*if you find a global var, refer to that. if you are inside a function you can't access anything except global or args or local*/
                    {
                        /*check the function stack and if symbol scope <= of function then error*/
                        symbol_T tmp = getActiveFunctionFromScopeOut(scope-1);  /*functions stay active after their block is closed, so for this search to be correct we need to look 1 level higher*/
                        
                        if(tmp != NULL && sym->scope <= tmp->scope)
                        {
                            printf(ANSI_COLOR_RED"Syntax error in line <%d>: cannot access %s inside function."ANSI_COLOR_RESET"\n", alpha_yylineno, $1);
                            exit(-1);   /*call yacc error manager*/
                        }
                    }

                    exprPtr = newExpr(var_e, sym);
                    $$ = exprPtr;
                    printf("lvalue -> ID\n");
            }   |
            local ID    {
                    symbol_T sym = getElement($2, scope);
                    expr_P exprPtr = NULL;

                    if(sym!= NULL && sym->category == func_arg && sym->active == 1)
                    {
                        /*printf("local x == arg x\n");*/
                    } 
                    else if (scope == 0) /*if global ignore local*/
                    {
                        sym = addSymbol($2, global_var, scope, alpha_yylineno, offset, getSpace());
                        offset++;
                        printf("Added global %s (ignored local)\n", $2);
                    }
                    else
                    {
                        sym = addSymbol($2, local_var, scope, alpha_yylineno, offset, getSpace());
                        offset++;
                        printf("Added local %s\n", $2);
                    }

                    exprPtr = newExpr(var_e, sym);
                    $$ = exprPtr;
                    printMessage("lvalue -> local ID"); 
            } |
            coloncolon ID   {
                symbol_T sym = getElement($2, 0); /*:: means we search in global scope*/
                expr_P exprPtr = NULL;

                if(sym == NULL)
                {
                    printf(ANSI_COLOR_RED"Syntax error in line <%d>: no global variable or function %s"ANSI_COLOR_RESET"\n", alpha_yylineno, $2);
                    exit(-1);
                }
                
                exprPtr = newExpr(var_e, sym);
                $$ = exprPtr;
                printMessage("lvalue -> :: ID"); 
            } |
            member  { $$ = $1; printMessage("lvalue -> member"); }
    ;

member:     lvalue dot ID   {
                expr* lvalue = $1;

                if($1->type == tableitem_e)
                {
                    lvalue = newExpr(var_e, NULL);
                    lvalue->sym = newTemp(&offset, getSpace());
                    emit(tablegetelem, $1, $1->index, lvalue, nextQuadLabel(), alpha_yylineno);
                }
                
                $$ = newExpr(tableitem_e, NULL);
                $$->sym = lvalue->sym;
                $$->index = newExpr(conststring_e, NULL);
	            $$->index->strConst = strdup($3);

                printMessage("member -> lvalue.ID"); 
        }    |
            lvalue LSquareBracket expr RSquareBracket   {
                 if($3->type == boolexpr_e)
                 {
                    expr_P trueExpr = newExpr(constbool_e, NULL);
                    trueExpr->boolConst = '1';
                    expr_P falseExpr = newExpr(constbool_e, NULL);
                    falseExpr->boolConst = '0';
                    expr_P numExpr = newExpr(constnum_e, NULL);

                    $3->sym = newTemp(&offset, getSpace());
                    
                    backPatchList($3->truelist, nextQuadLabel());
                    emit(iop_assign, trueExpr, NULL, $3, nextQuadLabel(), alpha_yylineno);
                    numExpr->numConst = nextQuadLabel()+2;
                    emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);
                    backPatchList($3->falselist, nextQuadLabel());
                    emit(iop_assign, falseExpr, NULL, $3, nextQuadLabel(), alpha_yylineno);
                }

                expr* lvalue = $1;

                if($1->type == tableitem_e)
                {
                    lvalue = newExpr(var_e, newTemp(&offset, getSpace()));
                    emit(tablegetelem, $1, $1->index, lvalue, nextQuadLabel(), alpha_yylineno);
                }

                $$ = newExpr(tableitem_e, NULL);
                $$->sym = lvalue->sym;
                $$->index = $3;

                printMessage("member -> lvalue[expr]"); 
        }    |
            call dot ID { printMessage("member -> call.ID"); }  |
            call LSquareBracket expr RSquareBracket { printMessage("member -> call[expr]"); }
    ;

call:       call Lparenthesis elist Rparenthesis    { 
                $$ = rule_call($$, $3, &offset, getSpace(), scope, alpha_yylineno);
                
                printMessage("call -> call(elist)");
        }   |
            lvalue callsuffix   {
                expr* tmp = $2->elist;  //elist tou call (normal or method call)

                if(is_lib_func($1->sym->varName) == 1)
                    $1->type = libraryfunc_e;
                
               
                if($2->isMethod == 1)
                {
                    expr* func = $1;
                    expr* memberItem;
                    expr* result = func;
                    if(func->type == tableitem_e)
                    {
                        result = newExpr(var_e, newTemp(&offset, getSpace()));
                        emit(tablegetelem, func, func->index, result, nextQuadLabel(), alpha_yylineno);
                    }

                    memberItem = newExpr(tableitem_e, result->sym);
                    memberItem->index = newExpr(conststring_e, NULL);
                    memberItem->index->strConst = $2->name;


                    $1 = memberItem;
                    if(memberItem->type == tableitem_e)
                    {
                        $1 = newExpr(var_e, newTemp(&offset, getSpace()));
                        emit(tablegetelem, memberItem, memberItem->index, $1, nextQuadLabel(), alpha_yylineno);
                    }


                    func->next = tmp;   //connect func expr with elist
                    $2->elist = func;
                }
                if($1->type != libraryfunc_e && $2->isMethod == 0)
                    $1->type = programfunc_e;

                $$ = rule_call($1, $2->elist, &offset, getSpace(), scope, alpha_yylineno);

                printMessage("call -> lvalue callsuffix");
        }  |
            Lparenthesis funcdef Rparenthesis Lparenthesis elist Rparenthesis   {
                expr* func  = newExpr(programfunc_e, $2->sym);
                $$ = rule_call(func, $5, &offset, getSpace(), scope, alpha_yylineno);

                printMessage("call -> (funcdef)(elist)");
            }
    ;

callsuffix: normcall    { $$ = $1; printMessage("callsuffix -> normcall"); } |
            methodcall  { $$ = $1; printMessage("callsuffix -> methodcall"); }
    ;

normcall:   Lparenthesis elist Rparenthesis {
                method_call *meth_call = (method_call *) malloc(sizeof(struct method_call));
                
                if(meth_call == NULL)
                {
                    printf("Error with malloc in normcall call rule.\n");
                    exit(-1);
                }

                $$ = meth_call;
                $$->elist = $2;
                $$->isMethod = 0;
                $$->name = NULL;
                printMessage("normcall -> (elist)");
            }
    ;

methodcall: dotdot ID Lparenthesis elist Rparenthesis   { 
                method_call *meth_call = (method_call *) malloc(sizeof(struct method_call));
                
                if(meth_call == NULL)
                {
                    printf("Error with malloc in normcall call rule.\n");
                    exit(-1);
                }

                $$ = meth_call;
                $$->elist = $4;
                $$->isMethod = 1;
                $$->name = $2;

                printMessage("..ID(elist)"); 
            }
    ;

elist: expr { 
        if($1->type == boolexpr_e)
        {
            expr_P trueExpr = newExpr(constbool_e, NULL);
            trueExpr->boolConst = '1';
            expr_P falseExpr = newExpr(constbool_e, NULL);
            falseExpr->boolConst = '0';
            expr_P numExpr = newExpr(constnum_e, NULL);

            $1->sym = newTemp(&offset, getSpace());
            
            backPatchList($1->truelist, nextQuadLabel());
            emit(iop_assign, trueExpr, NULL, $1, nextQuadLabel(), alpha_yylineno);

            numExpr->numConst = nextQuadLabel()+2;
            emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);
            backPatchList($1->falselist, nextQuadLabel());
            emit(iop_assign, falseExpr, NULL, $1, nextQuadLabel(), alpha_yylineno);         
        }

        $$ = $1; 
        printMessage("elist -> expr"); 
    }   |
        elist comma expr    {
            if($3->type == boolexpr_e)
            {
                expr_P trueExpr = newExpr(constbool_e, NULL);
                trueExpr->boolConst = '1';
                expr_P falseExpr = newExpr(constbool_e, NULL);
                falseExpr->boolConst = '0';
                expr_P numExpr = newExpr(constnum_e, NULL);

                $3->sym = newTemp(&offset, getSpace());
                
                backPatchList($3->truelist, nextQuadLabel());
                emit(iop_assign, trueExpr, NULL, $3, nextQuadLabel(), alpha_yylineno);

                numExpr->numConst = nextQuadLabel()+2;
                emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);
                backPatchList($3->falselist, nextQuadLabel());
                emit(iop_assign, falseExpr, NULL, $3, nextQuadLabel(), alpha_yylineno); 
            }

            expr_P tmp = $1;
            while(tmp->next != NULL)    /*go to the end of the list*/
            {
                tmp = tmp->next;
            }
                
            tmp->next = $3;
            $$ = $1;    /*return the first element of the list*/
            printMessage("elist -> elist,expr"); 
    }    |
        { $$ = newExpr(nil_e, NULL); printMessage("elist -> empty"); }
    ;

objectdef:  LSquareBracket elist RSquareBracket {
            expr_P exprPtr = NULL, tmp = $2, tableItemexpr = NULL;
            
            exprPtr = newExpr(newtable_e, NULL);
            exprPtr->sym = newTemp(&offset, getSpace());
            emit(tablecreate, NULL, NULL, exprPtr, nextQuadLabel(), alpha_yylineno);
            for (int i = 0; tmp != NULL; tmp = tmp->next)
            {
                tableItemexpr = newExpr(constnum_e, NULL);
                tableItemexpr->numConst = i++;
                emit(tablesetelem, exprPtr, tableItemexpr, tmp, nextQuadLabel(), alpha_yylineno);
            }
            $$ = exprPtr;
            printMessage("objectdef -> [elist]");
    }   |
            LSquareBracket indexed RSquareBracket   {
            expr_P exprPtr = NULL, tmp = $2;
            
            exprPtr = newExpr(newtable_e, NULL);
            exprPtr->sym = newTemp(&offset, getSpace());
            emit(tablecreate, NULL, NULL, exprPtr, nextQuadLabel(), alpha_yylineno);
            for (int i = 0; tmp != NULL; tmp = tmp->next)
            {
                emit(tablesetelem, exprPtr, tmp->index, tmp->indexedVal, nextQuadLabel(), alpha_yylineno);
            }
            $$ = exprPtr;
            
            printMessage("objectdef -> [indexed]"); 
    }
    ;

indexed:    indexedelem { $$ = $1; printMessage("indexed -> indexedelem"); } |
            indexed comma indexedelem { 
                expr* tmp = $1;
                while(tmp->next != NULL)
                {
                    tmp = tmp->next;
                }
                tmp->next = $3;
                $$ = $1;
                printMessage("indexed -> indexed, indexedelem");
            }
    ;

indexedelem:    LCurlyBracket expr colon expr RCurlyBracket { 
                 if($4->type == boolexpr_e)
                 {
                    expr_P trueExpr = newExpr(constbool_e, NULL);
                    trueExpr->boolConst = '1';
                    expr_P falseExpr = newExpr(constbool_e, NULL);
                    falseExpr->boolConst = '0';
                    expr_P numExpr = newExpr(constnum_e, NULL);

                    $4->sym = newTemp(&offset, getSpace());;
                    
                    backPatchList($4->truelist, nextQuadLabel());
                    emit(iop_assign, trueExpr, NULL, $4, nextQuadLabel(), alpha_yylineno);
                    numExpr->numConst = nextQuadLabel() + 2;
                    emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);
                    backPatchList($4->falselist, nextQuadLabel());
                    emit(iop_assign, falseExpr, NULL, $4, nextQuadLabel(), alpha_yylineno);
                }

                $$ = newExpr(tableitem_e, NULL);
                $$->index = $2;
                $$->indexedVal = $4;

                printMessage("indexedelem -> {expr:expr}"); }
    ;

block: LCurlyBracket {scope++; printf("block scope %d\n", scope);} stmts RCurlyBracket { hide_in_scope(scope); scope--; printMessage("block -> {stmts}"); } 
    ;

funcdef:    FUNCTION ID {
                symbol_T sym = getElement($2, scope);
                if(sym != NULL)
                {
                    printf(ANSI_COLOR_RED"Syntax error in line <%d>: redeclaration of %s as function"ANSI_COLOR_RESET"\n", alpha_yylineno, $2);
                    exit(-1);
                }
                sym = addSymbol($2, user_func, scope, alpha_yylineno, offset, getSpace()); 
                //offset++;   /*functions count as variables?*/

                push_func($2, scope, nextQuadLabel());
                offset_push(offset);
                expr_P expr = newExpr(programfunc_e, sym);
                
                sym->iaddress = nextQuadLabel();
                emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno); /*create empty jump that will later be filled with the end of this function*/
                emit(funcstart, NULL, NULL, expr, nextQuadLabel(), alpha_yylineno);

                printf("OFFSET BEFORE FUNC %d\n", offset);
                offset = 0;
            } 
            Lparenthesis idlist Rparenthesis {
                symbol_T sym = getElement($2, scope);
                if(sym == NULL)
                {
                    printf(ANSI_COLOR_RED"Symbol table, could not find function symbol %s, error in line <%d>"ANSI_COLOR_RESET"\n", $2, alpha_yylineno);
                    exit(-1);
                }
                sym->totalargs = totalFuncArgs;
                totalFuncArgs = 0;
                printf(ANSI_COLOR_GREEN"formal args counter : %d"ANSI_COLOR_RESET"\n", sym->totalargs);
                allowReturn++;
                openloops = 0;
            }
            block  {
                symbol_T sym = getElement($2, scope);
                expr_P expr = newExpr(programfunc_e, sym);

                stack_T funcStruct = pop_func();

                $$ = expr;
                emit(funcend, NULL, NULL, expr, nextQuadLabel(), alpha_yylineno);
                patchLabel(funcStruct->startLabel, nextQuadLabel());

                sym->totallocals = offset - sym->totalargs; //each time the offset is saved in a stack so i can calculate the locals this way
                offset_stack_T offsettmp = offset_pop();
                offset = offsettmp->offset; 
                allowReturn--;
                printf("OFFSET AFTER FUNC %d\n", offset);   //remove this later

                printMessage("funcdef -> function id(idlist){stmts}");
            }   |
            FUNCTION {
                symbol_T sym = add_anonymus_func(scope, alpha_yylineno, offset, getSpace());

                //offset++;   /*functions count as variables?*/
                offset_push(offset);
                push_func(sym->varName, scope, nextQuadLabel());
                expr_P expr = newExpr(programfunc_e, sym);
                
                sym->iaddress = nextQuadLabel();
                emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
                emit(funcstart, NULL, NULL, expr, nextQuadLabel(), alpha_yylineno);
                printf("OFFSET BEFORE FUNC %d\n", offset);
                
                offset = 0;
            } Lparenthesis idlist Rparenthesis {
                symbol_T func = getActiveFunctionFromScopeOut(scope);
                if(func == NULL)
                {
                    printf(ANSI_COLOR_RED"Symbol table, could not find anonymus function symbol, error in line <%d>"ANSI_COLOR_RESET"\n", alpha_yylineno);
                    exit(-1);
                }
                func->totalargs = totalFuncArgs;
                totalFuncArgs = 0;
                printf(ANSI_COLOR_GREEN"formal args for anonymus func counter : %d"ANSI_COLOR_RESET"\n", func->totalargs);
                allowReturn++;
                openloops = 0;
            } block {
                symbol_T func = getActiveFunctionFromScopeOut(scope);
                expr_P expr = newExpr(programfunc_e, func);
                stack_T funcStruct = pop_func();
                emit(funcend, NULL, NULL, expr, nextQuadLabel(), alpha_yylineno);
                patchLabel(funcStruct->startLabel, nextQuadLabel());
                allowReturn--;
                func->totallocals = offset - func->totalargs;
                offset_stack_T offsettmp = offset_pop();
                offset = offsettmp->offset;
                printf("OFFSET AFTER FUNC %d\n", offset);   //remove this later
                
                $$ = expr;
                printMessage("funcdef -> function(idlist){}"); 
            }
    ;

const:  NUMBER  {
            expr_P expr = newExpr(constnum_e, NULL);
            expr->numConst = $1;
            $$ = expr;
            printf("const -> number (%f)\n", expr->numConst);
        }    |
        STRING  {
            expr_P expr = newExpr(conststring_e, NULL);
            expr->strConst = $1;
            $$ = expr;
            printMessage("const -> string");
        }    |
        NIL     {
            expr_P expr = newExpr(nil_e, NULL);
            $$ = expr;
            printMessage("const -> nil");
        }    |
        TRUE    {
            expr_P expr = newExpr(constbool_e, NULL);
            expr->boolConst = '1';
            $$ = expr;
            printMessage("const -> true");
        }    |
        FALSE   {
            expr_P expr = newExpr(constbool_e, NULL);
            expr->boolConst = '0';
            $$ = expr;
            printMessage("const -> false"); }     
    ;

idlist:     ID  {
                symbol_T sym = addSymbol($1, func_arg, scope+1, alpha_yylineno, offset, formalArg);
                offset++;
                totalFuncArgs++;
                
                if(sym == NULL)
                {
                    printf(ANSI_COLOR_RED"Syntax error in line <%d>: argument %s is already declared"ANSI_COLOR_RESET"\n", alpha_yylineno, $1);
                    exit(-1);
                }
                printMessage("idlist -> ID"); 
            }   |
            idlist comma ID {
                symbol_T sym = addSymbol($3, func_arg, scope+1, alpha_yylineno, offset, formalArg);
                offset++;
                totalFuncArgs++;

                if(sym == NULL)
                {
                    printf(ANSI_COLOR_RED"Syntax error in line <%d>: argument %s is already declared"ANSI_COLOR_RESET"\n", alpha_yylineno, $1);
                    exit(-1);
                }
                
                printMessage("idlist -> idlist,ID"); 
            }   |
                { printMessage("idlist -> empty"); }
    ;

ifstmtprefix:   IF Lparenthesis expr Rparenthesis 
                {
                    expr_P trueExpr = newExpr(constbool_e, NULL);
                    trueExpr->boolConst = '1';
                    
                    expr_P numExpr = newExpr(constnum_e, NULL);
                    

                    if($3->type == boolexpr_e)
                    {
                        $3->sym = newTemp(&offset, getSpace());
                        
                        expr_P falseExpr = newExpr(constbool_e, NULL);
                        falseExpr->boolConst = '0';
                        
                        backPatchList($3->truelist, nextQuadLabel());

                        emit(iop_assign, trueExpr, NULL, $3, nextQuadLabel(), alpha_yylineno);
                        numExpr->numConst = nextQuadLabel() + 2;
                        emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);

                        backPatchList($3->falselist,nextQuadLabel());

                        emit(iop_assign, $3, falseExpr, NULL, nextQuadLabel(), alpha_yylineno);
                    }

                    numExpr->numConst = nextQuadLabel() + 2;
                    emit(if_eq, trueExpr, $3, numExpr, nextQuadLabel(), alpha_yylineno);
                    $$ = nextQuadLabel();
                    emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
                    printMessage("ifstmtprefix -> if(expr)");
                }
    ;

elseprefix: ELSE {
                $$ = nextQuadLabel();
                emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
                printMessage("elsestmtprefix -> else");
            }
    ;

ifstmt :    ifstmtprefix stmt {
                patchLabel($1, nextQuadLabel());
                $$ = $1;
                printMessage("ifstmt -> ifstmtprefix stmt"); 
        }  |
            ifstmt elseprefix stmt  {
                patchLabel($1, $2 + 1);
                patchLabel($2, nextQuadLabel());
                printMessage("ifstmt -> ifstmt elseprefix stmt"); 
        }
    ;



loopstmt:       { openloops++; push_loop(); } stmt  {
                    loopStack* tmp = pop_loop();
                    openloops--;
                    if(tmp == NULL)
                    {
                        printf("Loop stack shouldn't be empty, exiting...\n");
                        exit(-1);
                    }
                    $$ = tmp;
                }

        ;

whilestart:     WHILE   { 
                            $$ = nextQuadLabel();
                        }
            ;

whilecond:      Lparenthesis expr Rparenthesis   {
                    expr_P trueExpr = newExpr(constbool_e, NULL);
                    trueExpr->boolConst = '1';
                    expr_P numExpr2 = newExpr(constnum_e, NULL);

                    if($2->type == boolexpr_e)
                    {
                        expr_P numExpr = newExpr(constnum_e, NULL);
                        expr_P falseExpr = newExpr(constbool_e, NULL);
                        falseExpr->boolConst = '0';
                        $2->sym = newTemp(&offset, getSpace());
                        
                        backPatchList($2->truelist, nextQuadLabel());

                        emit(iop_assign, trueExpr, NULL, $2, nextQuadLabel(), alpha_yylineno);
                        numExpr->numConst = nextQuadLabel()+2;
                        emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);

                        backPatchList($2->falselist, nextQuadLabel());

                        emit(iop_assign, falseExpr, NULL, $2, nextQuadLabel(), alpha_yylineno); 
                    }

                    numExpr2->numConst = nextQuadLabel()+2;
                    emit(if_eq, $2, trueExpr, numExpr2, nextQuadLabel(), alpha_yylineno);
                    $$ = nextQuadLabel();
                    emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
                }
            ;


whilestmt:      whilestart whilecond loopstmt  {
                    expr_P numExpr = newExpr(constnum_e, NULL);
                    numExpr->numConst = $1;
                    emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);
                    patchLabel($2, nextQuadLabel());

                    logicList* breaklist = $3->breaklist;
                    logicList* contlist = $3->continuelist;
                    while(breaklist != NULL)
                    {
                        patchLabel(breaklist->quadNum, nextQuadLabel());
                        breaklist = breaklist->next;
                    }

                    while(contlist != NULL)
                    {
                        patchLabel(contlist->quadNum, $1);
                        contlist = contlist->next;
                    }                                                    
                    printMessage("whilestmt -> while (expr) stmt"); 
                }
            ;

N: { $$ = nextQuadLabel(); emit(jump, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno); }

forprefix:  FOR Lparenthesis elist M Semicolon expr Semicolon { 
                expr_P trueExpr = newExpr(constbool_e, NULL);
                trueExpr->boolConst = '1';
                if($6->type == boolexpr_e)
                {
                    expr_P numExpr = newExpr(constnum_e, NULL);
                    expr_P falseExpr = newExpr(constbool_e, NULL);
                    falseExpr->boolConst = '0';
                    $6->sym = newTemp(&offset, getSpace());
                    
                    backPatchList($6->truelist, nextQuadLabel());
                    emit(iop_assign, trueExpr, NULL, $6, nextQuadLabel(), alpha_yylineno);
                    numExpr->numConst = nextQuadLabel()+2;
                    emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);
                    backPatchList($6->falselist, nextQuadLabel());
                    emit(iop_assign, falseExpr, NULL, $6, nextQuadLabel(), alpha_yylineno);
                }

                struct forLoopStruct* loopStruct = (struct forLoopStruct*) malloc(sizeof(struct forLoopStruct));
                if(loopStruct == NULL)
                {
                    printf(ANSI_COLOR_RED"Error with malloc in forprefix rule, in Syntax.y file. Exiting..."ANSI_COLOR_RESET"\n");
                    exit(-1);
                }

                loopStruct->condition = $4;
                loopStruct->enter = nextQuadLabel();
                $$ = loopStruct;
                emit(if_eq, $6, trueExpr, NULL, nextQuadLabel(), alpha_yylineno);
            }
        ;

forstmt:    forprefix N elist Rparenthesis N loopstmt N    {    

                patchLabel($1->enter, $5+1);
                patchLabel($2, nextQuadLabel());
                patchLabel($5, $1->condition);
                patchLabel($7, $2+1);
                logicList* breaklist = $6->breaklist;
                logicList* contlist = $6->continuelist;
                while(breaklist != NULL)
                {
                    patchLabel(breaklist->quadNum, nextQuadLabel());
                    breaklist = breaklist->next;
                }
                while(contlist != NULL)
                {
                    patchLabel(contlist->quadNum, $2+1);
                    contlist = contlist->next;
                }
                printMessage("forstmt -> for(elist;expr;elist) stmt");
            }
        ;


returnstmt: RETURN Semicolon { 
                if(allowReturn == 0)
                {
                    printf(ANSI_COLOR_RED"Syntax error in line <%d>: return is not allowed outside of a function"ANSI_COLOR_RESET"\n", alpha_yylineno);
                    exit(-1);
                }
                emit(ret, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
                printMessage("returnstmt -> return;"); 
            }    |
            RETURN expr Semicolon   { 
                expr_P trueExpr = newExpr(constbool_e, NULL);
                trueExpr->boolConst = '1';
                expr_P falseExpr = newExpr(constbool_e, NULL);
                falseExpr->boolConst = '0';
                expr_P numExpr = newExpr(constnum_e, NULL);
                
                if($2->type == boolexpr_e)
                {
                    $2->sym = newTemp(&offset, getSpace());
                    
                    backPatchList($2->truelist, nextQuadLabel());
                    emit(iop_assign, trueExpr, NULL, $2, nextQuadLabel(), alpha_yylineno);

                    numExpr->numConst = nextQuadLabel() + 2;
                    emit(jump, NULL, NULL, numExpr, nextQuadLabel(), alpha_yylineno);
                    backPatchList($2->falselist, nextQuadLabel());
                    emit(iop_assign, falseExpr, NULL, $2, nextQuadLabel(), alpha_yylineno);
                }

                expr_P expr = $2;
                if(allowReturn == 0)
                {
                    printf(ANSI_COLOR_RED"Syntax error in line <%d>: return is not allowed outside of a function"ANSI_COLOR_RESET"\n", alpha_yylineno);
                    exit(-1);
                }
                emit(ret, NULL, NULL, expr, nextQuadLabel(), alpha_yylineno);    /*return the expr*/
                printMessage("returnstmt -> return expr;"); }
    ;

%%

void createBinaryFile(char* customName)
{
    FILE *fp;

    if(customName)
    {
        fp = fopen(strcat(customName, ".bin"), "wb");
        if(fp == NULL)
        {
            printf("Cannot open file\n");
            exit(0); 
        }
    }
    else
    {
        fp = fopen("AlphaCode.bin","wb");
        if(fp == NULL)
        {
            printf("Cannot open file\n");
            exit(0); 
        }
    }

    int totalGlobalsNo = getTotalGlobals();
    instructionToBinary instr;

    char* value = NULL;
    int currStringSize = 0, i = 0;

    unsigned int CorrectNumber    = 42069360;
    fwrite(&CorrectNumber,        sizeof(CorrectNumber),    1,fp);  // CorrectNumber
    fwrite(&totalNumConsts,     sizeof(totalNumConsts),     1,fp);  // totalNumConsts
    fwrite(&totalStringConsts,  sizeof(totalStringConsts),  1,fp);  // totalStringConsts
    fwrite(&totalNamedLibFuncs, sizeof(totalNamedLibFuncs), 1,fp);  // totalNamedLibFuncs 
    fwrite(&totalUserFuncs,     sizeof(totalUserFuncs),     1,fp);  // totalUserFuncs
    fwrite(&totalInstructions,  sizeof(totalInstructions),  1,fp);  // totalInstructions
    fwrite(&totalGlobalsNo,     sizeof(totalGlobalsNo),     1,fp);  // totalGlobals

    // numConsts
    for(i = 0; i < totalNumConsts; i++)
    {   
        fwrite(&i, sizeof(int), 1, fp);                  
        fwrite(&numConsts[i], sizeof(double), 1, fp);
    }

    // stringConsts
    for(i = 0; i < totalStringConsts; i++)
    {                           
        currStringSize = strlen(stringConsts[i]) + 1;

        fwrite(&currStringSize, sizeof(int), 1,fp);  

        value = calloc (currStringSize, sizeof(char));
        strcpy(value, stringConsts[i]); 

        fwrite(&i, sizeof(int), 1,fp);                 
        fwrite(value, sizeof(char)*currStringSize, 1, fp);                 

        value = NULL;
    }

    // userFuncs
    for(i = 0; i < totalUserFuncs; i++)
    {
        currStringSize = strlen(userFuncs[i].id)+1; 
        fwrite(&currStringSize, sizeof(int), 1,fp);            

        value = calloc (currStringSize, sizeof(char)) ;           
        strcpy(value, userFuncs[i].id);
        
        fwrite(&i, sizeof(int), 1,fp);            
        fwrite(&userFuncs[i].address, sizeof(int), 1,fp);            
        fwrite(&userFuncs[i].localSize, sizeof(int), 1,fp); 
        fwrite(&userFuncs[i].totalargs, sizeof(int), 1,fp);
        fwrite(value, sizeof(char)*currStringSize , 1,fp);            

        value = NULL;
    }

    // namedLibFuncs
    for(i = 0; i < totalNamedLibFuncs; i++)
    {
        currStringSize = strlen(namedLibFuncs[i])+1;
        fwrite(&currStringSize,sizeof(int), 1,fp);  

        value = calloc (currStringSize, sizeof(char)) ;           
        strcpy(value, namedLibFuncs[i]);

        fwrite(&i, sizeof(int), 1,fp);              
        fwrite(value, sizeof(char)*currStringSize , 1,fp);              

        value  = NULL;
    }   

    for (i = 0; i < nextinstructionlabel(); i++)
    {
        instr.instrOpcode   = instructions[i].opcode;
        
        instr.resultType    = instructions[i].result.type;
        instr.resultOffset  = instructions[i].result.val;
        
        instr.arg1Type      = instructions[i].arg1.type;
        instr.arg1Offset    = instructions[i].arg1.val;

        instr.arg2Type      = instructions[i].arg2.type;
        instr.arg2Offset    = instructions[i].arg2.val;

        instr.instrLine     = instructions[i].srcLine;

        fwrite(&instr,sizeof(instr),1,fp);
    }
    
    fclose(fp);
}

void createTextFile(char* customName)
{
    FILE *fp;

    if (customName)
    {
        char filename[100];
        sprintf(filename, "%s.txt", customName);
        fp = fopen(filename, "w");
        if (fp == NULL)
        {
            printf("Cannot open file\n");
            exit(0);
        }
    }
    else
    {
        fp = fopen("AlphaCode.txt", "w");
        if (fp == NULL)
        {
            printf("Cannot open file\n");
            exit(0);
        }
    }

    int totalGlobalsNo = getTotalGlobals();
    instructionToBinary instr;

    int i = 0;

    unsigned int CorrectNumber    = 42069360;
    fprintf(fp, "CorrectNumber = %d\n",      CorrectNumber);
    fprintf(fp, "totalNumConsts = %d\n",     totalNumConsts);
    fprintf(fp, "totalStringConsts = %d\n",  totalStringConsts);
    fprintf(fp, "totalNamedLibFuncs = %d\n", totalNamedLibFuncs);
    fprintf(fp, "totalUserFuncs = %d\n",     totalUserFuncs);
    fprintf(fp, "totalInstructions = %d\n",  totalInstructions);
    fprintf(fp, "totalGlobalsNo = %d\n",     totalGlobalsNo);
    fprintf(fp, "\n");

    // numConsts
    fprintf(fp, "numConsts\n");
    for(i = 0; i < totalNumConsts; i++)
    {   
        fprintf(fp, "numConsts[%d] = %f\n", i, numConsts[i]);
    }
    fprintf(fp, "\n");


    // stringConsts
    fprintf(fp, "stringConsts\n");
    for(i = 0; i < totalStringConsts; i++)
    {               
        fprintf(fp, "stringConsts[%d] = %s\n", i, stringConsts[i]);
    }
    fprintf(fp, "\n");


    // userFuncs
    fprintf(fp, "userFuncs\n");
    for(i = 0; i < totalUserFuncs; i++)
    {
        fprintf(fp, "userFuncs[%d] :\n", i);
        fprintf(fp, "id = %s\n",        userFuncs[i].id);
        fprintf(fp, "address = %d\n",   userFuncs[i].address);
        fprintf(fp, "localSize = %d\n", userFuncs[i].localSize);
        fprintf(fp, "totalargs = %d\n", userFuncs[i].totalargs);
        fprintf(fp, "\n");
    }
    fprintf(fp, "\n");


    // namedLibFuncs
    fprintf(fp, "namedLibFuncs\n");
    for(i = 0; i < totalNamedLibFuncs; i++)
    {
        fprintf(fp, "namedLibFuncs[%d] = %s\n", i, namedLibFuncs[i]);
    }
    fprintf(fp, "\n");


    fprintf(fp, "Instructions : \n");
    fprintf(fp, "instr#     opcode              result         offset         arg1          offset         arg2          offset    srcL\n");
    fprintf(fp, "-----------------------------------------------------------------------------------------------------------------------\n");
    for (i = 0; i < nextinstructionlabel(); i++)
    {
        fprintf(fp, "<%03d>:  op: %13s,    ", i, opcodeToString[instructions[i].opcode]);
        
        fprintf(fp, "type: %14s  ", typeToString(instructions[i].result.type));
        fprintf(fp, "%3d,   ", instructions[i].result.val);
        
        fprintf(fp, "type:%14s  ", typeToString(instructions[i].arg1.type));
        fprintf(fp, "%3d,   ", instructions[i].arg1.val);

        fprintf(fp, ":type:%14s  ", typeToString(instructions[i].arg2.type));
        fprintf(fp, "%3d,   ", instructions[i].arg2.val);

        fprintf(fp, "%4d\n", instructions[i].srcLine);
    }

    fclose(fp);
}

int alpha_yyerror(char *yaccProvidedMessage)
{
    fprintf(stderr, "%s: at line %d, before token: %s\n", yaccProvidedMessage, alpha_yylineno, alpha_yytext);
    fprintf(stderr, "Input not valid\n");
}

int main(int argc, char **argv) 
{
    char *binFileName = NULL;

    if(argc > 2)
    {
        if(!(alpha_yyin = fopen(argv[1], "r")))
        {
            fprintf(stderr, "Couldn't read from file %s\n", argv[1]);
            return 1;
        }
        
        binFileName = (char *) malloc(strlen(argv[2]));
        if(binFileName == NULL)
        {
            fprintf(stderr, "Malloc for binary file name failed.\n");
            exit(-1);
        }
        strcpy(binFileName, argv[2]);
    }
    else if(argc > 1)
    {
        if(!(alpha_yyin = fopen(argv[1], "r")))
        {
            fprintf(stderr, "Couldn't read from file %s\n", argv[1]);
            return 1;
        }
    }
    else
        alpha_yyin = stdin;

    init_symbol_table();

    yyparse();

    
    emit(iop_noop, NULL, NULL, NULL, nextQuadLabel(), alpha_yylineno);
    
    printf("Generating target code...\n");
    generateTcode(nextQuadLabel());

    printf("Creating text file...\n");
    createTextFile(NULL);

    printf("Creating binary file...\n");
    createBinaryFile(NULL); //i like the default name i have

    return 0;
}