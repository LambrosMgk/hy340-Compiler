%{
    #include "symbol_table.h"
    #include "stack.h"
    #include "quads.h"
    #include "offset_stack.h"

    int alpha_yylex(void);
    int alpha_yyerror(char *yaccProvidedMessage);

    extern int alpha_yylineno;
    extern char* alpha_yytext;
    extern FILE* alpha_yyin;

    int scope = 0, offset = 0;
    int allowReturn = 0;
    enum scopespace_t curr_space = programmVar;

    void  printMessage(char *msg)
    {
        printf("%s\n", msg);
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
}


%token<doubleval> NUMBER
%token<strVal> ID STRING
%token<strVal> IF ELSE WHILE FOR FUNCTION RETURN BREAK CONTINUE AND NOT OR local TRUE FALSE NIL
%token<strVal> plus minus mul divide mod greater ge less le equal neq plusplus minusminus assign
%token<strVal> Lparenthesis Rparenthesis LCurlyBracket RCurlyBracket LSquareBracket RSquareBracket Semicolon comma colon coloncolon dot dotdot

%type<exprPtr> lvalue primary term expr const elist objectdef assignexpr member funcdef
%type<exprPtr> call callsuffix normcall methodcall
%type<strVal> indexed indexedelem block idlist whilestmt forstmt returnstmt
%type<intVal> stmt ifstmt


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



program:    stmts{ printMessage("program -> stmts\n"ANSI_COLOR_GREEN"Accepted!"ANSI_COLOR_RESET); print_symbol_table();}
    ;

stmts:  stmts stmt { printMessage("stmts -> statement kleene star");}
        | 
    ;

stmt:   expr Semicolon { printMessage("stmt -> exp;");} |
        ifstmt { printMessage("stmt -> if statement");} |
        whilestmt { printMessage("stmt -> while statement");} |
        forstmt { printMessage("stmt -> for statement");}  |
        returnstmt { printMessage("stmt -> return statement");} |
        BREAK Semicolon { 
            stack_T elem = pop_loop();
            if(elem == NULL)
            {
                printf(ANSI_COLOR_RED"Syntax error in line <%d>: break usage is not allowed outside of a loop"ANSI_COLOR_RESET"\n", alpha_yylineno);
                exit(-1);
            }
            push_loop(elem->name, elem->scope);
            mark_break_quad();
            emit(jump, NULL, NULL, NULL, alpha_yylineno);
            printMessage("stmt -> break; statement");
        } |
        CONTINUE Semicolon { 
            stack_T elem = pop_loop();
            if(elem == NULL)
            {
                printf(ANSI_COLOR_RED"Syntax error in line <%d>: continue usage is not allowed outside of a loop"ANSI_COLOR_RESET"\n", alpha_yylineno);
                exit(-1);
            }
            push_loop(elem->name, elem->scope);
            mark_continue_quad();
            emit(jump, NULL, NULL, NULL, alpha_yylineno);
            printMessage("stmt -> continue; statement");
        } |
        block { printMessage("stmt -> block statement");} |
        funcdef { printMessage("stmt -> funcdef statement");} |
        Semicolon { printMessage("stmt -> Semicolon statement");}
    ;

expr:   assignexpr { printMessage("expr -> assignexpr"); } |
        expr plus expr {
            expr_P result = $1; 
            if(result->type == arithexpr_e && result->sym->varName[0] == '_')   /*optimized code, use the same temp var to store the result*/
            {
                emit(iop_add, result, $1, $3, alpha_yylineno);
            }
            else
            {
                symbol_T temp = newTemp(&offset, getSpace());   /*gave pointer to offset because i don't know if i'll get a new var or not*/
                result = newExpr(arithexpr_e, temp);
                emit(iop_add, result, $1, $3, alpha_yylineno);
            }
            
            $$ = result;
            printMessage("expr -> expr + expr");
        } |
        expr minus expr {           
            expr_P result = $1; 
            if(result->type == arithexpr_e && result->sym->varName[0] == '_')   /*optimized code*/
            {
                emit(iop_sub, result, $1, $3, alpha_yylineno);
            }
            else
            {
                symbol_T temp = newTemp(&offset, getSpace());
                result = newExpr(arithexpr_e, temp);
                emit(iop_sub, result, $1, $3, alpha_yylineno);
            }
            
            $$ = result;
            printMessage("expr -> expr - expr");
        } |
        expr mul expr {
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(arithexpr_e, temp);
            $$ = result;
            emit(iop_mul, result, $1, $3, alpha_yylineno); printMessage("expr -> expr * expr");
        } |
        expr divide expr {
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(arithexpr_e, temp);
            $$ = result;
            emit(iop_div, result, $1, $3, alpha_yylineno); printMessage("expr -> expr / expr");
        } |
        expr mod expr {
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(arithexpr_e, temp);
            $$ = result;
            emit(iop_mod, result, $1, $3, alpha_yylineno); printMessage("expr -> expr % expr");
        } |
        expr greater expr {
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(var_e, temp);
            
            emit_rel_op(if_greater, result, $1, $3, alpha_yylineno); printMessage("expr -> expr > expr");
            $$ = result;
        } |
        expr ge expr {
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(var_e, temp);

            emit_rel_op(if_geatereq, result, $1, $3, alpha_yylineno); printMessage("expr -> expr >= expr");
            $$ = result;
        } |
        expr less expr {
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(var_e, temp);
            $$ = result;
            emit_rel_op(if_less, result, $1, $3, alpha_yylineno); printMessage("expr -> expr < expr");
        } |
        expr le expr {
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(var_e, temp);
            $$ = result;
            emit_rel_op(if_lesseq, result, $1, $3, alpha_yylineno); printMessage("expr -> expr <= expr");
        } |
        expr equal expr {
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(var_e, temp);
            $$ = result;
            emit_rel_op(if_eq, result, $1, $3, alpha_yylineno); printMessage("expr -> expr == expr");
        } |
        expr neq expr {
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(var_e, temp);
            $$ = result;
            emit_rel_op(if_noteq, result, $1, $3, alpha_yylineno); printMessage("expr -> expr != expr");
        } |
        expr AND {
                expr_P expr = newExpr(constbool_e, NULL);
                expr->boolConst = 0;
                mark_quad();
                emit(if_eq, $1, expr, NULL, alpha_yylineno); 
        } expr {
                expr_P result = $4;
                expr_P expr = newExpr(constbool_e, NULL);
                expr->boolConst = 0;

                emit(jump, NULL, NULL, NULL, alpha_yylineno);
                patchEmittedResult();
                patchArg2Label();
                emit(iop_assign, result, expr, NULL, alpha_yylineno);

                $$ = result;
                printMessage("expr -> expr AND expr");
        } |
        expr OR {
                expr_P expr = newExpr(constbool_e, NULL);
                expr->boolConst = 0;
                mark_quad();
                emit(if_noteq, $1, expr, NULL, alpha_yylineno);
        } expr {
                expr_P result = $4;
                expr_P expr = newExpr(constbool_e, NULL);
                expr->boolConst = 1;

                emit(jump, NULL, NULL, NULL, alpha_yylineno);
                patchEmittedResult();
                patchArg2Label();
                emit(iop_assign, result, expr, NULL, alpha_yylineno);
                
                $$ = result;
                printMessage("expr -> expr OR expr");
        } |
        term { $$ = $1; printMessage("expr -> term"); }
    ;


term:   Lparenthesis expr Rparenthesis {  
            $$ = $2;
            printMessage("term -> (expr)"); 
        } |
        uminus expr { 
            expr_P exprPtr = $2;
            
            check_for_func_error(exprPtr->sym);
            emit(iop_uminus, exprPtr, NULL, NULL, alpha_yylineno);
            $$ = exprPtr;
            printMessage("term -> uminus expr");
        } |
        NOT expr    {
            expr_P exprPtr = $2;
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(var_e, temp);
            $$ = result;

            check_for_func_error(exprPtr->sym);
            emit(iop_NOT, result, $2, NULL, alpha_yylineno);    /*or i could use a function like emit_rel_op() and use if_eq and jumps*/
            printMessage("term -> not expr");
        } |
        plusplus lvalue { 
            $$ = $2;
            expr_P exprPtr = $2, numExpr = newExpr(constnum_e, NULL);
            numExpr->numConst = 1;

            check_for_func_error(exprPtr->sym);
            emit(iop_add, exprPtr, exprPtr, numExpr, alpha_yylineno);   /*pre increment*/
            printMessage("term -> ++lvalue");
        } |
        lvalue plusplus { 
            expr_P exprPtr = $1, numExpr = newExpr(constnum_e, NULL);
            numExpr->numConst = 1;
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(var_e, temp);
            $$ = result;

            check_for_func_error(exprPtr->sym); 
            emit(iop_assign, result, exprPtr, NULL, alpha_yylineno);    /*assign old value to a temp, post increment*/
            emit(iop_add, exprPtr, exprPtr, numExpr, alpha_yylineno);
            printMessage("term -> lvalue++");
        } |
        minusminus lvalue   { 
            $$ = $2;
            expr_P exprPtr = $2, numExpr = newExpr(constnum_e, NULL);
            numExpr->numConst = 1;

            check_for_func_error(exprPtr->sym);
            emit(iop_sub, exprPtr, exprPtr, numExpr, alpha_yylineno);   /*pre decrement*/
            printMessage("term -> --lvalue");
        } |
        lvalue minusminus   { 
            expr_P exprPtr = $1, numExpr = newExpr(constnum_e, NULL);
            numExpr->numConst = 1;
            symbol_T temp = newTemp(&offset, getSpace());
            expr_P result = newExpr(var_e, temp);
            $$ = result;

            check_for_func_error(exprPtr->sym);
            emit(iop_assign, result, exprPtr, NULL, alpha_yylineno);    /*assign old value to a temp, post decrement*/
            emit(iop_sub, exprPtr, exprPtr, numExpr, alpha_yylineno);
            printMessage("term -> lvalue--");
        } |
        primary { printMessage("term -> primary");}
    ;

assignexpr:     lvalue assign expr  {
            symbol_T lval = $1;
            
            check_for_func_error(lval);

            
            printMessage("assignexpr -> lvalue = expr");
        }
    ;
assignexpr:     lvalue assign expr  {
            expr_P exprPtr = $1, tmp = NULL, result = NULL, prev_result = NULL, final_result = NULL;
            symbol_T temp = NULL;
            
            check_for_func_error(exprPtr->sym);
            $$ = $3;
            if($3->index != NULL) /*only table items have index != null (another way to know when expr is a tableitem while also being constbool_e or something)*/
            {
                tmp = $3->index;
                temp = newTemp(&offset, getSpace());
                result = newExpr(tableitem_e, temp);
                emit(tablegetelem, tmp, tmp->next, result, alpha_yylineno); /* TABLEGETELEM t "a" _t1*/

                tmp = tmp->next->next;
                prev_result = result;
                while(tmp != NULL)
                {
                    temp = newTemp(&offset, getSpace());
                    result = newExpr(tableitem_e, temp);
                    emit(tablegetelem, prev_result, tmp, result, alpha_yylineno);
                    prev_result = result;
                    tmp = tmp->next;
                }
                final_result = prev_result;
            }
            if($1->type == tableitem_e) /*if lvalue is table item then get the first item and at the end to tablesetelem*/
            {
                tmp = $1->index;    /*all index pointers point to the first item*/
                if(tmp != NULL)     /*just to be sure*/
                {
                    temp = newTemp(&offset, getSpace());
                    result = newExpr(tableitem_e, temp);
                    if(tmp->next->next != NULL)
                    {
                        emit(tablegetelem, tmp, tmp->next, result, alpha_yylineno); /* TABLEGETELEM t "a" _t1*/
                        tmp = tmp->next->next;  /*if t.a.b we go to 'b'*/
                        prev_result = result;
                    }   
                    else
                    {
                        prev_result = tmp;
                        tmp = tmp->next;
                    }

                    
                    while(tmp->next != NULL)
                    {
                        temp = newTemp(&offset, getSpace());
                        result = newExpr(tableitem_e, temp);
                        emit(tablegetelem, prev_result, tmp, result, alpha_yylineno);
                        prev_result = result;
                        tmp = tmp->next;
                    }
                    if(final_result != NULL)    /*then expr is a table item*/
                        emit(tablesetelem, prev_result, tmp, final_result, alpha_yylineno);   /*TABLESETELEM _t1 "b" x*/
                    else    /*its was something else*/
                        emit(tablesetelem, prev_result, tmp, $3, alpha_yylineno);
                }
                else
                {
                    printf("Error: tmp shouldn't be null, that means we have lvalue = table.nothing\n");
                }
            }
            else
            {
                if(final_result != NULL)    /*if R-value was tableitem then we need to assign the value from the temporary var inside final_result*/
                    emit(iop_assign, $1, final_result, NULL, alpha_yylineno);
                else    /*classic emit*/
                    emit(iop_assign, $1, $3, NULL, alpha_yylineno);
            }

            /*type checking??*/
            if($3->type == newtable_e || $3->type == tableitem_e)/*maybe check the type of R-value to determine the type of L-value*/
            {
                /*$1->type = newtable_e;?????????*/ /*no because that's how i check objectdef and elsewhere*/ /*athlough that may not matter cuz lvalue -> id assigns the type var_e*/
                printf("lvalue is now table??\n");
            }
            /*type checking??*/
            /*if($3->type == constnum_e)
                printf("%s is type of constnum_e\n", $1->sym->varName);
            else if($3->type == constbool_e)
                printf("%s is type of constbool_e\n", $1->sym->varName);
            else if($3->type == conststring_e)
                printf("%s is type of conststring_e\n", $1->sym->varName);
            else
                printf("is some other type\n");*/
            
                
            printMessage("assignexpr -> lvalue = expr");}
    ;

primary:    lvalue  {
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

                        sym = addSymbol($1, category, scope, alpha_yylineno, offset, curr_space);
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
                        sym = addSymbol($2, global_var, scope, alpha_yylineno, offset, curr_space);
                        offset++;
                        printf("Added global %s (ignored local)\n", $2);
                    }
                    else
                    {
                        sym = addSymbol($2, local_var, scope, alpha_yylineno, offset, curr_space);
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
                $$ = member_lvalue_dot_ID($1, $3);
                printMessage("member -> lvalue.ID"); 
    }    |
            lvalue LSquareBracket expr RSquareBracket   {
                $$ = member_lvalue_LSqBr_expr_RSqBr($1, $3, scope);
                printMessage("member -> lvalue[expr]"); 
    }    |
            call dot ID { printMessage("member -> call.ID"); }  |
            call LSquareBracket expr RSquareBracket { printMessage("member -> call[expr]"); }
    ;

call:       call Lparenthesis elist Rparenthesis    { printMessage("call -> call(elist)"); }   |
            lvalue callsuffix   {
                expr_P tmp = $2;    /*get callsuffix (only done normcall tho)*/
                while(tmp != NULL)    /*go to the end of the list*/
                {
                    emit(param, tmp, NULL, NULL, alpha_yylineno);/*emit param for every struct in the elist list*/
                    tmp = tmp->next;
                }
                emit(call, $1, NULL, NULL, alpha_yylineno);
                symbol_T temp = newTemp(&offset, getSpace());
                expr_P result = newExpr(var_e, temp);
                emit(getretval, result, NULL , NULL, alpha_yylineno);
                $$ = result;
                printMessage("call -> lvalue callsuffix");
        }  |
            Lparenthesis funcdef Rparenthesis Lparenthesis elist Rparenthesis   { printMessage("call -> (funcdef)(elist)"); }
    ;

callsuffix: normcall    { $$ = $1; printMessage("callsuffix -> normcall"); } |
            methodcall  { printMessage("callsuffix -> methodcall"); }
    ;

normcall:   Lparenthesis elist Rparenthesis {
            $$ = $2;
            printMessage("normcall -> (elist)"); }
    ;

methodcall: dotdot ID Lparenthesis elist Rparenthesis   { printMessage("..ID(elist)"); }
    ;

elist: expr { $$ = $1; printMessage("elist -> expr"); }   |
        elist comma expr    {
            expr_P tmp = $1;
            while(tmp->next != NULL)    /*go to the end of the list*/
            {
                tmp = tmp->next;
            }
                
            tmp->next = $3;
            $$ = $1;    /*return the first element of the list*/
            printMessage("elist -> elist,expr"); 
    }    |
        { $$ = NULL; printMessage("elist -> empty"); }
    ;

objectdef:  LSquareBracket elist RSquareBracket {
            expr_P exprPtr = NULL, tmp = $2, tableItemexpr = NULL;
            
            exprPtr = newExpr(newtable_e, NULL);
            exprPtr->sym = newTemp(&offset, getSpace());
            emit(tablecreate, exprPtr, NULL, NULL, alpha_yylineno);
            for (int i = 0; tmp; tmp = tmp->next)
            {
                tableItemexpr = newExpr(constnum_e, NULL);
                tableItemexpr->numConst = i++;
                emit(tablesetelem, exprPtr, tableItemexpr, tmp, alpha_yylineno);
            }
            $$ = exprPtr;
            printMessage("objectdef -> [elist]");
    }   |
            LSquareBracket indexed RSquareBracket   {
            expr_P exprPtr = newExpr(newtable_e, NULL);
            $$ = exprPtr;
            printMessage("objectdef -> [indexed]"); 
    }
    ;

indexed:    indexedelem { printMessage("indexed -> indexedelem"); } |
            indexed comma indexedelem   { printMessage("indexed -> indexed,indexedelem"); }
    ;

indexedelem:    LCurlyBracket expr colon expr RCurlyBracket { printMessage("indexedelem -> {expr:expr}"); }
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
                addSymbol($2, user_func, scope, alpha_yylineno, offset, curr_space); 

                
                offset++;   /*functions count as variables?*/
                offset_push(offset);
                expr_P expr = newExpr(programfunc_e, sym);
                mark_quad();
                emit(jump, NULL, NULL, NULL, alpha_yylineno); /*create empty jump that will later be filled with the end of this function*/
                emit(funcstart, expr, NULL, NULL, alpha_yylineno);

                printf("OFFSET BEFORE FUNC %d\n", offset);
                offset = 0;
            } 
            Lparenthesis idlist {
                curr_space = functionLocal;
                printf(ANSI_COLOR_GREEN"formal args counter : %d"ANSI_COLOR_RESET"\n", offset);
            }
            Rparenthesis {allowReturn++;} 
            block  {
                symbol_T sym = getElement($2, scope);
                expr_P expr = newExpr(programfunc_e, sym);

                emit(funcend, expr, NULL, NULL, alpha_yylineno);
                patchLabel();
                allowReturn--;
                
                offset_stack_T offsettmp = offset_pop();
                offset = offsettmp->offset; printf("OFFSET AFTER FUNC %d\n", offset);
                printMessage("funcdef -> function id(idlist){stmts}");
            }   |
            FUNCTION {add_anonymus_func(scope, alpha_yylineno);} Lparenthesis idlist Rparenthesis {allowReturn++;} block {
                allowReturn--;
                printMessage("funcdef -> function(idlist){}"); 
            }
            FUNCTION {
                symbol_T sym = add_anonymus_func(scope, alpha_yylineno, offset, curr_space);

                offset++;   /*functions count as variables?*/
                offset_push(offset);
                allowReturn++;

                expr_P expr = newExpr(programfunc_e, sym);
                mark_quad();
                emit(jump, NULL, NULL, NULL, alpha_yylineno);
                emit(funcstart, expr, NULL, NULL, alpha_yylineno);
                printf("OFFSET BEFORE FUNC %d\n", offset);
                
                anonymusFuncSym = sym;  /*this might also need a stack in case of anonymus inside of anonymus*/
                offset = 0;
            } Lparenthesis idlist { printf("formal args for anonymus func counter : %d\n", offset); } Rparenthesis block {
                expr_P expr = newExpr(programfunc_e, anonymusFuncSym);
                emit(funcend, expr, NULL, NULL, alpha_yylineno);
                patchLabel();
                allowReturn--;
                offset_stack_T offsettmp = offset_pop();
                offset = offsettmp->offset; printf("OFFSET AFTER FUNC %d\n", offset);
                func_pop();
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
            expr->boolConst = 1;
            $$ = expr;
            printMessage("const -> true");
        }    |
        FALSE   {
            expr_P expr = newExpr(constbool_e, NULL);
            expr->boolConst = 0;
            $$ = expr;
            printMessage("const -> false"); }     
    ;

idlist:     ID  { 
                curr_space = formalArg;
                symbol_T sym = addSymbol($1, func_arg, scope+1, alpha_yylineno, offset, curr_space);
                offset++;

                if(sym == NULL)
                {
                    printf(ANSI_COLOR_RED"Syntax error in line <%d>: argument %s is already declared"ANSI_COLOR_RESET"\n", alpha_yylineno, $1);
                    exit(-1);
                }
                printMessage("idlist -> ID"); 
            }   |
            idlist comma ID { 
                curr_space = formalArg;
                symbol_T sym = addSymbol($3, func_arg, scope+1, alpha_yylineno, offset, curr_space);
                offset++;

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
                    expr_P result = $3;
                    expr_P numExpr = newExpr(constnum_e, NULL);
                    numExpr->numConst = 1;
                    if(result == NULL)
                    {
                        printf("Syntax error : empty if statement in line %d\n", alpha_yylineno);
                        exit(-1);
                    }

                    mark_quad();
                    emit(if_noteq, result, numExpr, NULL, alpha_yylineno);    /*if expr != TRUE then jump away*/
                    printMessage("ifstmtprefix -> if(expr)");
                }
    ;

elseprefix: ELSE {
                mark_quad();
                emit(jump, NULL, NULL, NULL, alpha_yylineno);
                printMessage("elsestmtprefix -> else");
            }
    ;

ifstmt :    ifstmtprefix stmt {
                $$ = patchArg2Label();
                printMessage("ifstmt -> ifstmtprefix stmt"); 
        }  |
            ifstmt elseprefix stmt  {
                patchLabel();
                patchELSEjump($1);
                printMessage("ifstmt -> ifstmt elseprefix stmt"); 
        }
    ;

whilestmt:   WHILE { push_loop(NULL, scope); }  Lparenthesis { mark_quad(); } expr Rparenthesis {
                expr_P result = $4;
                expr_P numExpr = newExpr(constnum_e, NULL);
                numExpr->numConst = 1;
                if(result == NULL)
                {
                    printf("Syntax error : empty while statement in line %d\n", alpha_yylineno);
                    exit(-1);
                }

                mark_quad();
                emit(if_noteq, result, numExpr, NULL, alpha_yylineno);    /*if expr != TRUE then jump away*/
                push_break_count(breakExists);  /*store the prev counter for break before stmts begin*/
                push_continue_count(ContinueExists);
                breakExists = 0;
                ContinueExists = 0;
            } stmt {
                int exprQuadStart = 0;
                emit(jump, NULL, NULL, NULL, alpha_yylineno);
                patchArg2Label();       /*patch from stack*/
                exprQuadStart = patch_thisResult_FromStack();     /*patch the jump i just emitted with a queue*/
                while(breakExists != 0)
                {
                    patchBreakLabel();
                    breakExists--;
                }
                while(ContinueExists != 0)
                {
                    patchContinueLabel(exprQuadStart);
                    ContinueExists--;
                }
                breakExists = pop_break_count();
                ContinueExists = pop_continue_count();

                pop_loop();
                printMessage("whilestmt -> while (expr) stmt"); 
            } 
    ;

forstmt:    FOR { push_loop(NULL, scope); } Lparenthesis elist Semicolon { mark_queue_quad(); /*(1)mark the start of expr*/} expr {
                expr_P result = $6;
                expr_P numExpr = newExpr(constnum_e, NULL);
                numExpr->numConst = 1;

                if(result == NULL)
                {
                    printf("Syntax error : empty for statement in line %d\n", alpha_yylineno);
                    exit(-1);
                }
                
                mark_next_quad();   /*because of the stack i have to first mark the false jump and then the true jump*/
                mark_quad();
                emit(if_eq, result, numExpr, NULL, alpha_yylineno);    /*(2)if expr == TRUE then jump to stmts*/
                emit(jump, NULL, NULL, NULL, alpha_yylineno);          /*false jump*/

            } Semicolon { mark_queue_quad(); /*(3)mark step (elist2)*/} elist{

                emit(jump, NULL, NULL, NULL, alpha_yylineno);   /*loop jump to expr*/
                patch_loop_label();                              /*(1)patch for expr*/

            } Rparenthesis {
                patchArg2Label();   /*(2)patch jump to the start of stmts*/
                push_break_count(breakExists);  /*store the prev counter for break before stmts begin*/
                push_continue_count(ContinueExists);
                breakExists = 0;
                ContinueExists = 0;
            } stmt {
                int exprQuadStart = 0;
                emit(jump, NULL, NULL, NULL, alpha_yylineno);    /*closure jump*/
                exprQuadStart = patch_loop_label();          /*(3) patch step (closure jump)*/
                patchLabel();

                while(breakExists != 0)
                {
                    patchBreakLabel();
                    breakExists--;
                }
                while(ContinueExists != 0)
                {
                    patchContinueLabel(exprQuadStart);
                    ContinueExists--;
                }
                breakExists = pop_break_count();
                ContinueExists = pop_continue_count();

                pop_loop();
                printMessage("forstmt -> for(elist;expr;elist)stmt"); 
            }  
    ;


returnstmt: RETURN Semicolon { 
                if(allowReturn == 0)
                {
                    printf(ANSI_COLOR_RED"Syntax error in line <%d>: return is not allowed outside of a function"ANSI_COLOR_RESET"\n", alpha_yylineno);
                    exit(-1);
                }
                emit(ret, NULL, NULL, NULL, alpha_yylineno);
                printMessage("returnstmt -> return;"); 
            }    |
            RETURN expr Semicolon   { 
                expr_P expr = $2;
                if(allowReturn == 0)
                {
                    printf(ANSI_COLOR_RED"Syntax error in line <%d>: return is not allowed outside of a function"ANSI_COLOR_RESET"\n", alpha_yylineno);
                    exit(-1);
                }
                emit(ret, expr, NULL, NULL, alpha_yylineno);    /*return the expr*/
                printMessage("returnstmt -> return expr;"); }
    ;

%%

int alpha_yyerror(char *yaccProvidedMessage)
{
    fprintf(stderr, "%s: at line %d, before token: %s\n", yaccProvidedMessage, alpha_yylineno, alpha_yytext);
    fprintf(stderr, "Input not valid\n");
}

int main(int argc, char **argv) 
{
    if(argc > 1)
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
    return 0;
}