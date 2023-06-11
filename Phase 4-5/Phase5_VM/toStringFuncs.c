#include "toStringFuncs.h"

tostring_func_t tostringFuncs[] = {

	number_tostring,
	string_tostring,
	bool_tostring,
	table_tostring,
	userfunc_tostring,
	libfunc_tostring,
	nil_tostring,
	undef_tostring

};

char* avm_tostring(avm_memcell* m)
{
	assert(m->type >= 0 && m->type <= undef_m);
	return (*tostringFuncs[m->type])(m);
}

char* number_tostring(avm_memcell* m)
{
	assert(m->type == number_m);

    char* convertedStr = NULL;
    double decPart;

    decPart = modf(m->data.numVal, &decPart);

    if (decPart == 0)
    {
        int length = snprintf(NULL, 0, "%d", (int)m->data.numVal);
        convertedStr = malloc(length + 1);
        snprintf(convertedStr, length + 1, "%d", (int)m->data.numVal);
    }
    else
    {
        int length = snprintf(NULL, 0, "%lf", m->data.numVal);
        convertedStr = malloc(length + 1);
        snprintf(convertedStr, length + 1, "%lf", m->data.numVal);
    }

    return convertedStr;
}

char* string_tostring(avm_memcell* m)
{
	assert(m->type == string_m);
	return m->data.strVal;
}

char* bool_tostring(avm_memcell* m)
{
	assert(m->type == bool_m);
	if(m->data.boolVal == '0')
		return "false";
	else
		return "true";
}

char* table_tostring(avm_memcell* m)
{
	assert(m->type == table_m);

	printTable(m);

	return "";
}

char* userfunc_tostring(avm_memcell* m)
{
	assert(m->type == userfunc_m);
	char* convertedStr = "Func";
	return convertedStr;
}

char* libfunc_tostring(avm_memcell* m)
{
	char* convertedStr = "LibFunc";
	return convertedStr;
}

char* nil_tostring(avm_memcell* m)
{
	char* convertedStr = "Nil";
	return convertedStr;
}

char* undef_tostring(avm_memcell* m)
{
	char* convertedStr = "Undef";
	return convertedStr;
}