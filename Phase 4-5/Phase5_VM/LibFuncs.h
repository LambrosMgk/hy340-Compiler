#ifndef LibFuncs_h
#define LibFuncs_h

#include "executors/Dispatcher.h"

void libfunc_print(void);

void libfunc_input(void);

void libfunc_objectmemberkeys(void);

void libfunc_objecttotalmembers(void);

void libfunc_objectcopy(void);

void libfunc_totalarguments(void);

void libfunc_argument(void);

void libfunc_typeof(void);

void libfunc_strtonum(void);

void libfunc_sqrt(void);

void libfunc_cos(void);

void libfunc_sin(void);

library_func_t avm_getlibraryfunc(char* id);

#endif