#include "ColumnFilterHelper.h"
#include <Processors/Formats/Impl/Parquet/ParquetReader.h>
#include <Poco/String.h>

namespace DB
{

FilterSplitResultPtr ColumnFilterHelper::splitFilterForPushDown(const ActionsDAG & filter_expression, bool case_insensitive)
{
    FilterSplitResultPtr split_result = std::make_shared<FilterSplitResult>();
    split_result->filter_expression = filter_expression.clone();
    if (split_result->filter_expression.getOutputs().empty())
        return {};
    const auto * filter_node = split_result->filter_expression.getOutputs().front();
    auto conditions = ActionsDAG::extractConjunctionAtoms(filter_node);
    std::vector<ColumnFilterPtr> filters;
    ActionsDAG::NodeRawConstPtrs unsupported_conditions;
    const auto & factories = ColumnFilterFactory::allFactories();
    for (const auto * condition : conditions)
    {
        // convert expr to column filter, and try to merge with existing filter on same column
        if (std::none_of(
                factories.begin(),
                factories.end(),
                [&](ColumnFilterFactoryPtr factory)
                {
                    if (!factory->validate(*condition))
                        return false;
                    auto named_filter = factory->create(*condition);
                    auto col_name = named_filter.first;
                    if (case_insensitive)
                        col_name = Poco::toLower(col_name);
                    if (!split_result->filters.contains(col_name))
                        split_result->filters.emplace(col_name, named_filter.second);
                    else
                    {
                        auto merged = split_result->filters[col_name]->merge(named_filter.second.get());
                        if (merged)
                            split_result->filters[col_name] = merged;
                        else
                            // doesn't support merge, use common expression push down
                            return false;
                    }
                    split_result->fallback_filters[col_name].push_back(condition);
                    return true;
                }))
            unsupported_conditions.push_back(condition);
    }
    auto actions_dag = ActionsDAG::buildFilterActionsDAG(unsupported_conditions);
    if (actions_dag.has_value())
    {
        split_result->expression_filters.emplace_back(std::make_shared<ExpressionFilter>(std::move(actions_dag.value())));
    }
    return split_result;
}

void pushFilterToParquetReader(const ActionsDAG & filter_expression, ParquetReader & reader)
{
    if (filter_expression.getOutputs().empty())
        return;
    auto split_result = ColumnFilterHelper::splitFilterForPushDown(filter_expression);
    reader.pushDownFilter(split_result);
}
}
