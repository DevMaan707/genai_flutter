#include "embedding_model.h"
#include <android/log.h>
#include <cmath>
#include <algorithm>

#define LOG_TAG "EmbeddingModel"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

EmbeddingModel::EmbeddingModel(const std::string& model_path) : model_ptr(nullptr), embedding_dim(384) {
    LOGI("Initializing embedding model from %s", model_path.c_str());

    // In a real implementation, you would:
    // 1. Load your MobileBERT or other embedding model here
    // 2. Set up tokenization and inference

    // For this example, we'll just initialize an empty model
    model_ptr = new int(1);  // Dummy allocation for the example

    LOGI("Embedding model initialized, dimension: %d", embedding_dim);
}

EmbeddingModel::~EmbeddingModel() {
    if (model_ptr) {
        delete static_cast<int*>(model_ptr);
        model_ptr = nullptr;
    }

    LOGI("Embedding model resources released");
}

void EmbeddingModel::tokenize(const std::string& text, std::vector<int>& tokens) {
    // In a real implementation, this would tokenize the text using the model's tokenizer
    // For this example, we'll just use a simple character-based tokenization
    tokens.clear();
    for (char c : text) {
        tokens.push_back(static_cast<int>(c));
    }

    // Truncate to max sequence length if needed
    if (tokens.size() > 512) {
        tokens.resize(512);
    }
}

void EmbeddingModel::processTokens(const std::vector<int>& tokens, std::vector<float>& embedding) {
    // In a real implementation, this would process the tokens through the model
    // For this example, we'll just generate a dummy embedding

    embedding.resize(embedding_dim, 0.0f);

    // Generate a deterministic but unique embedding based on the content
    float sum = 0.0f;
    for (size_t i = 0; i < tokens.size(); ++i) {
        float val = static_cast<float>(tokens[i]) / 256.0f;
        int pos = i % embedding_dim;
        embedding[pos] += val;
        sum += val;
    }

    // Normalize the embedding
    float norm = 0.0f;
    for (float val : embedding) {
        norm += val * val;
    }
    norm = std::sqrt(norm);

    if (norm > 0) {
        for (float& val : embedding) {
            val /= norm;
        }
    }
}

std::vector<float> EmbeddingModel::generateEmbedding(const std::string& text) {
    std::lock_guard<std::mutex> lock(mtx);

    std::vector<int> tokens;
    std::vector<float> embedding;

    // Tokenize the text
    tokenize(text, tokens);

    // Process tokens to get the embedding
    processTokens(tokens, embedding);

    return embedding;
}
