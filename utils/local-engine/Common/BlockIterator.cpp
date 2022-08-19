#include "BlockIterator.h"
#include <Common/Exception.h>

namespace DB
{
namespace ErrorCodes
{
    extern const int LOGICAL_ERROR;
}
}

namespace local_engine
{
void local_engine::BlockIterator::checkNextValid()
{
    if (consumed)
    {
        throw DB::Exception(DB::ErrorCodes::LOGICAL_ERROR, "Block iterator next should after hasNext");
    }
}
void BlockIterator::produce()
{
    consumed = false;
}
void BlockIterator::consume()
{
    consumed = true;
}
}

