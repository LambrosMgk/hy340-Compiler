#include "LibFuncs.h"

char* typeStrings[] = {

	"number",
	"string",
	"bool",
	"table",
	"userfunc",
	"libfunc",
	"nil",
	"undef"

};

void libfunc_print(void)
{
	unsigned int n = avm_totalactuals();
	unsigned int i;
	int j;
	char* s;

	for(i = 0; i < n; ++i)
	{	
		s = avm_tostring(avm_getactual(i)); 

		for(j = 0; j < strlen(s); j++)
		{ 
			if(s[j] == '\\' && s[j+1] == 'n')
			{
				printf("\n");
				j++;
			}
			else
			{
				printf("%c", s[j]);
			}
		}
	}
}

void libfunc_input(void)
{
	char* userInput = calloc (1, sizeof(char*));
	scanf("%s", userInput);
	char* strPure = strtok(userInput,"\"");

	retval.type = string_m;
	retval.data.strVal = strdup(strPure);
}

void libfunc_objectmemberkeys(void)
{
	unsigned int n = avm_totalactuals();

	if(n != 1)
	{
		char *nName = NULL;
    	asprintf(&nName, "%d",n);
		avm_print_error( "One argument and not(", nName , ") expected in 'libfunc objecttotalmembers' !" );
		executionFinished = 1;
		return;
	}

	if(avm_getactual(0)->type != table_m)
	{
		avm_print_error("libfunc objecttotalmembers ",0,", gets only arguments, of type table");
		executionFinished = 1;
		return;
	}

	if(avm_getactual(0)->data.tableVal != NULL)
	{
		avm_memcellClear(&retval);
		retval.type = table_m;
		retval.data.tableVal = avm_getactual(0)->data.tableVal;
	}
}

void libfunc_objecttotalmembers(void)
{
	unsigned int n = avm_totalactuals();

	if(n != 1)
	{
		char *nName = NULL;
    	asprintf(&nName, "%d",n);
		avm_print_error("One argument and not(", nName , ") expected in 'libfunc objecttotalmembers' !");
		executionFinished = 1;
		return;
	}

	if(avm_getactual(0)->type != table_m)
	{
		avm_print_error("libfunc objecttotalmembers ",0,", gets only arguments, of type table");
		executionFinished = 1;
		return;
	}

	if(avm_getactual(0)->data.tableVal != NULL)
	{
		avm_memcellClear(&retval);
		retval.type = number_m;
		retval.data.numVal = avm_getactual(0)->data.tableVal->total;
	}
}

void libfunc_objectcopy(void)
{
	
}

void libfunc_totalarguments(void)
{
	unsigned int p_topsp = avm_get_envvalue(topsp + AVM_SAVEDTOPSP_OFFSET);
	avm_memcellClear(&retval);

	if(!p_topsp)
	{
		avm_print_error("'totalarguments' called outside a function!",NULL,NULL);
		retval.type = nil_m;
		executionFinished = 1;
	}
	else
	{
		retval.type 		= number_m;
		retval.data.numVal	= avm_get_envvalue(p_topsp + AVM_NUMACTUALS_OFFSET);
	}
}

// to do
void libfunc_argument(void)
{
	unsigned int n = avm_totalactuals();

	if(n != 1)
	{
		char *nName = NULL;
    	asprintf(&nName, "%d",n);
		avm_print_error("One argument and not(", nName , ") expected in 'libfunc argument' !" );
		executionFinished = 1;
	}
	else
	{
		if(avm_getactual(0)->type != number_m)
		{
			avm_print_error("libfunc argument ",0,", gets only arguments, of type number");
			executionFinished = 1;

		}
		else
		{
			avm_memcellClear(&retval);
			memcpy(&retval,avm_getactual(0),sizeof(avm_memcell));
		}
	}
}

void libfunc_typeof(void)
{
	unsigned int n = avm_totalactuals();

	if(n != 1)
	{
		char *nName = NULL;
    	asprintf(&nName, "%d",n);
		avm_print_error("One argument and not(", nName , ") expected in 'typeof' !" );
		executionFinished = 1;
	}
	else
	{
		avm_memcellClear(&retval);
		retval.type = string_m;
		retval.data.strVal = strdup(typeStrings[avm_getactual(0)->type]);
	}
}

void libfunc_strtonum(void)
{
	unsigned int n = avm_totalactuals();

	if(n != 1)
	{
		char *nName = NULL;
    	asprintf(&nName, "%d",n);
		avm_print_error("One argument and not(", nName , ") expected in 'strtonum' !" );
		executionFinished = 1;
	}
	else
	{
		if(avm_getactual(0)->type != string_m)
		{
			avm_print_error("strtonum libfunc", 0, ", gets only arguments, of type string");
			executionFinished = 1;
		}
		else
		{
			avm_memcellClear(&retval);
			char* numPure = strtok( avm_getactual(0)->data.strVal, "\"");
			retval.type = number_m;
			retval.data.numVal = atoi(numPure);
		}
	}
}

void libfunc_sqrt(void)
{
	unsigned int n = avm_totalactuals();

	if(n != 1)
	{
		char *nName = NULL;
    	asprintf(&nName, "%d",n);
		avm_print_error("One argument and not(", nName , ") expected in 'sqrt' !" );
		executionFinished = 1;
	}
	else
	{
		if(avm_getactual(0)->type != number_m)
		{
			avm_print_error("sqrt libfunc",0,", gets only arguments, of type number");
			executionFinished = 1;
		}
		else
		{
			avm_memcellClear(&retval);
			retval.type = number_m;
			retval.data.numVal = sqrt(avm_getactual(0)->data.numVal);
		}
	}
}

void libfunc_cos(void)
{
	unsigned int n = avm_totalactuals();

	if(n != 1)
	{
		char *nName = NULL;
    	asprintf(&nName, "%d",n);
		avm_print_error( "One argument and not(", nName , ") expected in 'cos' !" );
		executionFinished = 1;
	}
	else
	{
		if(avm_getactual(0)->type != number_m)
		{
			avm_print_error("cos libfunc",0,", gets only arguments, of type number");
			executionFinished = 1;
		}
		else
		{
			avm_memcellClear(&retval);
			retval.type = number_m;
			retval.data.numVal = cos(avm_getactual(0)->data.numVal);
		}
	}
}

void libfunc_sin(void)
{
	unsigned int n = avm_totalactuals();

	if(n != 1)
	{
		char *nName = NULL;
    	asprintf(&nName, "%d",n);
		avm_print_error( "One argument and not(", nName , ") expected in 'sin' !" );
		executionFinished = 1;
	}else
	{
		if(avm_getactual(0)->type != number_m)
		{
			avm_print_error("sin libfunc",0,", gets only arguments, of type number");
			executionFinished = 1;
		}
		else
		{
			avm_memcellClear(&retval);
			retval.type = number_m;
			retval.data.numVal = sin(avm_getactual(0)->data.numVal);
		}
	}
}

library_func_t avm_getlibraryfunc(char* id)
{
	if(strcmp("print", id) == 0)
	{
		return libfunc_print;
	}
	else if(strcmp("input", id) == 0)
	{
		return libfunc_input;		
	}
	else if(strcmp("objectmemberkeys", id) == 0)
	{
		return libfunc_objectmemberkeys;		
	}
	else if(strcmp("objecttotalmembers", id) == 0)
	{
		return libfunc_objecttotalmembers;		
	}
	else if(strcmp("objectcopy", id) == 0)
	{
		return libfunc_objectcopy;		
	}
	else if(strcmp("totalarguments", id) == 0)
	{
		return libfunc_totalarguments;		
	}
	else if(strcmp("argument", id) == 0)
	{
		return libfunc_argument;		
	}
	else if(strcmp("typeof", id) == 0)
	{
		return libfunc_typeof;		
	}
	else if(strcmp("strtonum", id) == 0)
	{
		return libfunc_strtonum;		
	}
	else if(strcmp("sqrt", id) == 0)
	{
		return libfunc_sqrt;		
	}
	else if(strcmp("cos", id) == 0)
	{
		return libfunc_cos;		
	}
	else if(strcmp("sin", id) == 0)
	{
		return libfunc_sin;		
	}

	return 0;
}