%{
    #include "symbol_table.h"
    #include "stack.h"

    int alpha_yylex(void);
    int alpha_yyerror(char *yaccProvidedMessage);

    extern int alpha_yylineno;
    extern char* alpha_yytext;
    extern FILE* alpha_yyin;

    int scope = 0;
    int allowReturn = 0;

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
%}

%define api.prefix {alpha_yy}
%define parse.error verbose

%start program

%union {
    int intVal;
    char* strVal;
    double doubleval;
    struct symbol_ *symPtr;
}


%token<doubleval> NUMBER
%token<strVal> ID STRING
%token<strVal> IF ELSE WHILE FOR FUNCTION RETURN BREAK CONTINUE AND NOT OR local TRUE FALSE NIL
%token<strVal> plus minus mul divide mod greater ge less le equal neq plusplus minusminus assign uminus
%token<strVal> Lparenthesis Rparenthesis LCurlyBracket RCurlyBracket LSquareBracket RSquareBracket Semicolon comma colon coloncolon dot dotdot

%type<symPtr> lvalue primary term expr member
%type<strVal> assignexpr call callsuffix normcall methodcall elist objectdef
%type<strVal> indexed indexedelem block funcdef const idlist ifstmt whilestmt forstmt returnstmt
%type<intVal> stmt


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
            printMessage("stmt -> break; statement");} |
        CONTINUE Semicolon { 
            stack_T elem = pop_loop();
            if(elem == NULL)
            {
                printf(ANSI_COLOR_RED"Syntax error in line <%d>: continue usage is not allowed outside of a loop"ANSI_COLOR_RESET"\n", alpha_yylineno);
                exit(-1);
            }
            push_loop(elem->name, elem->scope);
            printMessage("stmt -> continue; statement");} |
        block { printMessage("stmt -> block statement");} |
        funcdef { printMessage("stmt -> funcdef statement");} |
        Semicolon { printMessage("stmt -> Semicolon statement");}
    ;

expr:   assignexpr { printMessage("expr -> assignexpr"); } |
        expr plus expr { printMessage("expr -> expr plus expr"); } |
        expr minus expr { printMessage("expr -> expr minus expr"); } |
        expr mul expr { printMessage("expr -> expr mul expr"); } |
        expr divide expr { printMessage("expr -> expr divide expr"); } |
        expr mod expr { printMessage("expr -> expr mod expr"); } |
        expr greater expr { printMessage("expr -> expr greater expr"); } |
        expr ge expr { printMessage("expr -> expr ge expr"); } |
        expr less expr { printMessage("expr -> expr less expr"); } |
        expr le expr { printMessage("expr -> expr le expr"); } |
        expr equal expr { printMessage("expr -> expr equal expr"); } |
        expr neq expr { printMessage("expr -> expr neq expr"); } |
        expr AND expr { printMessage("expr -> expr AND expr"); } |
        expr OR expr { printMessage("expr -> expr OR expr"); } |
        term { printMessage("expr -> term"); }
    ;


term:   Lparenthesis expr Rparenthesis {  
            printMessage("term -> (expr)"); 
        } |
        uminus expr { 
            symbol_T lval = $2;

            check_for_func_error(lval);
            printMessage("term -> uminus expr");
            } |

        NOT expr    { 
            symbol_T lval = $2;
            
            check_for_func_error(lval);
            printMessage("ter, -> not expr");
            } |
        plusplus lvalue { 
            symbol_T lval = $2;
            
            check_for_func_error(lval);
            printMessage("term -> ++lvalue");
            } |
        lvalue plusplus { 
            symbol_T lval = $1;
            
            check_for_func_error(lval);
            printMessage("term -> lvalue++");
            } |
        minusminus lvalue   { 
            symbol_T lval = $2;
            
            check_for_func_error(lval);
            printMessage("term -> --lvalue");
            } |
        lvalue minusminus   { 
            symbol_T lval = $1;
            
            check_for_func_error(lval);
            printMessage("term -> lvalue--");
            } |
        primary { printMessage("term -> primary");}
    ;

assignexpr:     lvalue assign expr  {
            symbol_T lval = $1;
            
            check_for_func_error(lval);
            printMessage("assignexpr -> lvalue = expr");}
    ;

primary:    lvalue  {
                $$ = $1;
                printMessage("primary -> lvalue"); 
            }    |
            call    { printMessage("primary -> call"); }    |
            objectdef   { printMessage("primary -> objectdef"); }   |
            Lparenthesis funcdef Rparenthesis { printMessage("primary -> (funcdef)"); } |
            const   { printMessage("primary -> const"); }
    ;

lvalue:     ID  {
                    symbol_T sym = search_from_scope_out($1, scope);
                    enum SymbolCategory category;

                    if(sym == NULL) /*if you can't find anything add new symbol*/
                    {
                        if(scope == 0)
                            category = global_var;
                        else
                            category = local_var;

                        sym = addSymbol($1, category, scope, alpha_yylineno);
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


                    printf("lvalue -> ID\n"); 
                    $$ = sym; 
                }   |
            local ID    {
                    symbol_T sym = getElement($2, scope);

                    if(sym!= NULL && sym->category == func_arg && sym->active == 1)
                    {
                        /*printf("local x == arg x\n");*/
                    } 
                    else if (scope == 0) /*if global ignore local*/
                    {
                        sym = addSymbol($2, global_var, scope, alpha_yylineno);
                        printf("Added global %s (ignored local)\n", $2);
                    }
                    else
                    {
                        sym = addSymbol($2, local_var, scope, alpha_yylineno);
                        printf("Added local %s\n", $2);
                    }

                    $$ = sym;
                    printMessage("lvalue -> local ID"); 
                } |
            coloncolon ID   {
                symbol_T sym = getElement($2, 0); /*:: means we search in global scope*/
                if(sym == NULL)
                {
                    printf(ANSI_COLOR_RED"Syntax error in line <%d>: no global variable or function %s"ANSI_COLOR_RESET"\n", alpha_yylineno, $2);
                    exit(-1);
                }
                $$ = sym;
                printMessage("lvalue -> :: ID"); 
                } |
            member  { $$ = NULL; printMessage("lvalue -> member"); }
    ;

member:     lvalue dot ID   { printMessage("member -> lvalue.ID"); }    |
            lvalue LSquareBracket expr RSquareBracket   { printMessage("member -> lvalue[expr]"); } |
            call dot ID { printMessage("member -> call.ID"); }  |
            call LSquareBracket expr RSquareBracket { printMessage("member -> call[expr]"); }
    ;

call:       call Lparenthesis elist Rparenthesis    { printMessage("call -> call(elist)"); }   |
            lvalue callsuffix   { printMessage("call -> lvalue callsuffix"); }  |
            Lparenthesis funcdef Rparenthesis Lparenthesis elist Rparenthesis   { printMessage("call -> (funcdef)(elist)"); }
    ;

callsuffix: normcall    { printMessage("callsuffix -> normcall"); } |
            methodcall  { printMessage("callsuffix -> methodcall"); }
    ;

normcall:   Lparenthesis elist Rparenthesis { printMessage("normcall -> (elist)"); }
    ;

methodcall: dotdot ID Lparenthesis elist Rparenthesis   { printMessage("..ID(elist)"); }
    ;

elist: expr { printMessage("elist -> expr"); }   |
        elist comma expr    { printMessage("elist -> elist,expr"); }    |
        { printMessage("elist -> empty"); }
    ;

objectdef:  LSquareBracket elist RSquareBracket { printMessage("objectdef -> [elist]"); }   |
            LSquareBracket indexed RSquareBracket   {printMessage("objectdef -> [indexed]"); }
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
            addSymbol($2, user_func, scope, alpha_yylineno); } 
            Lparenthesis idlist Rparenthesis {allowReturn++;} block  { allowReturn--; printMessage("funcdef -> function id(idlist){}"); }   |

            FUNCTION {add_anonymus_func(scope, alpha_yylineno);} Lparenthesis idlist Rparenthesis {allowReturn++;} block {
                allowReturn--;
                printMessage("funcdef -> function(idlist){}"); 
            }
    ;

const:  NUMBER  { printMessage("const -> number"); }    |
        STRING  { printMessage("const -> string"); }    |
        NIL     { printMessage("const -> nil"); }       |
        TRUE    { printMessage("const -> true"); }      |
        FALSE   { printMessage("const -> false"); }     
    ;

idlist:     ID  { 
            symbol_T sym = addSymbol($1, func_arg, scope+1, alpha_yylineno);
            
            if(sym == NULL)
            {
                printf(ANSI_COLOR_RED"Syntax error in line <%d>: argument %s is already declared"ANSI_COLOR_RESET"\n", alpha_yylineno, $1);
                exit(-1);
            }
            printMessage("idlist -> ID"); }   |
            idlist comma ID { 
            symbol_T sym = addSymbol($3, func_arg, scope+1, alpha_yylineno);
            
            if(sym == NULL)
            {
                printf(ANSI_COLOR_RED"Syntax error in line <%d>: argument %s is already declared"ANSI_COLOR_RESET"\n", alpha_yylineno, $1);
                exit(-1);
            }
            
            printMessage("idlist -> idlist,ID"); } |
                { printMessage("idlist -> empty"); }
    ;

ifstmtprefix:   IF Lparenthesis expr Rparenthesis { printMessage("ifstmtprefix -> if(expr)"); }
    ;

elseprefix: ELSE { printMessage("elsestmtprefix -> else"); }
    ;

ifstmt :    ifstmtprefix stmt { printMessage("ifstmt -> ifstmtprefix stmt"); }  |
            ifstmt elseprefix stmt  { printMessage("ifstmt -> ifstmt elseprefix stmt"); }
    ;


whilestmt:  WHILE { push_loop(NULL, scope); } 
            Lparenthesis expr Rparenthesis stmt { pop_loop(); printMessage("whilestmt -> while (expr) stmt"); } 
    ;


forstmt:    FOR { push_loop(NULL, scope); } Lparenthesis elist Semicolon expr Semicolon elist Rparenthesis stmt { 
                pop_loop();
                printMessage("forstmt -> for(elist;expr;elist)stmt"); }  
    ;


returnstmt: RETURN Semicolon { 
                if(allowReturn == 0)
                {
                    printf(ANSI_COLOR_RED"Syntax error in line <%d>: return is not allowed outside of a function"ANSI_COLOR_RESET"\n", alpha_yylineno);
                    exit(-1);
                }

                printMessage("returnstmt -> return;"); }    |
            
            RETURN expr Semicolon   { 
                if(allowReturn == 0)
                {
                    printf(ANSI_COLOR_RED"Syntax error in line <%d>: return is not allowed outside of a function"ANSI_COLOR_RESET"\n", alpha_yylineno);
                    exit(-1);
                }
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