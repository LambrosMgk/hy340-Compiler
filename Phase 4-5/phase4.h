#ifndef phase4_h
#define phase4_h

#include "make_operand.h"

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