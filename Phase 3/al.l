%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

#include "syntax.h"


#define ANSI_COLOR_RED		"\x1b[41m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_RESET   "\x1b[0m"


typedef struct alpha_token
{
	unsigned int lineno, tokennum;
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
		fprintf(alpha_yyout, "Line <%d>: #<%d> \"%s\"\n", tmp->lineno, tmp->tokennum, tmp->value);
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
					fprintf(alpha_yyout, ANSI_COLOR_RED"Error comment in line %d col %d is not closed"ANSI_COLOR_RESET"\n", tmp->lineno, tmp->col);
					tmp = tmp->next;
					free(tmp->prev);	/*also delete the list*/
				}
				
				fprintf(alpha_yyout, ANSI_COLOR_RED"Error comment in line %d col %d is not closed"ANSI_COLOR_RESET"\n", tmp->lineno, tmp->col);
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
	addColCounter(alpha_yyleng);
	fprintf(alpha_yyout, "Line <%d> Col <%d>: #<%d> \"%s\" keyword\n", alpha_yylineno, column, ++total_tokens, alpha_yytext);
	
	if(strcmp(alpha_yytext, "if") == 0)
		return IF;
	else if(strcmp(alpha_yytext, "else") == 0)
		return ELSE;
	else if(strcmp(alpha_yytext, "while") == 0)
		return WHILE;
	else if(strcmp(alpha_yytext, "for") == 0)
		return FOR;
	else if(strcmp(alpha_yytext, "function") == 0)
		return FUNCTION;
	else if(strcmp(alpha_yytext, "return") == 0)
		return RETURN;
	else if(strcmp(alpha_yytext, "break") == 0)
		return BREAK;
	else if(strcmp(alpha_yytext, "continue") == 0)
		return CONTINUE;
	else if(strcmp(alpha_yytext, "and") == 0)
		return AND;
	else if(strcmp(alpha_yytext, "or") == 0)
		return OR;
	else if(strcmp(alpha_yytext, "not") == 0)
		return NOT;
	else if(strcmp(alpha_yytext, "local") == 0)
		return local;
	else if(strcmp(alpha_yytext, "true") == 0)
		return TRUE;
	else if(strcmp(alpha_yytext, "false") == 0)
		return FALSE;
	else if(strcmp(alpha_yytext, "nil") == 0)
		return NIL;
}

{operator} {	
	addColCounter(alpha_yyleng);
	fprintf(alpha_yyout, "Line <%d> Col <%d>: #<%d> \"%s\" operator\n", alpha_yylineno, column, ++total_tokens, alpha_yytext);
	
	if(strcmp(alpha_yytext, "+") == 0)
		return plus;
	else if(strcmp(alpha_yytext, "-") == 0)
		return minus;
	else if(strcmp(alpha_yytext, "*") == 0)
		return mul;
	else if(strcmp(alpha_yytext, "/") == 0)
		return divide;
	else if(strcmp(alpha_yytext, "%") == 0)
		return mod;
	else if(strcmp(alpha_yytext, ">") == 0)
		return greater;
	else if(strcmp(alpha_yytext, ">=") == 0)
		return ge;
	else if(strcmp(alpha_yytext, "<") == 0)
		return less;
	else if(strcmp(alpha_yytext, "<=") == 0)
		return le;
	else if(strcmp(alpha_yytext, "==") == 0)
		return equal;
	else if(strcmp(alpha_yytext, "!=") == 0)
		return neq;
	else if(strcmp(alpha_yytext, "++") == 0)
		return plusplus;
	else if(strcmp(alpha_yytext, "--") == 0)
		return minusminus;
	else if(strcmp(alpha_yytext, "=") == 0)
		return assign;
}

{real} {
	fprintf(alpha_yyout, "Line <%d> Col <%d>: #<%d> \"%s\" REAL\n", alpha_yylineno, column, ++total_tokens, alpha_yytext);
	addColCounter(alpha_yyleng);

	double d;
	sscanf(alpha_yytext, "%lf", &d);
	alpha_yylval.doubleval = d;

	return NUMBER;
}

{integer} {
	fprintf(alpha_yyout, "Line <%d> Col <%d>: #<%d> \"%s\" INTEGER\n", alpha_yylineno, column, ++total_tokens, alpha_yytext);
	addColCounter(alpha_yyleng);

	alpha_yylval.intVal = atoi(alpha_yytext);

	return NUMBER;
}

{string} {
	/*addColCounter(alpha_yyleng);*/
	
	char *value = NULL;
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
				
				fprintf(alpha_yyout, ANSI_COLOR_YELLOW"Warning : invalid escape character \'%c\' on string line %d col %d."ANSI_COLOR_RESET"\n",alpha_yytext[i+1], alpha_yylineno, column + i);
			}
		}
	}

	value = (char *) malloc((alpha_yyleng - cToRemove + 1)*sizeof(char));	/*1 extra char for \0*/
	j = 0;
	for(i = 0; i < alpha_yyleng; i++)
	{
		if(alpha_yytext[i] == '\\' && cToRemove > 0)
		{
			if(alpha_yytext[i+1] == 'n')
			{
				value[j] = '\n';
				i++;
				cToRemove--;
			}
			else if(alpha_yytext[i+1] == 't')
			{
				value[j] = '\t';
				i++;
				cToRemove--;
			}
			else if(alpha_yytext[i+1] == '\\')
			{
				value[j] = '\\';
				i++;
				cToRemove--;
			}
			else if(alpha_yytext[i+1] == '\"')
			{
				value[j] = '\"';
				i++;
				cToRemove--;
			}
			else
			{
				value[j] = alpha_yytext[i];
			}
		}
		else
			value[j] = alpha_yytext[i];
		j++;
	}
	value[j] = '\0';
	
	fprintf(alpha_yyout, "Line <%d> Col <%d>: #<%d> %s STRING\n", alpha_yylineno, column, total_tokens, value);
	addColCounter(alpha_yyleng);

	alpha_yylval.strVal = strdup(value);

	return STRING;
}

"\"" {
	fprintf(alpha_yyout, ANSI_COLOR_RED"Error : string in line %d col %d is not closed. Exiting..."ANSI_COLOR_RESET"\n", yylineno, column);
	exit(-1);
}

{punctuation} {
	fprintf(alpha_yyout, "Line <%d> Col <%d>: #<%d> \"%s\" PUNCTUATION\n", alpha_yylineno, column, ++total_tokens, alpha_yytext);
	addColCounter(alpha_yyleng);
	
	if(strcmp(alpha_yytext, "{") == 0)
		return LCurlyBracket;
	else if(strcmp(alpha_yytext, "}") == 0)
		return RCurlyBracket;
	else if(strcmp(alpha_yytext, "[") == 0)
		return LSquareBracket;
	else if(strcmp(alpha_yytext, "]") == 0)
		return RSquareBracket;
	else if(strcmp(alpha_yytext, "(") == 0)
		return Lparenthesis;
	else if(strcmp(alpha_yytext, ")") == 0)
		return Rparenthesis;
	else if(strcmp(alpha_yytext, ";") == 0)
		return Semicolon;
	else if(strcmp(alpha_yytext, ",") == 0)
		return comma;
	else if(strcmp(alpha_yytext, ":") == 0)
		return colon;
	else if(strcmp(alpha_yytext, "::") == 0)
		return coloncolon;
	else if(strcmp(alpha_yytext, ".") == 0)
		return dot;
	else if(strcmp(alpha_yytext, "..") == 0)
		return dotdot;
}

{id} {
	fprintf(alpha_yyout, "Line <%d> Col <%d>: #<%d> \"%s\" ID\n", alpha_yylineno, column, ++total_tokens, alpha_yytext);
	addColCounter(alpha_yyleng);

	alpha_yylval.strVal = strndup(alpha_yytext, alpha_yyleng);

	return ID;
}

{undefined} {
	fprintf(alpha_yyout, ANSI_COLOR_RED"Error : undefined character in line %d col %d. Exiting..."ANSI_COLOR_RESET"\n", yylineno, column);
	exit(-1);
}

%%