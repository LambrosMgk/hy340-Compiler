#include "executors/Dispatcher.h"

unsigned int totalActuals = 0;
int innerTablePrint = 0; 
avm_memcell stack[AVM_STACKSIZE];

library_func_t libraryFuncs[12];


arithmetic_func_t arithmeticFuncs[] = {

	add_impl,
	sub_impl,
	mul_impl,
	div_impl,
	mod_impl

};

cmp_func_t 	comparisonFuncs[] = {

	jle_impl,
	jge_impl,
	jlt_impl,
	jgt_impl

};

tobool_func_t toboolFuncs[] = {

	number_tobool,
	string_tobool,
	bool_tobool,
	table_tobool,
	userfunc_tobool,
	libfunc_tobool,
	nil_tobool,
	undef_tobool

};

void avm_tableIncRefCounter(avm_table* t)
{
	++t->refCounter;
}

void avm_tableDecRefCounter(avm_table* t)
{
	assert(t->refCounter > 0);

	if(! --t->refCounter)
		avm_tableDestroy(t);
}

void avm_tableBucketsInit(avm_table_bucket** p)
{
	unsigned int i = 0;

	for(i = 0; i < AVM_TABLE_HASHSIZE; i++)
	{
		p[i] = (avm_table_bucket*) 0;
	}
}

avm_table* avm_tableNew(void)
{
	avm_table* t = (avm_table*) malloc(sizeof(avm_table));
	memset(t, 0, sizeof(*t));

	t->refCounter = t->total = 0;
	avm_tableBucketsInit(t->numIndexed);
	avm_tableBucketsInit(t->strIndexed);

	return t;
}

void avm_tableBucketsDestroy(avm_table_bucket** p)
{
	unsigned int i = 0;
	avm_table_bucket* b;

	for(i = 0; i < AVM_TABLE_HASHSIZE; i++, p++)
	{
		for(b = *p; b;)
		{
			avm_table_bucket* del = b;
			b = b->next;
			avm_memcellClear(&del->key);
		    avm_memcellClear(&del->value);
			//free(del);
		}
		p[i] = (avm_table_bucket*) 0;
	}
}

void avm_tableDestroy(avm_table* t)
{
	avm_tableBucketsDestroy(t->strIndexed);
	avm_tableBucketsDestroy(t->numIndexed);
}

void memclear_string(avm_memcell* m)
{
	assert(m->data.strVal);
	free(m->data.strVal);
}

void memclear_table(avm_memcell* m)
{
	assert(m->data.tableVal);
	avm_tableDecRefCounter(m->data.tableVal);
}

memclear_func_t memclearFuncs[] = {

	0,					//number
	memclear_string,
	0,					//bool					
	memclear_table,
	0,					//userfunc
	0,					//libfunc
	0,					//nil
	0					//undef
};

void avm_memcellClear(avm_memcell* m)
{
	if(m->type != undef_m)
	{
		memclear_func_t f = memclearFuncs[m->type];
		if (f)
			(*f)(m);
		m->type = undef_m;
	}
}

void avm_print_warning(char* msg1, char* id, char* msg2)
{
	printf(ANSI_COLOR_YELLOW"%s"ANSI_COLOR_RESET, msg1);

	if(id != NULL)
		printf("%s ",id);
	
	
	if(msg2 != NULL)
		printf("%s",msg2);
	
	printf("\n");
}

void avm_print_error(char* msg1, char* id, char* msg2)
{
	printf(ANSI_COLOR_RED"%s"ANSI_COLOR_RESET,msg1);
	
	if(id != NULL)
		printf("%s ",id);
	
	
	if(msg2 != NULL)
		printf("%s",msg2);
	
	printf("\n");
}

void avm_assign(avm_memcell* lv, avm_memcell* rv)
{
	if(lv == rv)
		return;

	if(lv->type == table_m && rv->type == table_m &&
		lv->data.tableVal == rv->data.tableVal)
	{
		return;
	}

	if(rv->type == undef_m)
		avm_print_warning("assigning from 'undef' content !", NULL, NULL);

	avm_memcellClear(lv);
	
	memcpy(lv, rv, sizeof(avm_memcell));
	

	if(lv->type == string_m)
		lv->data.strVal = strdup(rv->data.strVal);
	else if(lv->type == table_m)
	{
		avm_tableIncRefCounter(lv->data.tableVal);
	}
}

void avm_dec_top(void)
{
	if(!top)
	{
		avm_print_error("Stack Overflow!\n", NULL, NULL);
		executionFinished = 1;
		exit(0);
	}

	--top;
}

void avm_push_envValue(unsigned int val)
{
	stack[top].type	= number_m;
	stack[top].data.numVal = val;
	avm_dec_top();
}

void avm_callSaveEnvironment(void)
{
	avm_push_envValue(totalActuals);
	avm_push_envValue(pc + 1);
	avm_push_envValue(top + totalActuals + 2);
	avm_push_envValue(topsp);
}

unsigned int avm_get_envvalue(unsigned int i)
{
	assert(stack[i].type == number_m);
	unsigned int val = (unsigned int) stack[i].data.numVal;
	assert(stack[i].data.numVal == (double) val);

	return val;
}

void avm_callLibFunc(char* id)
{
	library_func_t f = avm_getlibraryfunc(id);

	if(!f)
	{
		avm_print_error("Library function '",id,"' is not supported!");
		executionFinished = 1;
	}
	else
	{
		topsp = top;
		totalActuals = 0;
		(*f)();
		if(!executionFinished)
		{
			execute_funcexit((instruction * )0);
		}
	}
}

unsigned int avm_totalactuals(void)
{
	return avm_get_envvalue(topsp + AVM_NUMACTUALS_OFFSET);
}

avm_memcell* avm_getactual(unsigned int i)
{
	assert(i < avm_totalactuals());
	return &stack[topsp + AVM_STACKENV_SIZE + 1 + i];
}

void printTable(avm_memcell* t)
{
	avm_table_bucket* reader = NULL;
	int k;

	if(t->type == table_m)
	{
		if(!innerTablePrint) 
			printf("[\n");
		else
			printf("[ ");


		for(k = 0; k < AVM_TABLE_HASHSIZE; k++)
		{
			reader = t->data.tableVal->strIndexed[k];

			while(reader != NULL)
			{
				if(!innerTablePrint) 
					printf("\t{ ");
				else
					printf(" { ");

				if(reader->key.type == string_m)
				{
					printf("\"%s\" : ", reader->key.data.strVal);
				}
				else if(reader->key.type == number_m)
				{
					printf("%d : ", (int) reader->key.data.numVal);
				}

				if(reader->value.type == table_m)
					innerTablePrint = 1;

				printf("%s", avm_tostring(&reader->value));							

				if(!innerTablePrint) 
					printf(" } ,\n");
				else
					printf(" } , ");

				reader = reader->next;
			}

			reader = t->data.tableVal->numIndexed[k];
			
			while(reader != NULL)
			{ 
				if(!innerTablePrint) 
					printf("\t{ ");
				else
					printf(" { ");

				if(reader->key.type == string_m)
				{
					printf("\"%s\" : ", reader->key.data.strVal);
				}
				else if(reader->key.type == number_m)
				{
					printf("%d : ", (int) reader->key.data.numVal);
				}

				if(reader->value.type == table_m)
					innerTablePrint = 1;

				printf("%s", avm_tostring(&reader->value));

				reader = reader->next;

				if(!innerTablePrint) 
					printf(" } ,\n");
				else
					printf(" } , ");
			}
		}

		if(!innerTablePrint) 
			printf(" \t ] \n\n");
		else
			printf(" ]");
	}

	innerTablePrint = 0;
}


double add_impl(double x , double y){ return x + y; }

double sub_impl(double x , double y){ return x - y; }

double mul_impl(double x , double y){ return x * y; }

double div_impl(double x , double y)
{
	if(y != 0)
	{
		return x/y;
	}
	avm_print_error("Division by 0 is not allowed", NULL, NULL);
	executionFinished = 1;
	return -1.0;
}

double mod_impl(double x , double y)
{
	if(y != 0)
	{
		return (unsigned int)x % (unsigned int)y;
	}
	avm_print_error("Division by 0 is not allowed", NULL, NULL);
	executionFinished = 1;
	return -1.0;
}

void execute_arithmetic(instruction* instr)
{
	avm_memcell* lv = avm_translate_operand(&instr->result, (avm_memcell*) 0 );
	avm_memcell* rv1 = avm_translate_operand(&instr->arg1, &ax);
	avm_memcell* rv2 = avm_translate_operand(&instr->arg2, &bx);

	assert(lv && (&stack[AVM_STACKSIZE - 1] >= lv && lv > &stack[top] || lv == &retval));
	assert(rv1 && rv2);

	if(rv1->type != number_m || rv2->type != number_m)
	{
		avm_print_error("Not a number in arithmetic!",NULL,NULL);
		executionFinished = 1;
	}
	else
	{
		arithmetic_func_t op = arithmeticFuncs[instr->opcode - add_v];
		avm_memcellClear(lv);
		lv->type = number_m;
		lv->data.numVal = (*op) (rv1->data.numVal , rv2->data.numVal);	
	}
}

unsigned char jle_impl(double x , double y) { return x <= y; }

unsigned char jge_impl(double x , double y) { return x >= y; }

unsigned char jlt_impl(double x , double y) { return x < y; }

unsigned char jgt_impl(double x , double y) { return x > y; }

void execute_comparison(instruction* instr)
{
	avm_memcell* rv1 = avm_translate_operand(&instr->arg1, &ax);
	avm_memcell* rv2 = avm_translate_operand(&instr->arg2, &bx);

	assert(rv1 && rv2);

	
	if(rv1->type != number_m || rv2->type != number_m)
	{
		avm_print_error("Only numbers are allowed for comparison!", NULL, NULL);
		executionFinished = 1;
	}
	else
	{
		cmp_func_t cmp = comparisonFuncs[instr->opcode - jle_v];
		unsigned char result = (*cmp) (rv1->data.numVal, rv2->data.numVal);

		if(!executionFinished && result)
		{
			pc = instr->result.val;
		}
	}
}

unsigned char number_tobool (avm_memcell* m)
{
	return m->data.numVal != 0;
}

unsigned char string_tobool (avm_memcell* m)
{
	return m->data.strVal[0] != 0;
} 

unsigned char bool_tobool (avm_memcell* m)
{
	return m->data.boolVal;
} 

unsigned char table_tobool (avm_memcell* m)
{
	return 1;
} 

unsigned char userfunc_tobool (avm_memcell* m)
{
	return 1;
} 

unsigned char libfunc_tobool (avm_memcell* m)
{
	return 1;
} 

unsigned char nil_tobool (avm_memcell* m)
{
	return 0;
}

unsigned char undef_tobool (avm_memcell* m)
{
	assert(0);
	return 0;
}

unsigned char avm_tobool(avm_memcell *m)
{
	assert(m->type >= 0 && m->type < undef_m);
	return (*toboolFuncs[m->type])(m);
}

void avm_initialize(void)
{
	avm_initstack();
}

userfunc* avm_getfuncinfo(unsigned int address)
{
	assert(address >= 0 && address < totalUserFuncs);
	return &userFuncsTable[address]; 
}

void avm_tablesetelem(avm_table* table, avm_memcell* index, avm_memcell* value)
{
	assert(table);
	
	int indexOfTable;

	avm_memcell* tableGet = avm_tablegetelem(table,index);

	if(index->type == string_m)
	{
		indexOfTable = (int) strlen(index->data.strVal) % AVM_TABLE_HASHSIZE;
		
		if(tableGet != NULL)
		{
			avm_assign(tableGet, value);
			return;
		}

        if(table->strIndexed[indexOfTable] == NULL)
		{
			table->strIndexed[indexOfTable] = (avm_table_bucket*) malloc (sizeof(avm_table_bucket));

			avm_table_bucket* newBucket = (avm_table_bucket*) malloc (sizeof(avm_table_bucket));
			newBucket->key = *index;

			if(value->type == table_m)
			{
				avm_tableIncRefCounter(value->data.tableVal);
			}

			newBucket->value = *value;

			table->strIndexed[indexOfTable] = newBucket ;

			table->strIndexed[indexOfTable]->next = NULL;
			table->total++;

			return;
        }
        
        avm_table_bucket* tmp=table->strIndexed[indexOfTable];
        while(tmp->next!=NULL)
		{ 
			tmp=tmp->next; 
		}

        avm_table_bucket* newBucket = (avm_table_bucket*) malloc (sizeof(avm_table_bucket));
        newBucket->key = *index;

        if(value->type == table_m)
		{
        	avm_tableIncRefCounter(value->data.tableVal);
        }

        newBucket->value = *value;
        tmp->next = newBucket;
        newBucket->next = NULL;
        table->total++;

	}
	else if(index->type == number_m)
	{

		indexOfTable = (int) index->data.numVal % AVM_TABLE_HASHSIZE;

		if(tableGet != NULL)
		{
			avm_assign(tableGet, value);
			return;
		}

		if(table->numIndexed[indexOfTable] == NULL)
		{
		  	table->numIndexed[indexOfTable]=(avm_table_bucket*) malloc (sizeof(avm_table_bucket));

            avm_table_bucket* newBucket = (avm_table_bucket*) malloc (sizeof(avm_table_bucket));
    		newBucket->key.data.numVal = index->data.numVal;

    		if(value->type == table_m)
			{
        		avm_tableIncRefCounter(value->data.tableVal);
        	}

    		newBucket->value = *value;

    		table->numIndexed[indexOfTable] = newBucket;

            table->numIndexed[indexOfTable]->next = NULL;
            table->total++;

            return;
		}

		avm_table_bucket* tmp = table->numIndexed[indexOfTable];
		while(tmp->next!=NULL)
		{ 
			tmp = tmp->next; 
		}

		avm_table_bucket* newBucket = (avm_table_bucket*) malloc (sizeof(avm_table_bucket));
		newBucket->key = *index;

		if(value->type == table_m)
		{
 			avm_tableIncRefCounter(value->data.tableVal);
        }

		newBucket->value = *value;
		tmp->next = newBucket;
		newBucket->next = NULL;
		table->total++;
	}
}

avm_memcell* avm_tablegetelem(avm_table* table, avm_memcell* index)
{
	assert(table);

	int indexOfTable;

	if(index->type == string_m)
	{
		indexOfTable = (int) strlen(index->data.strVal) % AVM_TABLE_HASHSIZE;

		if(table->strIndexed[indexOfTable] != NULL)
		{
			avm_table_bucket* tmp = table->strIndexed[indexOfTable];
			while(tmp != NULL)
			{
				if(strcmp(tmp->key.data.strVal, index->data.strVal) == 0)
					return &tmp->value;

				tmp = tmp->next;
			}
		}
	}
	else if(index->type == number_m)
	{
		indexOfTable = (int) index->data.numVal % AVM_TABLE_HASHSIZE;

		if(table->numIndexed[indexOfTable] != NULL)
		{
			avm_table_bucket* tmp = table->numIndexed[indexOfTable];
			while(tmp != NULL)
			{
				if(tmp->key.data.numVal == index->data.numVal)
					return &tmp->value;

				tmp = tmp->next;
			}
		}
	}
	
	return NULL;
}