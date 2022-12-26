#pragma once
#include <unordered_map>
#include <Core/Field.h>
#include <Core/SortDescription.h>
#include <Interpreters/WindowDescription.h>
#include <Parser/RelParser.h>
#include <base/logger_useful.h>
#include <Poco/Logger.h>
namespace local_engine
{
class WindowRelParser : public RelParser
{
public:
    explicit WindowRelParser(SerializedPlanParser * plan_paser_);
    ~WindowRelParser() override = default;
    DB::QueryPlanPtr parse(DB::QueryPlanPtr current_plan_, const substrait::Rel & rel, std::list<const substrait::Rel *> & rel_stack_) override;

private:
    DB::QueryPlanPtr current_plan;
    // std::list<const substrait::Rel *> * rel_stack;
    Poco::Logger * logger = &Poco::Logger::get("WindowRelParser");

    /// There will be window descrptions generated for different window frame type;
    std::unordered_map<DB::String, WindowDescription> parseWindowDescriptions(const substrait::WindowRel & win_rel);
    DB::WindowFrame parseWindowFrame(const substrait::Expression::WindowFunction & window_function);
    DB::WindowFrame::FrameType parseWindowFrameType(const substrait::Expression::WindowFunction & window_function);
    static void parseBoundType(
        const substrait::Expression::WindowFunction::Bound & bound,
        bool is_begin_or_end,
        DB::WindowFrame::BoundaryType & bound_type,
        Field & offset,
        bool & preceding);
    DB::SortDescription parsePartitionBy(const google::protobuf::RepeatedPtrField<substrait::Expression> & expressions);
    DB::WindowFunctionDescription parseWindowFunctionDescription(const substrait::WindowRel & win_rel, const substrait::Expression::WindowFunction & window_function);

    String getWindowName(const substrait::WindowRel & win_rel, const substrait::Expression::WindowFunction & window_function);
    static String getWindowFunctionColumnName(const substrait::WindowRel & win_rel);
};


}
