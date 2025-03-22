
#pragma once
#include <Core/Block.h>
#include <Formats/FormatSettings.h>
#include <IO/ReadBufferFromFileBase.h>
#include <Processors/Chunk.h>
#include <Processors/Formats/Impl/Parquet/RowGroupChunkReader.h>
#include <Processors/Formats/Impl/Parquet/SelectiveColumnReader.h>

#include <arrow/io/interfaces.h>
#include <parquet/file_reader.h>
#include <parquet/properties.h>
#include <Common/threadPoolCallbackRunner.h>


namespace DB
{
struct FilterSplitResult;
using FilterSplitResultPtr = std::shared_ptr<FilterSplitResult>;
class SubRowGroupRangeReader
{
public:
    using RowGroupReaderCreator = std::function<std::unique_ptr<RowGroupChunkReader>(size_t, RowGroupPrefetchPtr, RowGroupPrefetchPtr)>;
    SubRowGroupRangeReader(
        const std::vector<Int32> & rowGroupIndices,
        std::vector<RowGroupPrefetchPtr> && row_group_condition_prefetches_,
        std::vector<RowGroupPrefetchPtr> && row_group_prefetches,
        RowGroupReaderCreator && creator);
    DB::Chunk read(size_t rows);

private:
    bool loadRowGroupChunkReaderIfNeeded();

    std::vector<Int32> row_group_indices;
    std::vector<RowGroupPrefetchPtr> row_group_condition_prefetches;
    std::vector<RowGroupPrefetchPtr> row_group_prefetches;
    std::unique_ptr<RowGroupChunkReader> row_group_chunk_reader;
    size_t next_row_group_idx = 0;
    RowGroupReaderCreator row_group_reader_creator;
};

class ParquetReader
{
public:
    friend class RowGroupChunkReader;
    struct Settings
    {
        parquet::ArrowReaderProperties arrow_properties;
        parquet::ReaderProperties reader_properties;
        const FormatSettings & format_settings;
        size_t min_bytes_for_seek = 1024 * 1024;
    };

    ParquetReader(
        Block header_,
        SeekableReadBuffer & file,
        std::shared_ptr<::arrow::io::RandomAccessFile> arrow_file,
        const Settings & settings,
        std::vector<int> row_groups_indices_ = {},
        std::shared_ptr<parquet::FileMetaData> metadata = nullptr,
        std::shared_ptr<ThreadPool> io_pool_ = nullptr);

    Block read() const;
    void setSourceArrowFile(std::shared_ptr<arrow::io::RandomAccessFile> arrow_file_);
    void pushDownFilter(FilterSplitResultPtr filter_split_result);
    std::unique_ptr<RowGroupChunkReader>
    getRowGroupChunkReader(size_t row_group_idx, RowGroupPrefetchPtr conditions_prefetch, RowGroupPrefetchPtr prefetch);
    std::unique_ptr<SubRowGroupRangeReader> getSubRowGroupRangeReader(std::vector<Int32> row_group_indices);
    const parquet::FileMetaData & metaData() const { return *meta_data; }
    const parquet::ReaderProperties & readerProperties() const { return settings.reader_properties; }
    parquet::schema::NodePtr getParquetColumn(const String & column_name);
    bool hasFilter() const { return filter_split_result.operator bool(); }

private:
    void addFilter(const String & column_name, ColumnFilterPtr filter);
    void addExpressionFilter(std::shared_ptr<ExpressionFilter> filter);
    std::unique_ptr<parquet::ParquetFileReader> file_reader;
    std::mutex file_mutex;
    SeekableReadBuffer & file;
    // for read page index
    std::shared_ptr<arrow::io::RandomAccessFile> arrow_file = nullptr;
    Block header;
    std::unique_ptr<SubRowGroupRangeReader> chunk_reader;

    UInt64 max_block_size;
    std::unordered_map<String, ColumnFilterPtr> filters;
    std::vector<int> parquet_col_indices;
    std::vector<int> row_groups_indices;
    size_t next_row_group_idx = 0;
    std::shared_ptr<parquet::FileMetaData> meta_data;
    std::unordered_map<String, parquet::schema::NodePtr> parquet_columns;
    std::vector<std::shared_ptr<ExpressionFilter>> expression_filters;
    std::unordered_set<String> condition_columns;
    std::shared_ptr<ThreadPool> io_pool;
    bool case_insensitive = false;
    FilterSplitResultPtr filter_split_result;
    std::once_flag filter_fallback_checked;
    Settings settings;
};

}
