#include <Processors/Transforms/MergeSortingTransform.h>
#include <Processors/IAccumulatingTransform.h>
#include <Processors/Merges/MergingSortedTransform.h>
#include <Common/MemoryTrackerUtils.h>
#include <Common/ProfileEvents.h>
#include <Common/formatReadable.h>
#include <Common/logger_useful.h>
#include <IO/WriteBufferFromFile.h>
#include <IO/ReadBufferFromFile.h>
#include <Compression/CompressedReadBuffer.h>
#include <Compression/CompressedWriteBuffer.h>
#include <Formats/NativeReader.h>
#include <Formats/NativeWriter.h>
#include <Disks/IVolume.h>


namespace ProfileEvents
{
    extern const Event ExternalSortWritePart;
    extern const Event ExternalSortMerge;
    extern const Event ExternalSortCompressedBytes;
    extern const Event ExternalSortUncompressedBytes;
    extern const Event ExternalProcessingCompressedBytesTotal;
    extern const Event ExternalProcessingUncompressedBytesTotal;
}


namespace DB
{

class TemporaryFileStreamSource : public ISource
{
public:
    TemporaryFileStreamSource(const Block& header, TemporaryBlockStreamReaderHolder&& stream_)
        : ISource(header),
          stream(std::move(stream_))
    {
    }

    String getName() const override { return "TemporaryFileStreamSource"; }

protected:
    Chunk generate() override
    {
        Block block = stream->read();
        if (!block)
            return {};

        UInt64 num_rows = block.rows();
        return Chunk(block.getColumns(), num_rows);
    }
private:
    TemporaryBlockStreamReaderHolder stream;
};

namespace ErrorCodes
{
    extern const int LOGICAL_ERROR;
}

class BufferingToFileTransform : public IAccumulatingTransform
{
public:
    BufferingToFileTransform(const Block & header, TemporaryBlockStreamHolder tmp_stream_, LoggerPtr log_)
        : IAccumulatingTransform(header, header)
        , tmp_stream(std::move(tmp_stream_))
        , log(log_)
    {
        LOG_INFO(log, "Sorting and writing part of data into temporary file {}", tmp_stream.getHolder()->describeFilePath());
        ProfileEvents::increment(ProfileEvents::ExternalSortWritePart);
    }

    String getName() const override { return "BufferingToFileTransform"; }

    void consume(Chunk chunk) override
    {
        Block block = getInputPort().getHeader().cloneWithColumns(chunk.detachColumns());
        tmp_stream->write(block);
    }

    Chunk generate() override
    {
        if (!tmp_read_stream)
        {
            auto stat = tmp_stream.finishWriting();
            tmp_read_stream = tmp_stream.getReadStream();

            ProfileEvents::increment(ProfileEvents::ExternalProcessingCompressedBytesTotal, stat.compressed_size);
            ProfileEvents::increment(ProfileEvents::ExternalProcessingUncompressedBytesTotal, stat.uncompressed_size);
            ProfileEvents::increment(ProfileEvents::ExternalSortCompressedBytes, stat.compressed_size);
            ProfileEvents::increment(ProfileEvents::ExternalSortUncompressedBytes, stat.uncompressed_size);

            LOG_INFO(log, "Done writing part of data into temporary file {}, compressed {}, uncompressed {} ",
                tmp_stream.getHolder()->describeFilePath(),
                ReadableSize(static_cast<double>(stat.compressed_size)), ReadableSize(static_cast<double>(stat.uncompressed_size)));
        }

        Block block = tmp_read_stream.value()->read();
        if (!block)
            return {};

        UInt64 num_rows = block.rows();
        return Chunk(block.getColumns(), num_rows);
    }

private:
    TemporaryBlockStreamHolder tmp_stream;
    std::optional<TemporaryBlockStreamReaderHolder> tmp_read_stream;

    LoggerPtr log;
};

MergeSortingTransform::MergeSortingTransform(
    const Block & header,
    const SortDescription & description_,
    size_t max_merged_block_size_,
    size_t max_block_bytes_,
    UInt64 limit_,
    bool increase_sort_description_compile_attempts,
    size_t max_bytes_before_remerge_,
    double remerge_lowered_memory_bytes_ratio_,
    size_t min_external_sort_block_bytes_,
    size_t max_bytes_before_external_sort_,
    TemporaryDataOnDiskScopePtr tmp_data_,
    size_t min_free_disk_space_,
    std::function<bool()> worth_external_sort_)
    : SortingTransform(header, description_, max_merged_block_size_, limit_, increase_sort_description_compile_attempts)
    , max_bytes_before_remerge(max_bytes_before_remerge_)
    , remerge_lowered_memory_bytes_ratio(remerge_lowered_memory_bytes_ratio_)
    , min_external_sort_block_bytes(min_external_sort_block_bytes_)
    , max_bytes_before_external_sort(max_bytes_before_external_sort_)
    , tmp_data(std::move(tmp_data_))
    , min_free_disk_space(min_free_disk_space_)
    , max_block_bytes(max_block_bytes_)
    , worth_external_sort(std::move(worth_external_sort_))
{
}

Processors MergeSortingTransform::expandPipeline()
{
    if (processors.size() > 1)
    {
        /// Add external_merging_sorted.
        inputs.emplace_back(header_without_constants, this);
        connect(external_merging_sorted->getOutputs().front(), inputs.back());
    }

    auto & buffer = processors.front();

    static_cast<MergingSortedTransform &>(*external_merging_sorted).addInput();
    connect(buffer->getOutputs().back(), external_merging_sorted->getInputs().back());

    if (!buffer->getInputs().empty())
    {
        /// Serialize
        outputs.emplace_back(header_without_constants, this);
        connect(getOutputs().back(), buffer->getInputs().back());
        /// Hack. Say buffer that we need data from port (otherwise it will return PortFull).
        external_merging_sorted->getInputs().back().setNeeded();
    }
    else
        /// Generate
        static_cast<MergingSortedTransform &>(*external_merging_sorted).setHaveAllInputs();

    return std::move(processors);
}

void MergeSortingTransform::consume(Chunk chunk)
{
    /** Algorithm:
      * - read to memory blocks from source stream;
      * - if too many of them and if external sorting is enabled,
      *   - merge all blocks to sorted stream and write it to temporary file;
      * - at the end, merge all sorted streams from temporary files and also from rest of blocks in memory.
      */

    /// If there were only const columns in sort description, then there is no need to sort.
    /// Return the chunk as is.
    if (description.empty())
    {
        generated_chunk = std::move(chunk);
        return;
    }

    removeConstColumns(chunk);

    sum_rows_in_blocks += chunk.getNumRows();
    sum_bytes_in_blocks += chunk.allocatedBytes();
    chunks.push_back(std::move(chunk));

    /** If significant amount of data was accumulated, perform preliminary merging step.
      */
    if (chunks.size() > 1
        && limit
        && limit * 2 < sum_rows_in_blocks   /// 2 is just a guess.
        && remerge_is_useful
        && max_bytes_before_remerge
        && sum_bytes_in_blocks > max_bytes_before_remerge)
    {
        remerge();
    }

    /** If too many of them and if external sorting is enabled,
      *  will merge blocks that we have in memory at this moment and write merged stream to temporary (compressed) file.
      * NOTE. It's possible to check free space in filesystem.
      */
    if ((sum_bytes_in_blocks > min_external_sort_block_bytes && max_bytes_before_external_sort)||
        (worth_external_sort && worth_external_sort() && sum_bytes_in_blocks > max_bytes_before_external_sort * 0.3))
    {
        Int64 query_memory = getCurrentQueryMemoryUsage();
        if (query_memory > static_cast<Int64>(max_bytes_before_external_sort))
        {
            if (!tmp_data)
                throw Exception(ErrorCodes::LOGICAL_ERROR, "TemporaryDataOnDisk is not set for MergeSortingTransform");
            temporary_files_num++;

            LOG_TRACE(log, "Will dump sorting block to disk ({} > {})", formatReadableSizeWithBinarySuffix(query_memory), formatReadableSizeWithBinarySuffix(max_bytes_before_external_sort));

            /// If there's less free disk space than reserve_size, an exception will be thrown
            size_t reserve_size = sum_bytes_in_blocks + min_free_disk_space;
            TemporaryBlockStreamHolder tmp_stream(header_without_constants, tmp_data.get(), reserve_size);
            merge_sorter = std::make_unique<MergeSorter>(header_without_constants, std::move(chunks), description, getAdaptiveMaxMergeSize(), limit);
            auto current_processor = std::make_shared<BufferingToFileTransform>(header_without_constants, std::move(tmp_stream), log);

            processors.emplace_back(current_processor);

            if (!external_merging_sorted)
            {
                bool have_all_inputs = false;
                bool use_average_block_sizes = false;
                bool apply_virtual_row = false;

                external_merging_sorted = std::make_shared<MergingSortedTransform>(
                        header_without_constants,
                        0,
                        description,
                        getAdaptiveMaxMergeSize(),
                        max_block_bytes,
                        SortingQueueStrategy::Batch,
                        limit,
                        /*always_read_till_end_=*/ false,
                        nullptr,
                        use_average_block_sizes,
                        apply_virtual_row,
                        have_all_inputs);

                processors.emplace_back(external_merging_sorted);
            }

            stage = Stage::Serialize;
            sum_bytes_in_blocks = 0;
            sum_rows_in_blocks = 0;
        }
    }
}

void MergeSortingTransform::serialize()
{
    current_chunk = merge_sorter->read();
    if (!current_chunk)
        merge_sorter.reset();
}

void logTmpWriteStat(LoggerPtr log, const String& path, const TemporaryDataBuffer::Stat& stat)
{
    ProfileEvents::increment(ProfileEvents::ExternalProcessingCompressedBytesTotal, stat.compressed_size);
    ProfileEvents::increment(ProfileEvents::ExternalProcessingUncompressedBytesTotal, stat.uncompressed_size);
    ProfileEvents::increment(ProfileEvents::ExternalSortCompressedBytes, stat.compressed_size);
    ProfileEvents::increment(ProfileEvents::ExternalSortUncompressedBytes, stat.uncompressed_size);

    LOG_INFO(log, "Done writing part of data into temporary file {}, compressed {}, uncompressed {} ",
        path,
        ReadableSize(static_cast<double>(stat.compressed_size)), ReadableSize(static_cast<double>(stat.uncompressed_size)));
}

void MergeSortingTransform::generate()
{
    if (!generated_prefix)
    {
        if (temporary_files_num == 0)
        {
            merge_sorter = std::make_unique<MergeSorter>(header_without_constants, std::move(chunks), description, getAdaptiveMaxMergeSize(), limit);
        }
        else
        {
            ProfileEvents::increment(ProfileEvents::ExternalSortMerge);
            LOG_INFO(log, "There are {} temporary sorted parts to merge", temporary_files_num);

            size_t reserve_size = sum_bytes_in_blocks + min_free_disk_space;
            TemporaryBlockStreamHolder tmp_stream(header_without_constants, tmp_data.get(), reserve_size);
            auto merge_sorter = MergeSorter(header_without_constants, std::move(chunks), description, getAdaptiveMaxMergeSize(), limit);
            while(auto chunk = merge_sorter.read())
                tmp_stream->write(header_without_constants.cloneWithColumns(chunk.detachColumns()));
            auto stat = tmp_stream.finishWriting();
            logTmpWriteStat(log, tmp_stream.getHolder()->describeFilePath(), stat);
            auto source = std::make_shared<TemporaryFileStreamSource>(header_without_constants, tmp_stream.getReadStream());
            processors.emplace_back(source);
        }

        generated_prefix = true;
    }

    if (merge_sorter && !temporary_file_reader)
    {
        if (worth_external_sort && worth_external_sort())
        {
            TemporaryBlockStreamHolder temporary_file_stream(header_without_constants, tmp_data.get());
            while(auto chunk = merge_sorter->read())
                temporary_file_stream->write(header_without_constants.cloneWithColumns(chunk.detachColumns()));
            auto stat = temporary_file_stream.finishWriting();
            logTmpWriteStat(log, temporary_file_stream.getHolder()->describeFilePath(), stat);
            temporary_file_reader = temporary_file_stream.getReadStream();
        }
        else
        {
            generated_chunk = merge_sorter->read();
            if (!generated_chunk)
                merge_sorter.reset();
            else
                enrichChunkWithConstants(generated_chunk);
        }
    }
    if (temporary_file_reader)
    {
        auto block = temporary_file_reader.value()->read();
        generated_chunk = Chunk(block.getColumns(), block.rows());
        if (!generated_chunk)
        {
            merge_sorter.reset();
            temporary_file_reader.reset();
        }
        else
            enrichChunkWithConstants(generated_chunk);
    }
}

void MergeSortingTransform::remerge()
{
    LOG_DEBUG(log, "Re-merging intermediate ORDER BY data ({} blocks with {} rows) to save memory consumption", chunks.size(), sum_rows_in_blocks);

    /// NOTE Maybe concat all blocks and partial sort will be faster than merge?
    MergeSorter remerge_sorter(header_without_constants, std::move(chunks), description, max_merged_block_size, limit);

    Chunks new_chunks;
    size_t new_sum_rows_in_blocks = 0;
    size_t new_sum_bytes_in_blocks = 0;

    while (auto chunk = remerge_sorter.read())
    {
        new_sum_rows_in_blocks += chunk.getNumRows();
        new_sum_bytes_in_blocks += chunk.allocatedBytes();
        new_chunks.emplace_back(std::move(chunk));
    }

    LOG_DEBUG(log, "Memory usage is lowered from {} to {}", ReadableSize(sum_bytes_in_blocks), ReadableSize(new_sum_bytes_in_blocks));

    /// If the memory consumption was not lowered enough - we will not perform remerge anymore.
    if (remerge_lowered_memory_bytes_ratio > 0.0 && (new_sum_bytes_in_blocks * remerge_lowered_memory_bytes_ratio > sum_bytes_in_blocks))
    {
        remerge_is_useful = false;
        LOG_DEBUG(log, "Re-merging is not useful (memory usage was not lowered by remerge_sort_lowered_memory_bytes_ratio={})", remerge_lowered_memory_bytes_ratio);
    }

    chunks = std::move(new_chunks);
    sum_rows_in_blocks = new_sum_rows_in_blocks;
    sum_bytes_in_blocks = new_sum_bytes_in_blocks;
}

size_t MergeSortingTransform::getAdaptiveMaxMergeSize() const
{
    size_t max_merged_block_size = this->max_merged_block_size;
    if (max_block_bytes > 0 && sum_rows_in_blocks > 0 && sum_bytes_in_blocks > 0)
    {
        auto avg_row_bytes = sum_bytes_in_blocks / sum_rows_in_blocks;
        /// max_merged_block_size >= 128
        max_merged_block_size = std::max(std::min(max_merged_block_size, max_block_bytes / avg_row_bytes), 128UL);
    }
    return max_merged_block_size;
}
}
