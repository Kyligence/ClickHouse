#include <iostream>
#include <jni/jni_error.h>
#include <jni/ReservationListenerWrapper.h>
#include <Shuffle/ShuffleReader.h>
#include <Shuffle/NativeSplitter.h>
#include <Shuffle/WriteBufferFromJavaOutputStream.h>
#include <Storages/SourceFromJavaIter.h>
#include <Parser/SparkRowToCHColumn.h>
#include <Common/CHUtil.h>
#include "JNIUtils.h"

namespace local_engine
{

JNIEnv * JNIUtils::getENV(int * attach)
{
    if (vm == nullptr)
        return nullptr;

    *attach = 0;
    JNIEnv * jni_env = nullptr;

    int status = vm->GetEnv(reinterpret_cast<void **>(&jni_env), JNI_VERSION_1_8);

    if (status == JNI_EDETACHED || jni_env == nullptr)
    {
        status = vm->AttachCurrentThread(reinterpret_cast<void **>(&jni_env), nullptr);
        if (status < 0)
        {
            jni_env = nullptr;
        }
        else
        {
            *attach = 1;
        }
    }
    return jni_env;
}

void JNIUtils::detachCurrentThread()
{
    vm->DetachCurrentThread();
}

jint JNIUtils::init(JavaVM * vm_)
{
    if (inited)
        return JNI_VERSION_1_8;

    JNIEnv * env;
    if (vm_->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_8) != JNI_OK)
        return JNI_ERR;

    JniErrorsGlobalState::instance().initialize(env);

    spark_row_info_class = CreateGlobalClassReference(env, "Lio/glutenproject/row/SparkRowInfo;");
    std::cout << "onload spark_row_info_class:" << spark_row_info_class << std::endl;
    spark_row_info_constructor = env->GetMethodID(spark_row_info_class, "<init>", "([J[JJJJ)V");
    std::cout << "branch3" << spark_row_info_class << std::endl;

    split_result_class = CreateGlobalClassReference(env, "Lio/glutenproject/vectorized/SplitResult;");
    split_result_constructor = GetMethodID(env, split_result_class, "<init>", "(JJJJJJ[J[J)V");
    std::cout << "branch4" << spark_row_info_class << std::endl;

    ShuffleReader::input_stream_class = CreateGlobalClassReference(env, "Lio/glutenproject/vectorized/ShuffleInputStream;");
    NativeSplitter::iterator_class = CreateGlobalClassReference(env, "Lio/glutenproject/vectorized/IteratorWrapper;");
    WriteBufferFromJavaOutputStream::output_stream_class = CreateGlobalClassReference(env, "Ljava/io/OutputStream;");
    SourceFromJavaIter::serialized_record_batch_iterator_class
        = CreateGlobalClassReference(env, "Lio/glutenproject/execution/ColumnarNativeIterator;");

    std::cout << "branch5" << spark_row_info_class << std::endl;

    ShuffleReader::input_stream_read = env->GetMethodID(ShuffleReader::input_stream_class, "read", "(JJ)J");

    NativeSplitter::iterator_has_next = GetMethodID(env, NativeSplitter::iterator_class, "hasNext", "()Z");
    NativeSplitter::iterator_next = GetMethodID(env, NativeSplitter::iterator_class, "next", "()J");
    std::cout << "branch6" << spark_row_info_class << std::endl;

    WriteBufferFromJavaOutputStream::output_stream_write
        = GetMethodID(env, WriteBufferFromJavaOutputStream::output_stream_class, "write", "([BII)V");
    WriteBufferFromJavaOutputStream::output_stream_flush
        = GetMethodID(env, WriteBufferFromJavaOutputStream::output_stream_class, "flush", "()V");
    std::cout << "branch7" << spark_row_info_class << std::endl;

    SourceFromJavaIter::serialized_record_batch_iterator_hasNext
        = GetMethodID(env, SourceFromJavaIter::serialized_record_batch_iterator_class, "hasNext", "()Z");
    SourceFromJavaIter::serialized_record_batch_iterator_next
        = GetMethodID(env, SourceFromJavaIter::serialized_record_batch_iterator_class, "next", "()[B");
    std::cout << "branch8" << spark_row_info_class << std::endl;

    SparkRowToCHColumn::spark_row_interator_class
        = CreateGlobalClassReference(env, "Lio/glutenproject/execution/SparkRowIterator;");
    SparkRowToCHColumn::spark_row_interator_hasNext
        = GetMethodID(env, SparkRowToCHColumn::spark_row_interator_class, "hasNext", "()Z");
    SparkRowToCHColumn::spark_row_interator_next
        = GetMethodID(env, SparkRowToCHColumn::spark_row_interator_class, "next", "()[B");
    SparkRowToCHColumn::spark_row_iterator_nextBatch
        = GetMethodID(env, SparkRowToCHColumn::spark_row_interator_class, "nextBatch", "()Ljava/nio/ByteBuffer;");
    std::cout << "branch9" << spark_row_info_class << std::endl;

    ReservationListenerWrapper::reservation_listener_class
        = CreateGlobalClassReference(env, "Lio/glutenproject/memory/alloc/ReservationListener;");
    ReservationListenerWrapper::reservation_listener_reserve
        = GetMethodID(env, ReservationListenerWrapper::reservation_listener_class, "reserve", "(J)J");
    ReservationListenerWrapper::reservation_listener_reserve_or_throw
        = GetMethodID(env, ReservationListenerWrapper::reservation_listener_class, "reserveOrThrow", "(J)V");
    ReservationListenerWrapper::reservation_listener_unreserve
        = GetMethodID(env, ReservationListenerWrapper::reservation_listener_class, "unreserve", "(J)J");

    std::cout << "branch10" << spark_row_info_class << std::endl;
    vm = vm_;
    inited = true;
    std::cout << "branch11" << spark_row_info_class << std::endl;
    return JNI_VERSION_1_8;
}

void JNIUtils::onExit()
{
    JNIEnv * env;
    vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_8);
    JniErrorsGlobalState::instance().destroy(env);
    env->DeleteGlobalRef(spark_row_info_class);
    env->DeleteGlobalRef(split_result_class);
    env->DeleteGlobalRef(ShuffleReader::input_stream_class);
    env->DeleteGlobalRef(NativeSplitter::iterator_class);
    env->DeleteGlobalRef(WriteBufferFromJavaOutputStream::output_stream_class);
    env->DeleteGlobalRef(SourceFromJavaIter::serialized_record_batch_iterator_class);
    env->DeleteGlobalRef(SparkRowToCHColumn::spark_row_interator_class);
    env->DeleteGlobalRef(ReservationListenerWrapper::reservation_listener_class);
}

void JNIUtils::registerOnExit()
{
    assert(inited);

    /// No need to worry about concurrency issue because gluten gurantees
    /// that it is invoked serially.
    if (!on_exit_registered)
    {
        std::atexit(JNIUtils::onExit);
        on_exit_registered = true;
    }
}

void JNIUtils::finalize()
{
    registerOnExit();
}

}
