#include "StringUtils.h"
#include <Poco/StringTokenizer.h>
#include <filesystem>

namespace local_engine
{
PartitionValues StringUtils::parsePartitionTablePath(const std::string & file)
{
    PartitionValues result;
    Poco::StringTokenizer path(file, "/");
    for (const auto & item : path)
    {
        auto position = item.find('=');
        if (position != std::string::npos)
        {
            result.emplace_back(PartitionValue(toLowerCase(item.substr(0,position)), item.substr(position+1)));
        }
    }
    return result;
}

bool StringUtils::isNullPartitionValue(const std::string & value)
{
    return value == "__HIVE_DEFAULT_PARTITION__";
}

std::string StringUtils::toLowerCase(const std::string & value)
{
    std::string res = value;
    for (size_t i = 0; i < value.size(); i++) {
        res[i] = tolower(value[i]);
    }
    return res;
}
}


