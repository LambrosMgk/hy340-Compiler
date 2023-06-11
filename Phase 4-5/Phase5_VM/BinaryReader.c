#include "BinaryReader.h"

unsigned int totalGlobals;

char* opcodeToString[] = {
	"assign", "add", "sub", "mul", "div", "mod",

	"jeq", "jne", "jle", "jge", "jlt", "jgt",

	"jump", "call", "pusharg", "funcenter", "funcexit", "newtable", "tablegetelem", "tablesetelem", "nop"
};

char* typeToStringArray[] = {

    "0  (label), ",      
    "1  (global), ",    
    "2  (formal), ",    
    "3  (local), ",     
    "4  (number), ",    
    "5  (string), ",    
    "6  (bool), ",      
    "7  (nil), ",       
    "8  (userfunc), ",  
    "9  (libfunc), ",   
    "10 (retval), "

};

char* typeToString(int type)
{
	if(type < 0 || type > 10)
	{
		return "";
	}
	else
	{
		return typeToStringArray[type];
	}
}


/*Reads the binary file from phase 4 and returns a struct that has all the const arrays*/
DataTables* decoder(int printFlag, char* BinaryName)
{
	DataTables* tables;
	tables = (DataTables*) malloc(sizeof(DataTables));
	memset(tables, 0, sizeof(DataTables));


	instructionToBinary instr;

	unsigned int CorrectNumberBinary = 0;

	unsigned int totalNumConstsBinary = 0;

	unsigned int totalStringConstsBinary = 0;
	
	unsigned int totalUserFuncsBinary = 0;
	
	unsigned int totalNamedLibFuncsBinary = 0;
	
	unsigned int codeTableSize = 0;

	totalGlobals = 0; 

	printf("Binary name: %s\n", BinaryName);

	FILE *fp = fopen(BinaryName, "rb");
	if(fp == NULL) 
	{
		printf(ANSI_COLOR_RED"Error while opening file %s. Exiting..."ANSI_COLOR_RESET"\n", BinaryName);
		exit(0);
	}

	if(fread(&CorrectNumberBinary,sizeof(CorrectNumberBinary), 1, fp) == 1)
	{
		if(CorrectNumberBinary != 42069360)
		{
			printf(ANSI_COLOR_RED"Data corrupted in binary file, unexpected CorrectNumber. Exiting..."ANSI_COLOR_RESET"\n");
			exit(0);
			
		}
		if(printFlag) 
			printf("CorrectNumber is Ok.\n");
	}

	fread(&totalNumConstsBinary,		sizeof(totalNumConstsBinary),		1,fp);	//Reading the sizes
	fread(&totalStringConstsBinary,		sizeof(totalStringConstsBinary),	1,fp);
	fread(&totalNamedLibFuncsBinary,	sizeof(totalNamedLibFuncsBinary),	1,fp);
	fread(&totalUserFuncsBinary,		sizeof(totalUserFuncsBinary),		1,fp);
	fread(&codeTableSize,				sizeof(codeTableSize),				1,fp);
	fread(&totalGlobals,				sizeof(totalGlobals),				1,fp);

	tables->numConstsTable = (double*) malloc(sizeof(double) * totalNumConstsBinary);
	tables->totalNumConsts = totalNumConstsBinary;

	tables->strConstsTable = (char**) malloc(sizeof(char*) * totalStringConstsBinary);
	tables->totalStrConsts = totalStringConstsBinary;

	tables->userFuncsTable = (userfunc*) malloc(sizeof(userfunc) * totalUserFuncsBinary);
	tables->totalUserFuncs = totalUserFuncsBinary;

	tables->libFuncsTable = (char**) malloc(sizeof(char*) * totalNamedLibFuncsBinary);
	tables->totalLibFuncs = totalNamedLibFuncsBinary;

	tables->code = (instruction*) malloc(sizeof(instruction) * codeTableSize);
	tables->codeSize = codeTableSize;

	if(!tables->numConstsTable || !tables->strConstsTable || !tables->userFuncsTable || !tables->libFuncsTable || !tables->code)
	{
		fprintf(stderr, "Malloc failed while reading the binary file. Exiting...\n");
		exit(-1);
	}

	int currStringSize = 0;
	int i = 0;
	int offset = 0;
	int address = 0;
	int localSize = 0;
	int totalargs = 0;
	double num = 0;
	char* str = NULL;	

	if(printFlag) 
		printf("PINAKAS ARITHMITIKWN STATHERWN\n");

	for(i = 0; i < totalNumConstsBinary; i++)
	{
		fread(&offset, sizeof(int), 1, fp);
		fread(&tables->numConstsTable[offset], sizeof(double), 1, fp);
		
		if(printFlag)
		{
			printf("[%d] = %f\n", offset, tables->numConstsTable[offset]);
		}

	}
	if(printFlag) 
		printf("\n");


	if(printFlag) 
		printf("PINAKAS STATHERWN STRINGS\n");

	for(i = 0; i < totalStringConstsBinary; i++)
	{
		fread(&currStringSize, sizeof(int), 1, fp); 
	    str = calloc(currStringSize, sizeof(char));

		fread(&offset, sizeof(int), 1, fp);
		fread(str, sizeof(char)*currStringSize, 1, fp);  

		tables->strConstsTable[offset] = strdup(str);

		if(printFlag)
		{
			printf("[%d] %s\n", offset, tables->strConstsTable[offset]);
		}
		str = NULL;
	}
	if(printFlag) 
		printf("\n");


	if(printFlag) 
		printf("PINAKAS SUNARTISEWN XRHSTH\n");

	for(i = 0; i < totalUserFuncsBinary; i++)
	{
		fread(&currStringSize, sizeof(int), 1, fp); 
	    str = calloc(currStringSize, sizeof(char));

		fread(&offset, sizeof(int), 1, fp);
		fread(&address, sizeof(int), 1, fp);
		fread(&localSize, sizeof(int), 1, fp);
		fread(&totalargs, sizeof(int), 1, fp);
		fread(str, sizeof(char)*currStringSize, 1, fp);

		tables->userFuncsTable[offset].id = (char*) strdup(str);
		tables->userFuncsTable[offset].address = address;
		tables->userFuncsTable[offset].localSize = localSize;
		tables->userFuncsTable[offset].totalargs = totalargs;

		if(printFlag)
		{
			printf("[%d] address %d, localSize %d, totalargs %d, id %s\n", offset, tables->userFuncsTable[offset].address,
			tables->userFuncsTable[offset].localSize, tables->userFuncsTable[offset].totalargs, tables->userFuncsTable[offset].id);
		}
		str = NULL;
	}
	if(printFlag) 
		printf("\n");


	if(printFlag) 
		printf("PINAKAS SUNARTISEWN BIBLIOTHIKHS\n");

	for(i = 0; i < totalNamedLibFuncsBinary; i++)
	{
		fread(&currStringSize, sizeof(int), 1, fp); 
	    str = calloc(currStringSize, sizeof(char));

		fread(&offset, sizeof(int), 1, fp);
		fread(str, sizeof(char)*currStringSize, 1, fp);

		tables->libFuncsTable[offset] = strdup (str);
		if(printFlag)
		{
			printf("[%d] %s\n", offset, tables->libFuncsTable[offset]);
		}
		str = NULL;		
	}
	if(printFlag) 
		printf("\n");


	if(printFlag) 
	{
		printf("instr#     opcode              result                      arg1                             arg2                           srcL\n");
		printf("-------------------------------------------------------------------------------------------------------------------------------\n");
	}

	for (i = 0; i < codeTableSize ; i++)
	{
		fread(&instr, sizeof(instr), 1, fp);

		tables->code[i].opcode = instr.instrOpcode;

		tables->code[i].result.type = instr.resultType;
		tables->code[i].result.val = instr.resultOffset;

		tables->code[i].arg1.type = instr.arg1Type;
		tables->code[i].arg1.val = instr.arg1_Offset;

		tables->code[i].arg2.type = instr.arg2Type;
		tables->code[i].arg2.val = instr.arg2_Offset;

		tables->code[i].srcLine	= instr.instrLine;

	    if(printFlag)
		{
			printf("<%03d>:   op: %8s,    ", i, opcodeToString[instr.instrOpcode]);
        
			printf("type:%14s    ", typeToString(instr.resultType));
			printf("%3d,    ", instr.resultOffset);
			
			printf("type:%14s    ", typeToString(instr.arg1Type));
			printf("%3d,    ", instr.arg1_Offset);

			printf("type:%14s    ", typeToString(instr.arg2Type));
			printf("%3d,    ", instr.arg2_Offset);

			printf("%4d\n", instr.instrLine);
		}
	}
	printf("\n");

	fclose(fp);

	return tables;
}