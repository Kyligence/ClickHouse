#pragma once
#include <jni.h>

namespace local_engine
{
class JNIUtils
{
public:
    inline static JavaVM * vm = nullptr;

    inline static jclass spark_row_info_class;
    inline static jmethodID spark_row_info_constructor;

    inline static jclass split_result_class;
    inline static jmethodID split_result_constructor;

    /// Make sure JNI related initialization is executed only once when first loading libch.so
    inline static bool inited = false;

    /// Make sure JNI related release is executed only once before process exit.
    inline static bool on_exit_registered = false;

    static JNIEnv * getENV(int * attach);

    static void detachCurrentThread();

    static jint init(JavaVM * vm_);
    static void finalize();

private:
    static void onExit();
    static void registerOnExit();
};

#define GET_JNIENV(env) \
    int attached; \
    JNIEnv * (env) = JNIUtils::getENV(&attached);

#define CLEAN_JNIENV \
    if (attached) [[unlikely]]\
    { \
        JNIUtils::detachCurrentThread(); \
    }

}
