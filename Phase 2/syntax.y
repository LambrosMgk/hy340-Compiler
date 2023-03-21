%{
    #include "symbol_table.h"

    #define ANSI_COLOR_RED     "\x1b[41m"
    #define ANSI_COLOR_GREEN   "\x1b[32m"
    #define ANSI_COLOR_RESET   "\x1b[0m"

    int alpha_yylex(void);
    int alpha_yyerror(char *yaccProvidedMessage);

    extern int alpha_yylineno;
    extern char* alpha_yytext;
    extern FILE* alpha_yyin;

    int scope = 0;

    void  printMessage(char *msg)
    {
        printf("%s\n", msg);
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

%type<symPtr> lvalue primary term expr
%type<strVal> assignexpr member call callsuffix normcall methodcall elist objectdef
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



program:    stmts{ printMessage("program -> stmts\nAccepted!"); print_symbol_table();}
    ;

stmts:  stmts stmt { printMessage("stmts -> statement kleene star");}
        | 
    ;

stmt:   expr Semicolon { printMessage("stmt -> exp;");} |
        ifstmt { printMessage("stmt -> if statement");} |
        whilestmt { printMessage("stmt -> while statement");} |
        forstmt { printMessage("stmt -> for statement");}  |
        returnstmt { printMessage("stmt -> return statement");} |
        BREAK Semicolon { printMessage("stmt -> break; statement");} |
        CONTINUE Semicolon { printMessage("stmt -> continue; statement");} |
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


term:   Lparenthesis expr Rparenthesis {  printMessage("term -> (expr)"); } |
        uminus expr { printMessage("term -> uminus expr");} |
        NOT expr    { printMessage("ter, -> not expr");} |
        plusplus lvalue { printMessage("term -> ++lvalue");} |
        lvalue plusplus { printMessage("term -> lvalue++");} |
        minusminus lvalue   { printMessage("term -> --lvalue");} |
        lvalue minusminus   { printMessage("term -> lvalue--");} |
        primary { printMessage("term -> primary");}
    ;

assignexpr:     lvalue assign expr  { printMessage("assignexpr -> lvalue = expr");}
    ;

primary:    lvalue  { printMessage("primary -> lvalue"); }    |
            call    { printMessage("primary -> call"); }    |
            objectdef   { printMessage("primary -> objectdef"); }   |
            Lparenthesis funcdef Rparenthesis { printMessage("primary -> (funcdef)"); } |
            const   { printMessage("primary -> const"); }
    ;

lvalue:     ID  { 
                    symbol_T sym = getElement($1, scope);
                    if(sym == NULL && scope != 0 && is_lib_func($1) == 0)
                    {
                        printf("Syntax error: no variable %s in scope\n", $1);
                        exit(-1);
                    }
                    else if(sym != NULL && sym->scope == scope)
                    {
                        if(sym->category == 2)
                            printf("this reference will use the function argument variable\n");
                    }
                    else if(sym != NULL && sym->scope == 0)
                        printf("this refers to global %s\n", $1);
                    else if(addElement($1, 1, scope, alpha_yylineno) != NULL) 
                        printf("Added symbol\n");
                    printf("lvalue -> ID with scope %d ", scope); 
                    $$ = sym; 
                }   |
            local ID    { 
                    symbol_T sym = getElement($2, scope);
                    if(is_lib_func($2) == 1)
                    {
                        printf("Syntax error: can't use library function name %s as local var.\n", $2);
                        exit(-1);
                    } else if(sym!= NULL && sym->category == 2)
                    {
                        /*printf("local x == arg x\n");*/
                    } 
                    else if (scope == 0) /*if global ignore local*/
                        addElement($2, 1, scope, alpha_yylineno); 
                    else
                        addElement($2, 3, scope, alpha_yylineno); 
                    printMessage("lvalue -> local ID"); 
                } |
            coloncolon ID   {
                symbol_T sym = getElement($2, 0);
                if(sym == NULL)
                {
                    printf("Syntax error: no global %s variable or function\n", $2);
                    exit(-1);
                }
                $$ = sym;
                printMessage("lvalue -> :: ID"); } |
            member  { printMessage("lvalue -> member"); }
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
                printf("Syntax error: redeclaration of %s as function\n", $2);
                exit(-1);
            }
            addElement($2, 4, scope, alpha_yylineno); } 
            Lparenthesis idlist Rparenthesis block  { printMessage("funcdef -> function id(idlist){}"); }   |
            FUNCTION Lparenthesis idlist Rparenthesis block {
                add_anonymus_func(scope, alpha_yylineno);
                printMessage("funcdef -> function(idlist){}"); }
    ;

const:  NUMBER  { printMessage("const -> number"); }    |
        STRING  { printMessage("const -> string"); }    |
        NIL     { printMessage("const -> nil"); }       |
        TRUE    { printMessage("const -> true"); }      |
        FALSE   { printMessage("const -> false"); }     
    ;

idlist:     ID  { 
            symbol_T sym = addElement($1, 2, scope+1, alpha_yylineno);
            if(sym != NULL)
            {
                printf("Syntax error: argument %s is already declared\n", $1);
                exit(-1);
            }
            printMessage("idlist -> ID"); }   |
            idlist comma ID { addElement($3, 2, scope+1, alpha_yylineno); printMessage("idlist -> idlist,ID");} |
                { printMessage("idlist -> empty"); }
    ;

ifstmtprefix:   IF Lparenthesis expr Rparenthesis { printMessage("ifstmtprefix -> if(expr)"); }
    ;

elseprefix: ELSE { printMessage("elsestmtprefix -> else"); }
    ;

ifstmt :    ifstmtprefix stmt { printMessage("ifstmt -> ifstmtprefix stmt"); }  |
            ifstmt elseprefix stmt  { printMessage("ifstmt -> ifstmt elseprefix stmt"); }
    ;


whilestmt:   WHILE Lparenthesis expr Rparenthesis stmt { printMessage("whilestmt -> while (expr) stmt"); } 
    ;


forstmt:    FOR Lparenthesis elist Semicolon expr Semicolon elist Rparenthesis stmt { 
    printMessage("forstmt -> for(elist;expr;elist)stmt"); }  
    ;


returnstmt: RETURN Semicolon { printMessage("returnstmt -> return;"); }    |
            RETURN expr Semicolon   { printMessage("returnstmt -> return expr;"); }
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