#ifndef GENAI_BRIDGE_H
#define GENAI_BRIDGE_H

#include <stdint.h>
#include <jni.h>
#include <android/log.h>
#include <string>
#include <vector>
#include <map>
#include <mutex>

// Forward declarations for GGML types
struct ggml_context;
struct ggml_tensor;

// LLM Context structure to hold model and its state
class LlmContext {
private:
    ggml_context* ctx;
    void* model;  // This would be a pointer to your model structure
    std::mutex mtx;

public:
    LlmContext(const std::string& model_path);
    ~LlmContext();

    std::string generate(const std::string& prompt, int max_tokens, double temperature);
};

// JNI function declarations
extern "C" {
    JNIEXPORT void JNICALL Java_com_genai_flutter_GenaiFlutterPlugin_nativeInitialize(
        JNIEnv* env, jobject thiz);

    JNIEXPORT jlong JNICALL Java_com_genai_flutter_GenaiFlutterPlugin_nativeLoadModel(
        JNIEnv* env, jobject thiz, jstring model_path);

    JNIEXPORT jlong JNICALL Java_com_genai_flutter_GenaiFlutterPlugin_nativeLoadEmbeddingModel(
        JNIEnv* env, jobject thiz, jstring model_path);

    JNIEXPORT jstring JNICALL Java_com_genai_flutter_GenaiFlutterPlugin_nativeGenerate(
        JNIEnv* env, jobject thiz, jlong context_ptr, jstring prompt, jint max_tokens, jdouble temperature);

    JNIEXPORT jboolean JNICALL Java_com_genai_flutter_GenaiFlutterPlugin_nativeCreateVectorDatabase(
        JNIEnv* env, jobject thiz, jstring db_name, jint embedding_dimension);

    JNIEXPORT jboolean JNICALL Java_com_genai_flutter_GenaiFlutterPlugin_nativeAddToKnowledgeBase(
        JNIEnv* env, jobject thiz, jlong emb_model_ptr, jstring content, jstring document_id, jstring db_name);

    JNIEXPORT jstring JNICALL Java_com_genai_flutter_GenaiFlutterPlugin_nativeGenerateWithContext(
        JNIEnv* env, jobject thiz, jlong llm_ptr, jlong emb_model_ptr, jstring query,
        jstring db_name, jint max_tokens, jdouble temperature, jint top_k);

    JNIEXPORT jobject JNICALL Java_com_genai_flutter_GenaiFlutterPlugin_nativeSearchSimilarDocuments(
        JNIEnv* env, jobject thiz, jlong emb_model_ptr, jstring query, jstring db_name, jint top_k);

    JNIEXPORT void JNICALL Java_com_genai_flutter_GenaiFlutterPlugin_nativeUnloadModel(
        JNIEnv* env, jobject thiz, jlong context_ptr);

    JNIEXPORT void JNICALL Java_com_genai_flutter_GenaiFlutterPlugin_nativeUnloadEmbeddingModel(
        JNIEnv* env, jobject thiz, jlong emb_model_ptr);

    JNIEXPORT void JNICALL Java_com_genai_flutter_GenaiFlutterPlugin_nativeDispose(
        JNIEnv* env, jobject thiz);
}

#endif // GENAI_BRIDGE_H
