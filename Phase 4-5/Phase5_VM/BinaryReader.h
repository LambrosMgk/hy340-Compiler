#ifndef BinaryReader_h
#define BinaryReader_h


#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "Linker.h"

typedef struct instructionToBinary instructionToBinary;
typedef struct numberToBinary numberToBinary;
typedef struct stringToBinary stringToBinary;
typedef struct userFuncToBinary userFuncToBinary;
typedef struct libFuncToBinary libFuncToBinary;

struct instructionToBinary{

	int instrOpcode;
	
	int resultType;
	int resultOffset;
	
	int arg1Type;
	int arg1_Offset;

	int arg2Type;
	int arg2_Offset;

	int instrLine;

};

#endif