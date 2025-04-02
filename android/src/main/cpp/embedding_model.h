#ifndef GENAI_EMBEDDING_MODEL_H
#define GENAI_EMBEDDING_MODEL_H

#include <stdint.h>
#include <string>
#include <vector>
#include <mutex>
#include <android/log.h>
// MobileBERT embedding model implementation
class EmbeddingModel {
private:
    void* model_ptr;  // Opaque pointer to the model
    std::mutex mtx;
    int embedding_dim;

    // Private helper functions
    void tokenize(const std::string& text, std::vector<int>& tokens);
    void processTokens(const std::vector<int>& tokens, std::vector<float>& embedding);

public:
    EmbeddingModel(const std::string& model_path);
    ~EmbeddingModel();

    // Generate embedding for a piece of text
    std::vector<float> generateEmbedding(const std::string& text);

    // Get embedding dimension
    int embeddingDimension() const { return embedding_dim; }
};

#endif // EMBEDDING_MODEL_H
