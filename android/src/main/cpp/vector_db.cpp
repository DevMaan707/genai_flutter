#include "sqlite_wrapper.h"
#include <stdint.h>
#include <android/log.h>
#include "vector_db.h"
#include <cmath>
#include <algorithm>
#include <sstream>
#include <iomanip>
#include <sys/stat.h>
#include <unistd.h>

#define LOG_TAG "VectorDB"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

VectorDB::VectorDB(const std::string& db_name, int embedding_dim)
    : db(nullptr), initialized(false), embedding_dimension(embedding_dim) {

    LOGI("Initializing vector database: %s, dim: %d", db_name.c_str(), embedding_dim);

    // Use Android's app-specific directory
    std::string app_data_dir = "/data/data/com.example.genai_flutter_example/databases/";

    // Create directories if they don't exist
    mkdir(app_data_dir.c_str(), 0755);

    db_path = app_data_dir + db_name + ".db";

    LOGI("Database path: %s", db_path.c_str());

    // Open database connection
    int rc = sqlite3_open(db_path.c_str(), &db);
    if (rc != SQLITE_OK) {
        LOGE("Failed to open database: %s", sqlite3_errmsg(db));
        return;
    }

    // Create tables
    if (!createTables()) {
        LOGE("Failed to create tables");
        sqlite3_close(db);
        db = nullptr;
        return;
    }

    initialized = true;
    LOGI("Vector database initialized successfully");
}

VectorDB::~VectorDB() {
    if (db) {
        sqlite3_close(db);
        db = nullptr;
    }
    LOGI("Vector database resources released");
}

bool VectorDB::createTables() {
    std::lock_guard<std::mutex> lock(mtx);

    if (!db) return false;

    const char* create_tables_sql = R"(
        -- Documents table with embeddings
        CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            embedding BLOB NOT NULL
        );

        -- Create indices for faster retrieval
        CREATE INDEX IF NOT EXISTS idx_documents_id ON documents(id);
        CREATE INDEX IF NOT EXISTS idx_documents_content ON documents(content);
    )";

    char* error_msg = nullptr;
    int rc = sqlite3_exec(db, create_tables_sql, nullptr, nullptr, &error_msg);

    if (rc != SQLITE_OK) {
        LOGE("SQL error: %s", error_msg);
        sqlite3_free(error_msg);
        return false;
    }

    return true;
}

std::string VectorDB::serializeEmbedding(const std::vector<float>& embedding) {
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(6);

    for (size_t i = 0; i < embedding.size(); ++i) {
        if (i > 0) oss << ",";
        oss << embedding[i];
    }

    return oss.str();
}

std::vector<float> VectorDB::deserializeEmbedding(const std::string& data) {
    std::vector<float> embedding;
    std::istringstream iss(data);
    std::string token;

    while (std::getline(iss, token, ',')) {
        try {
            embedding.push_back(std::stof(token));
        } catch (const std::exception& e) {
            LOGE("Error parsing embedding value: %s", e.what());
        }
    }

    return embedding;
}

float VectorDB::computeCosineSimilarity(const std::vector<float>& a, const std::vector<float>& b) {
    if (a.size() != b.size() || a.empty()) {
        return 0.0f;
    }

    float dot_product = 0.0f;
    float norm_a = 0.0f;
    float norm_b = 0.0f;

    for (size_t i = 0; i < a.size(); ++i) {
        dot_product += a[i] * b[i];
        norm_a += a[i] * a[i];
        norm_b += b[i] * b[i];
    }

    if (norm_a == 0.0f || norm_b == 0.0f) {
        return 0.0f;
    }

    return dot_product / (std::sqrt(norm_a) * std::sqrt(norm_b));
}

bool VectorDB::addDocument(const std::string& doc_id, const std::string& content, const std::vector<float>& embedding) {
    std::lock_guard<std::mutex> lock(mtx);

    if (!db || !initialized) {
        LOGE("Database not initialized");
        return false;
    }

    if (static_cast<int>(embedding.size()) != embedding_dimension){
        LOGE("Invalid embedding dimension: expected %d, got %zu", embedding_dimension, embedding.size());
        return false;
    }

    const char* sql = "INSERT OR REPLACE INTO documents (id, content, embedding) VALUES (?, ?, ?)";
    sqlite3_stmt* stmt;

    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) {
        LOGE("Failed to prepare statement: %s", sqlite3_errmsg(db));
        return false;
    }

    std::string serialized_embedding = serializeEmbedding(embedding);

    sqlite3_bind_text(stmt, 1, doc_id.c_str(), -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 2, content.c_str(), -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 3, serialized_embedding.c_str(), -1, SQLITE_STATIC);

    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);

    if (rc != SQLITE_DONE) {
        LOGE("Failed to insert document: %s", sqlite3_errmsg(db));
        return false;
    }

    LOGI("Document added successfully: %s", doc_id.c_str());
    return true;
}

std::vector<DocumentMatch> VectorDB::findSimilarDocuments(const std::vector<float>& query_embedding, int top_k) {
    std::lock_guard<std::mutex> lock(mtx);
    std::vector<DocumentMatch> results;

    if (!db || !initialized) {
        LOGE("Database not initialized");
        return results;
    }

    if (static_cast<int>(query_embedding.size()) != embedding_dimension) {
        LOGE("Invalid query embedding dimension: expected %d, got %zu",
             embedding_dimension, query_embedding.size());
        return results;
    }

    // Get all documents
    const char* sql = "SELECT id, content, embedding FROM documents";
    sqlite3_stmt* stmt;

    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) {
        LOGE("Failed to prepare statement: %s", sqlite3_errmsg(db));
        return results;
    }

    std::vector<DocumentMatch> matches;

    // Process each document
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        const char* doc_id = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));
        const char* content = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
        const char* embedding_str = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));

        std::vector<float> doc_embedding = deserializeEmbedding(embedding_str);

        if (static_cast<int>(doc_embedding.size()) == embedding_dimension) {
            float similarity = computeCosineSimilarity(query_embedding, doc_embedding);

            DocumentMatch match;
            match.id = doc_id;
            match.content = content;
            match.score = similarity;

            matches.push_back(match);
        }
    }

    sqlite3_finalize(stmt);

    // Sort by similarity score (descending)
    std::sort(matches.begin(), matches.end(),
              [](const DocumentMatch& a, const DocumentMatch& b) {
                  return a.score > b.score;
              });

    // Return top_k results
    size_t count = std::min(static_cast<size_t>(top_k), matches.size());
    results.assign(matches.begin(), matches.begin() + count);

    LOGI("Found %zu similar documents", count);
    return results;
}

bool VectorDB::deleteDocument(const std::string& doc_id) {
    std::lock_guard<std::mutex> lock(mtx);

    if (!db || !initialized) {
        LOGE("Database not initialized");
        return false;
    }

    const char* sql = "DELETE FROM documents WHERE id = ?";
    sqlite3_stmt* stmt;

    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) {
        LOGE("Failed to prepare statement: %s", sqlite3_errmsg(db));
        return false;
    }

    sqlite3_bind_text(stmt, 1, doc_id.c_str(), -1, SQLITE_STATIC);

    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);

    if (rc != SQLITE_DONE) {
        LOGE("Failed to delete document: %s", sqlite3_errmsg(db));
        return false;
    }

    LOGI("Document deleted successfully: %s", doc_id.c_str());
    return true;
}

int VectorDB::getDocumentCount() {
    std::lock_guard<std::mutex> lock(mtx);

    if (!db || !initialized) {
        LOGE("Database not initialized");
        return 0;
    }

    const char* sql = "SELECT COUNT(*) FROM documents";
    sqlite3_stmt* stmt;

    int count = 0;
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);

    if (rc == SQLITE_OK && sqlite3_step(stmt) == SQLITE_ROW) {
        count = sqlite3_column_int(stmt, 0);
    }

    sqlite3_finalize(stmt);
    return count;
}

bool VectorDB::clearDatabase() {
    std::lock_guard<std::mutex> lock(mtx);

    if (!db || !initialized) {
        LOGE("Database not initialized");
        return false;
    }

    const char* sql = "DELETE FROM documents";
    char* error_msg = nullptr;

    int rc = sqlite3_exec(db, sql, nullptr, nullptr, &error_msg);

    if (rc != SQLITE_OK) {
        LOGE("Failed to clear database: %s", error_msg);
        sqlite3_free(error_msg);
        return false;
    }

    LOGI("Database cleared successfully");
    return true;
}

bool VectorDB::isInitialized() const {
    return initialized;
}

void VectorDB::compactDatabase() {
    std::lock_guard<std::mutex> lock(mtx);

    if (!db || !initialized) {
        LOGE("Database not initialized");
        return;
    }

    const char* sql = "VACUUM";
    char* error_msg = nullptr;

    int rc = sqlite3_exec(db, sql, nullptr, nullptr, &error_msg);

    if (rc != SQLITE_OK) {
        LOGE("Failed to compact database: %s", error_msg);
        sqlite3_free(error_msg);
        return;
    }

    LOGI("Database compacted successfully");
}
