#include "ArrowParquetBlockInputFormat.h"

#include <Processors/Formats/Impl/ArrowColumnToCHColumn.h>
#include <arrow/record_batch.h>
#include <Common/Stopwatch.h>
#include <arrow/table.h>
#include <boost/range/irange.hpp>


namespace local_engine
{
ArrowParquetBlockInputFormat::ArrowParquetBlockInputFormat(
    DB::ReadBuffer & in_, const DB::Block & header, const DB::FormatSettings & formatSettings, size_t prefer_block_size_)
    : ParquetBlockInputFormat(in_, header, formatSettings), prefer_block_size(prefer_block_size_)
{
}

void ArrowParquetBlockInputFormat::prepareRecordBatchReader(const arrow::Table & table)
{
    auto row_groups = boost::irange(0, file_reader->num_row_groups());
    auto row_group_vector = std::vector<int>(row_groups.begin(), row_groups.end());
    auto reader = std::make_shared<arrow::TableBatchReader>(table);
    reader->set_chunksize(1024);
    current_record_batch_reader = reader;
}

DB::Chunk ArrowParquetBlockInputFormat::generate()
{
    DB::Chunk res;
    block_missing_values.clear();

    if (!file_reader)
    {
        prepareReader();
        file_reader->set_batch_size(8192);
//        file_reader->set_use_threads(true);
        auto row_group_range = boost::irange(0, file_reader->num_row_groups());
        auto row_group_indices = std::vector(row_group_range.begin(), row_group_range.end());
        auto read_status = file_reader->GetRecordBatchReader(row_group_indices, &current_record_batch_reader);
        if (!read_status.ok())
            throw std::runtime_error{"Error while reading Parquet data: " + read_status.ToString()};
    }

    if (is_stopped)
        return {};


    auto batch = current_record_batch_reader->Next();
    if (*batch)
    {
        auto tmp_table = arrow::Table::FromRecordBatches({*batch});
        Stopwatch watch;
        watch.start();
        arrow_column_to_ch_column->arrowTableToCHChunk(res, *tmp_table);
        convert_time += watch.elapsedNanoseconds();
    }
    else
    {
        current_record_batch_reader.reset();
        file_reader.reset();
        return {};
    }

    /// If defaults_for_omitted_fields is true, calculate the default values from default expression for omitted fields.
    /// Otherwise fill the missing columns with zero values of its type.
    if (format_settings.defaults_for_omitted_fields)
        for (size_t row_idx = 0; row_idx < res.getNumRows(); ++row_idx)
            for (const auto & column_idx : missing_columns)
                block_missing_values.setBit(column_idx, row_idx);
    return res;
}
ArrowParquetBlockInputFormat::~ArrowParquetBlockInputFormat()
{
    std::cerr<<"convert time: " << convert_time / 1000000.0 <<" ms"<<std::endl;
}

}
