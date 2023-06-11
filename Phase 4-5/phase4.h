#ifndef phase4_h
#define phase4_h

#include "make_operand.h"

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

typedef struct instructionToBinary{

	int instrOpcode;
	
	int resultType;
	int resultOffset;
	
	int arg1Type;
	int arg1Offset;

	int arg2Type;
	int arg2Offset;

	int instrLine;

} instructionToBinary;

#endif