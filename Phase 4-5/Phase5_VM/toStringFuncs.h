#ifndef toStringFuncs_h
#define toStringFuncs_h

#include "executors/Dispatcher.h"

char* avm_tostring(avm_memcell* m);

char* number_tostring(avm_memcell* m);

char* string_tostring(avm_memcell* m);

char* bool_tostring(avm_memcell* m);

char* table_tostring(avm_memcell* m);

char* userfunc_tostring(avm_memcell* m);

char* libfunc_tostring(avm_memcell* m);

char* nil_tostring(avm_memcell* m);

char* undef_tostring(avm_memcell* m);

#endif