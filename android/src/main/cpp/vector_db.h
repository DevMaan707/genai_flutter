#ifndef VECTOR_DB_H
#define VECTOR_DB_H

#include <string>
#include <vector>
#include <mutex>
#include <sqlite3.h>

// Document match structure for search results
struct DocumentMatch {
    std::string id;
    std::string content;
    float score;
};

// SQLite-based vector database for document storage and retrieval
class VectorDB {
private:
    sqlite3* db;
    std::mutex mtx;
    bool initialized;
    int embedding_dimension;
    std::string db_path;

    // Helper methods
    bool createTables();
    float computeCosineSimilarity(const std::vector<float>& a, const std::vector<float>& b);
    std::string serializeEmbedding(const std::vector<float>& embedding);
    std::vector<float> deserializeEmbedding(const std::string& data);

public:
    VectorDB(const std::string& db_name, int embedding_dim);
    ~VectorDB();

    // Check if database initialized correctly
    bool isInitialized() const { return initialized; }

    // Add a document with its embedding to the database
    bool addDocument(const std::string& doc_id, const std::string& content, const std::vector<float>& embedding);

    // Find similar documents using vector similarity search
    std::vector<DocumentMatch> findSimilarDocuments(const std::vector<float>& query_embedding, int top_k);

    // Delete a document from the database
    bool deleteDocument(const std::string& doc_id);

    // Get total document count
    int getDocumentCount();
};

#endif // VECTOR_DB_H
