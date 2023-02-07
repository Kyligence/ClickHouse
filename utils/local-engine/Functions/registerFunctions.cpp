#include <Functions/FunctionFactory.h>

namespace local_engine
{
void registerFunctionSparkTrim(DB::FunctionFactory &);

void registerFunctions(DB::FunctionFactory  & factory)
{
    registerFunctionSparkTrim(factory);
}
}
