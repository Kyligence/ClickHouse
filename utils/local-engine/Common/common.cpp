#include <AggregateFunctions/registerAggregateFunctions.h>
#include <AggregateFunctions/AggregateFunctionFactory.h>
#include <Functions/registerFunctions.h>
#include <AggregateFunctions/AggregateFunctionCombinatorFactory.h>
#include <Functions/FunctionFactory.h>
#include <Interpreters/Context.h>
#include <Interpreters/JIT/CompiledExpressionCache.h>
#include <Parser/SerializedPlanParser.h>
#include <Processors/QueryPlan/Optimizations/QueryPlanOptimizationSettings.h>
#include <Common/Config/ConfigProcessor.h>
#include <Common/Logger.h>
#include <Poco/SimpleFileChannel.h>
#include <Poco/Util/MapConfiguration.h>
#include <jni.h>
#include <filesystem>

namespace DB
{
namespace ErrorCodes
{
extern const int BAD_ARGUMENTS;
}
}

using namespace DB;
namespace fs = std::filesystem;

namespace local_engine
{
extern void registerAggregateFunctionCombinatorPartialMerge(AggregateFunctionCombinatorFactory &);
extern void registerFunctions(FunctionFactory &);
}

#ifdef __cplusplus
extern "C" {
#endif

void registerAllFunctions()
{
    registerFunctions();
    registerAggregateFunctions();

    /// register aggregate function combinators from local_engine
    {
        auto & factory = AggregateFunctionCombinatorFactory::instance();
        local_engine::registerAggregateFunctionCombinatorPartialMerge(factory);
    }

    /// register ordinary functions from local_engine
    auto & factory = FunctionFactory::instance();
    local_engine::registerFunctions(factory);

}

static const String CH_BACKEND_CONF_PREFIX = "spark.gluten.sql.columnar.backend.ch";
static const String CH_RUNTIME_CONF = "runtime_conf";
static const String CH_RUNTIME_CONF_PREFIX = CH_BACKEND_CONF_PREFIX + "." + CH_RUNTIME_CONF;
static const String CH_RUNTIME_CONF_FILE = CH_RUNTIME_CONF_PREFIX + ".conf_file";
static const String GLUTEN_TIMEZONE_KEY = "spark.gluten.timezone";
static const String LIBHDFS3_CONF_KEY = "hdfs.libhdfs3_conf";

/// For using gluten, we recommend to pass clickhouse runtime configure by using --files in spark-submit.
/// And set the parameter CH_BACKEND_CONF_PREFIX.CH_RUNTIME_CONF.conf_file
/// You can also set a specified configuration with prefix CH_BACKEND_CONF_PREFIX.CH_RUNTIME_CONF, and this
/// will overwrite the configuration from CH_BACKEND_CONF_PREFIX.CH_RUNTIME_CONF.conf_file .
static std::map<std::string, std::string> getBackendConf(const std::string & plan)
{
    std::map<std::string, std::string> ch_backend_conf;

    /// parse backend configs from plan extensions
    do
    {
        auto plan_ptr = std::make_unique<substrait::Plan>();
        auto success = plan_ptr->ParseFromString(plan);
        if (!success)
            break;

        if (!plan_ptr->has_advanced_extensions() || !plan_ptr->advanced_extensions().has_enhancement())
            break;
        const auto & enhancement = plan_ptr->advanced_extensions().enhancement();

        if (!enhancement.Is<substrait::Expression>())
            break;

        substrait::Expression expression;
        if (!enhancement.UnpackTo(&expression) || !expression.has_literal() || !expression.literal().has_map())
            break;

        const auto & key_values = expression.literal().map().key_values();
        for (const auto & key_value : key_values)
        {
             if (!key_value.has_key() || !key_value.has_value())
                continue;

            const auto & key = key_value.key();
            const auto & value = key_value.value();
            if (!key.has_string() || !value.has_string())
                continue;

            if (!key.string().starts_with(CH_BACKEND_CONF_PREFIX) && key.string() != std::string(GLUTEN_TIMEZONE_KEY))
                continue;

            ch_backend_conf[key.string()] = value.string();
        }
    } while (false);

    if (!ch_backend_conf.count(CH_RUNTIME_CONF_FILE))
    {
        /// Try to get config path from environment variable
        const char * config_path = std::getenv("CLICKHOUSE_BACKEND_CONFIG"); /// NOLINT
        if (config_path)
        {
            ch_backend_conf[CH_RUNTIME_CONF_FILE] = config_path;
        }
    }
    return ch_backend_conf;
}

void initCHRuntimeConfig(const std::map<std::string, std::string> & conf)
{}

void init(const std::string & plan)
{
    static std::once_flag init_flag;
    std::call_once(
        init_flag,
        [&plan]()
        {
            /// Load Config
            std::map<std::string, std::string> ch_backend_conf;
            if (!local_engine::SerializedPlanParser::config)
            {
                ch_backend_conf = getBackendConf(plan);

                /// If we have a configuration file, use it at first
                if (ch_backend_conf.count(CH_RUNTIME_CONF_FILE))
                {
                    if (fs::exists(CH_RUNTIME_CONF_FILE) && fs::is_regular_file(CH_RUNTIME_CONF_FILE))
                    {
                        DB::ConfigProcessor config_processor(CH_RUNTIME_CONF_FILE, false, true);
                        config_processor.setConfigPath(fs::path(CH_RUNTIME_CONF_FILE).parent_path());
                        auto loaded_config = config_processor.loadConfig(false);
                        local_engine::SerializedPlanParser::config = loaded_config.configuration;
                    }
                    else
                    {
                        throw DB::Exception(DB::ErrorCodes::BAD_ARGUMENTS, "{} is not a valid configure file.", CH_RUNTIME_CONF_FILE);
                    }
                }
                else
                {
                    local_engine::SerializedPlanParser::config = Poco::AutoPtr(new Poco::Util::MapConfiguration());
                }

                /// Update specified settings
                for (const auto & kv : ch_backend_conf)
                {
                    if (kv.first.starts_with(CH_RUNTIME_CONF_PREFIX) && kv.first != CH_RUNTIME_CONF_FILE)
                    {
                        /// Notice, you can set a conf by setString(), but get it by getInt()
                        local_engine::SerializedPlanParser::config->setString(
                            kv.first.substr(CH_RUNTIME_CONF_PREFIX.size() + 1), kv.second);
                    }
                    else if (kv.first == std::string(GLUTEN_TIMEZONE_KEY))
                    {
                        local_engine::SerializedPlanParser::config->setString(kv.first, kv.second);
                    }
                }
            }

            /// Initialize Loggers
            auto & config = local_engine::SerializedPlanParser::config;
            auto level = config->getString("logger.level", "error");
            if (config->has("logger.log"))
            {
                local_engine::Logger::initFileLogger(*config, "ClickHouseBackend");
            }
            else
            {
                local_engine::Logger::initConsoleLogger(level);
            }
            auto * logger = &Poco::Logger::get("ClickHouseBackend");
            LOG_INFO(logger, "Init logger.");

            if (config->has(GLUTEN_TIMEZONE_KEY))
            {
                const std::string config_timezone = config->getString(GLUTEN_TIMEZONE_KEY);
                if (0 != setenv("TZ", config_timezone.data(), 1)) /// NOLINT
                    throw Poco::Exception("Cannot setenv TZ variable");

                tzset();
                DateLUT::setDefaultTimezone(config_timezone);
                LOG_INFO(&Poco::Logger::get("ClickHouseBackend"), "Init timezone {}.", config_timezone);
            }

            /// Initialize settings
            auto settings = Settings();
            std::string settings_path = "local_engine.settings";
            Poco::Util::AbstractConfiguration::Keys config_keys;
            config->keys(settings_path, config_keys);
            for (const std::string & key : config_keys)
            {
                settings.set(key, config->getString(settings_path + "." + key));
            }
            settings.set("join_use_nulls", true);
            LOG_INFO(logger, "Init settings.");

            /// Initialize global context
            if (!local_engine::SerializedPlanParser::global_context)
            {
                local_engine::SerializedPlanParser::shared_context = SharedContextHolder(Context::createShared());
                local_engine::SerializedPlanParser::global_context
                    = Context::createGlobal(local_engine::SerializedPlanParser::shared_context.get());
                local_engine::SerializedPlanParser::global_context->makeGlobalContext();
                local_engine::SerializedPlanParser::global_context->setConfig(config);
                local_engine::SerializedPlanParser::global_context->setSettings(settings);
                local_engine::SerializedPlanParser::global_context->setTemporaryStoragePath("/tmp/libch", 0);
                auto path = config->getString("path", "/");
                local_engine::SerializedPlanParser::global_context->setPath(path);
                LOG_INFO(logger, "Init global context.");
            }

            registerAllFunctions();
            LOG_INFO(logger, "Register all functions.");

#if USE_EMBEDDED_COMPILER
            /// 128 MB
            constexpr size_t compiled_expression_cache_size_default = 1024 * 1024 * 128;
            size_t compiled_expression_cache_size = config->getUInt64("compiled_expression_cache_size", compiled_expression_cache_size_default);

            constexpr size_t compiled_expression_cache_elements_size_default = 10000;
            size_t compiled_expression_cache_elements_size = config->getUInt64("compiled_expression_cache_elements_size", compiled_expression_cache_elements_size_default);

            CompiledExpressionCacheFactory::instance().init(compiled_expression_cache_size, compiled_expression_cache_elements_size);
            LOG_INFO(logger, "Init compiled expressions cache factory.");
#endif

            /// Set environment variable LIBHDFS3_CONF if possible
            std::string libhdfs3_conf = config->getString(LIBHDFS3_CONF_KEY, "");
            if (libhdfs3_conf.empty())
                LOG_WARNING(logger, "Can't find {} in config file, it may cause error in Hadoop HA mode", LIBHDFS3_CONF_KEY);
            else
                setenv("LIBHDFS3_CONF", libhdfs3_conf.c_str(), true); /// NOLINT
        }
    );
}

char * createExecutor(const std::string & plan_string)
{
    auto context = Context::createCopy(local_engine::SerializedPlanParser::global_context);
    local_engine::SerializedPlanParser parser(context);
    auto query_plan = parser.parse(plan_string);
    local_engine::LocalExecutor * executor = new local_engine::LocalExecutor(parser.query_context);
    executor->execute(std::move(query_plan));
    return reinterpret_cast<char* >(executor);
}

bool executorHasNext(char * executor_address)
{
    local_engine::LocalExecutor * executor = reinterpret_cast<local_engine::LocalExecutor *>(executor_address);
    return executor->hasNext();
}

#ifdef __cplusplus
}
#endif
