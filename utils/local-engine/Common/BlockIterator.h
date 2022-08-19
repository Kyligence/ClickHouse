#pragma once

#include <Core/Block.h>



namespace local_engine
{
class BlockIterator
{

protected:
    void checkNextValid();
    void produce();
    void consume();

    DB::Block cached_block;
    bool consumed = true;
};
}

