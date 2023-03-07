%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

#define YY_DECL int alpha_yylex(void* yylval)
#define ANSI_COLOR_RED		"\x1b[41m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_RESET   "\x1b[0m"

enum Category{KEYWORD, OPERATOR, INTEGER, REAL, STRING, PUNCTUATION, ID, COMMENT};

/*enum Keywords{IF, ELSE, WHILE, FOR, FUNCTION, RETURN, BREAK, CONTINUE, AND, NOT, OR, LOCAL, TRUE, FALSE, NIL};
enum Operators{ASSIGNMENT, PLUS, MINUS, MUL, DIV, MOD, EQ, NEQ, PLUSPLUS, MINUSMINUS, GT, LT, GEQ, LEQ};
enum Punctuation{LCurlyBracket, RCurlyBracket, LSquareBracket, RSquareBracket, Lparenthesis, Rparenthesis, Semicolon};*/

typedef struct alpha_token
{
	unsigned int lineno, tokennum;
	enum Category category;
	char *value;
	struct alpha_token *next;
} alpha_token, *alpha_token_t;

typedef struct comment_struct
{
	unsigned int lineno, col;
	struct comment_struct *next, *prev;
} comment_struct, *comment_struct_t;


unsigned int total_tokens = 0, column = 0;

void addColCounter(int times)
{
	column = column + times;
}

void resetColCounter()
{
	column = 0;
}

comment_struct_t create_comment_struct(int line, int col)
{
	comment_struct_t tmp = (comment_struct_t) malloc(sizeof(comment_struct));
	if(tmp == NULL)
	{
		fprintf(alpha_yyout, "Error, not enough memory for comment struct. Exiting...\n");
		exit(-1);
	}
	tmp->lineno = line;
	tmp->col = col;
	tmp->next = NULL;
	tmp->prev = NULL;
	
	return tmp;
}

void print_token_list(alpha_token_t head)
{
	alpha_token_t tmp = head;

	while(tmp != NULL)
	{
		fprintf(alpha_yyout, "Line <%d>: #<%d> \"%s\" category %d\n", tmp->lineno, tmp->tokennum, tmp->value, tmp->category);
		tmp = tmp->next;
	}
}

%}

%option outfile="scanner.c"
%option noyywrap
%option yylineno
%option prefix="alpha_yy"


keyword "if"{1}|"else"{1}|"while"{1}|"for"{1}|"function"{1}|"return"{1}|"break"{1}|"continue"{1}|"and"{1}|"not"{1}|"or"{1}|"local"{1}|"true"{1}|"false"{1}|"nil"{1}
operator "="+|"+"+|"-"+|"*"+|"/"+|"%"+|"=="+|"!="+|"++"+|"--"+|">"{1}|"<"{1}|">="{1}|"<="{1}
integer [0-9][0-9]*
real	[0-9]*\.[0-9](e|E)?[0-9]*
string \"(\\.|[^"\\])*\"
punctuation "{"{1}|"}"{1}|"["{1}|"]"{1}|"("{1}|")"{1}|";"{1}|","{1}|":"{1}|"::"{1}|"."{1}|".."{1}
id [a-zA-Z][a-zA-Z_0-9]*
whitespace [ \t]
undefined [^keyword^operator^integer^real^string^punctuation^id^whitespace]


%%
<<EOF>> {
	fprintf(alpha_yyout, "EOF\n");
	return -1;
}

"\n" {
	resetColCounter();
	/*fprintf(alpha_yyout, "newline\n");*/
}

{whitespace} {
	/*i've defined space and tab as whitespaces*/
	addColCounter(1);
	/*fprintf(alpha_yyout, "Whitespace\n");*/
}

"/*" {
	addColCounter(2);
	fprintf(alpha_yyout, "multy-line comment in line %d col %d\n", yylineno, column);
	int opened = 1, closed = 0;
	comment_struct_t head = create_comment_struct(yylineno, column);
	comment_struct_t tmp = head;
	char c = 0; /*change it to -1*/

	while(c != EOF)
	{
		c = input();
		addColCounter(1);
		if(c == '\n')
		{
			resetColCounter();
		}

		if(c == '/')
		{
			c = input();
			
			if(c == '*')
			{
				addColCounter(1);
				opened++;
				tmp->next = create_comment_struct(yylineno, column);
				tmp->next->prev = tmp;
				tmp = tmp->next;
				/*fprintf(alpha_yyout, "multy-line comment opened in line %d col %d\n", yylineno, column);*/
			}
			else
			{
				unput(c);
			}
		}
		else if(c == '*')
		{
			c = input();
			
			if(c == '/')
			{
				addColCounter(1);
				closed++;
				if(tmp->prev == NULL)	/*only 1 comment opened so delete the struct*/
				{	
					free(tmp);
					tmp = NULL;
				}
				else
				{
					tmp = tmp->prev;	/*go 1 struct back and delete its next*/
					free(tmp->next);
					tmp->next = NULL;
				}
				/*fprintf(alpha_yyout, "multy-line comment closed in line %d col %d\n", yylineno, column);*/
			}
			else
			{
				unput(c);
			}
		}
		else
		{
			if(c == 0 && (opened != closed))	/*old implementation c == EOF when i used flex on windows, when i switched to linux it didn't work*/
			{
				if(tmp == NULL)	/*you can't get here, something went really bad if you do (tmp == NULL can't mean opened != closed)*/
				{
					fprintf(alpha_yyout, "tmp == NULL cannot happen. Exiting...\n");
					exit(-1);
				}

				tmp = head;	/*last struct is on the list so i can reuse tmp like this*/
				while(tmp->next != NULL)
				{
					fprintf(alpha_yyout, "While loop\n");
					fprintf(alpha_yyout, ANSI_COLOR_RED"Error comment in line %d col %d is not closed\n"ANSI_COLOR_RESET, tmp->lineno, tmp->col);
					tmp = tmp->next;
					free(tmp->prev);	/*also delete the list*/
				}
				
				fprintf(alpha_yyout, ANSI_COLOR_RED"Error comment in line %d col %d is not closed\n"ANSI_COLOR_RESET, tmp->lineno, tmp->col);
				free(tmp);
				break;
			}
			else if(opened == closed)
				break;
		}
	}
	
	/*fprintf(alpha_yyout, "Multi-line comment total %d opened and %d closed\n", opened, closed);*/
}

"//" {
	addColCounter(2);
	
	fprintf(alpha_yyout, "single-line comment in line %d col %d\n", yylineno, column);
	char c = 0;

	while(c != '\n')	/*ignore everything except \n*/
	{
		c = input();
	}
	resetColCounter();
}

{keyword} {	
	fprintf(alpha_yyout, "Line <%d> Col <%d>: #<%d> \"%s\" KEYWORD\n", alpha_yylineno, column, ++total_tokens, alpha_yytext);
	addColCounter(alpha_yyleng);
	((alpha_token_t)yylval)->lineno = alpha_yylineno; 
	((alpha_token_t)yylval)->tokennum = total_tokens;
	((alpha_token_t)yylval)->category = KEYWORD;
	((alpha_token_t)yylval)->value = malloc((alpha_yyleng + 1)*sizeof(char));	/*1 extra char for \0*/
	strncpy(((alpha_token_t)yylval)->value, alpha_yytext, alpha_yyleng);

	return KEYWORD;
}

{operator} {	
	fprintf(alpha_yyout, "Line <%d> Col <%d>: #<%d> \"%s\" OPERATOR\n", alpha_yylineno, column, ++total_tokens, alpha_yytext);
	addColCounter(alpha_yyleng);
	((alpha_token_t)yylval)->lineno = alpha_yylineno;
	((alpha_token_t)yylval)->tokennum = total_tokens;
	((alpha_token_t)yylval)->category = OPERATOR;
	((alpha_token_t)yylval)->value = malloc((alpha_yyleng + 1)*sizeof(char));	/*1 extra char for \0*/
	strncpy(((alpha_token_t)yylval)->value, alpha_yytext, alpha_yyleng);

	return OPERATOR;
}

{real} {
	fprintf(alpha_yyout, "Line <%d> Col <%d>: #<%d> \"%s\" REAL\n", alpha_yylineno, column, ++total_tokens, alpha_yytext);
	addColCounter(alpha_yyleng);
	((alpha_token_t)yylval)->lineno = alpha_yylineno;
	((alpha_token_t)yylval)->tokennum = total_tokens;
	((alpha_token_t)yylval)->category = REAL;
	((alpha_token_t)yylval)->value = malloc((alpha_yyleng + 1)*sizeof(char));	/*1 extra char for \0*/
	strncpy(((alpha_token_t)yylval)->value, alpha_yytext, alpha_yyleng);

	return REAL;
}

{integer} {
	fprintf(alpha_yyout, "Line <%d> Col <%d>: #<%d> \"%s\" INTEGER\n", alpha_yylineno, column, ++total_tokens, alpha_yytext);
	addColCounter(alpha_yyleng);
	((alpha_token_t)yylval)->lineno = alpha_yylineno;
	((alpha_token_t)yylval)->tokennum = total_tokens;
	((alpha_token_t)yylval)->category = INTEGER;
	((alpha_token_t)yylval)->value = malloc((alpha_yyleng + 1)*sizeof(char));	/*1 extra char for \0*/
	strncpy(((alpha_token_t)yylval)->value, alpha_yytext, alpha_yyleng);

	return INTEGER;
}

{string} {
	/*addColCounter(alpha_yyleng);*/
	((alpha_token_t)yylval)->lineno = alpha_yylineno;
	((alpha_token_t)yylval)->tokennum = ++total_tokens;
	((alpha_token_t)yylval)->category = STRING;
	
	int i, j, cToRemove = 0;

	for(i = 0; i < alpha_yyleng; i++)
	{
		if(alpha_yytext[i] == '\\')
		{
			if(alpha_yytext[i+1] == 'n' || alpha_yytext[i+1] == '\\' || alpha_yytext[i+1] == 't' || alpha_yytext[i+1] == '\"')
			{
				cToRemove++;
				i++;
			}
			else
			{
				
				fprintf(alpha_yyout, ANSI_COLOR_YELLOW"Warning : invalid escape character \'%c\' on string line %d col %d.\n"ANSI_COLOR_RESET,alpha_yytext[i+1], alpha_yylineno, column + i);
			}
		}
	}

	((alpha_token_t)yylval)->value = (char *) malloc((alpha_yyleng - cToRemove + 1)*sizeof(char));	/*1 extra char for \0*/
	j = 0;
	for(i = 0; i < alpha_yyleng; i++)
	{
		if(alpha_yytext[i] == '\\' && cToRemove > 0)
		{
			if(alpha_yytext[i+1] == 'n')
			{
				((alpha_token_t)yylval)->value[j] = '\n';
				i++;
				cToRemove--;
			}
			else if(alpha_yytext[i+1] == 't')
			{
				((alpha_token_t)yylval)->value[j] = '\t';
				i++;
				cToRemove--;
			}
			else if(alpha_yytext[i+1] == '\\')
			{
				((alpha_token_t)yylval)->value[j] = '\\';
				i++;
				cToRemove--;
			}
			else if(alpha_yytext[i+1] == '\"')
			{
				((alpha_token_t)yylval)->value[j] = '\"';
				i++;
				cToRemove--;
			}
			else
			{
				((alpha_token_t)yylval)->value[j] = alpha_yytext[i];
			}
		}
		else
			((alpha_token_t)yylval)->value[j] = alpha_yytext[i];
		j++;
	}
	((alpha_token_t)yylval)->value[j] = '\0';
	
	fprintf(alpha_yyout, "Line <%d> Col <%d>: #<%d> %s STRING\n", alpha_yylineno, column, total_tokens, ((alpha_token_t)yylval)->value);
	addColCounter(alpha_yyleng);

	return STRING;
}

"\"" {
	fprintf(alpha_yyout, ANSI_COLOR_RED"Error : string in line %d col %d is not closed. Exiting..."ANSI_COLOR_RESET"\n", yylineno, column);
	exit(-1);
}

{punctuation} {
	fprintf(alpha_yyout, "Line <%d> Col <%d>: #<%d> \"%s\" PUNCTUATION\n", alpha_yylineno, column, ++total_tokens, alpha_yytext);
	addColCounter(alpha_yyleng);
	((alpha_token_t)yylval)->lineno = alpha_yylineno;
	((alpha_token_t)yylval)->tokennum = total_tokens;
	((alpha_token_t)yylval)->category = PUNCTUATION;
	((alpha_token_t)yylval)->value = malloc((alpha_yyleng + 1)*sizeof(char));	/*1 extra char for \0*/
	strncpy(((alpha_token_t)yylval)->value, alpha_yytext, alpha_yyleng);

	return PUNCTUATION;
}

{id} {
	fprintf(alpha_yyout, "Line <%d> Col <%d>: #<%d> \"%s\" ID\n", alpha_yylineno, column, ++total_tokens, alpha_yytext);
	addColCounter(alpha_yyleng);
	((alpha_token_t)yylval)->lineno = alpha_yylineno;
	((alpha_token_t)yylval)->tokennum = total_tokens;
	((alpha_token_t)yylval)->category = ID;
	((alpha_token_t)yylval)->value = malloc((alpha_yyleng + 1)*sizeof(char));	/*1 extra char for \0*/
	strncpy(((alpha_token_t)yylval)->value, alpha_yytext, alpha_yyleng);

	return ID;
}

{undefined} {
	fprintf(alpha_yyout, ANSI_COLOR_RED"Error : undefined character in line %d col %d. Exiting...\n"ANSI_COLOR_RESET, yylineno, column);
	exit(-1);
}

%%

int main(int argc, char *argv[])
{
	FILE *outfile;
	alpha_token_t token = NULL, prev = NULL;
	alpha_token dummy;


	if(argc == 2)
	{
		if(!(alpha_yyin = fopen(argv[1], "r")))
		{
			fprintf(stderr, "cannot read file: %s\n", argv[1]);
			return 0;
		}
	}
	else if(argc == 3)
	{
		alpha_yyout = stdout;
		outfile = fopen(argv[2], "w");
		if(outfile == NULL)
		{
			fprintf(stderr,"Error: cannot open file to write\n");
			exit(1);
		}
		alpha_yyout = outfile;
		fprintf(outfile, "printed in file!!!\n");
		printf("This should go to console...\n");
	}
	else
	{
		printf("Usage scanner <file_name> (Optional)<outfile_name>\n");
		return -1;
	}

	prev = &dummy;
	dummy.next = NULL;
	dummy.value = NULL;
	while(1)
	{
		token = (alpha_token_t) malloc(sizeof(alpha_token));
		if(token == NULL)
		{
			fprintf(stderr, "Error getting memory for token struct. Exiting...\n");
			return -1;
		}
		prev->next = token;
		token->next = NULL;
		
		if(alpha_yylex(token) == -1)	/*-1 is returned when yylex reaches EOF*/
		{
			prev->next = NULL;
			free(token);
			break;
		}
		prev = token;		
	}

	/*print_token_list(dummy.next);*/

	
	return 0;
}
