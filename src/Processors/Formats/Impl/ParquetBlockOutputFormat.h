#pragma once
#include "config.h"

#if USE_PARQUET
#    include <Processors/Formats/IOutputFormat.h>
#    include <Formats/FormatSettings.h>

namespace arrow
{
class Array;
class DataType;
}

namespace parquet
{
namespace arrow
{
    class FileWriter;
}
}

namespace DB
{

class CHColumnToArrowColumn;

class ParquetBlockOutputFormat : public IOutputFormat
{
public:
    ParquetBlockOutputFormat(WriteBuffer & out_, const Block & header_, const FormatSettings & format_settings_);

    String getName() const override { return "ParquetBlockOutputFormat"; }

    String getContentType() const override { return "application/octet-stream"; }

private:
    void consume(Chunk) override;
    void appendToAccumulatedChunk(Chunk chunk);
    void write(Chunk chunk, size_t row_group_size);
    void finalizeImpl() override;
    void resetFormatterImpl() override;

    const FormatSettings format_settings;

    std::unique_ptr<parquet::arrow::FileWriter> file_writer;
    std::unique_ptr<CHColumnToArrowColumn> ch_column_to_arrow_column;

    Chunk accumulated_chunk;
};

}

#endif
