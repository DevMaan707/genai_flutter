import 'dart:async';
import 'package:flutter/services.dart';

/// Service for interacting with the LLM and RAG capabilities
class GenaiService {
  final MethodChannel _channel;
  bool _isModelLoaded = false;
  bool _isEmbeddingModelLoaded = false;

  GenaiService(this._channel);

  /// Load a language model from the given path
  Future<bool> loadModel(String modelPath) async {
    try {
      _isModelLoaded = await _channel.invokeMethod('loadModel', {
            'modelPath': modelPath,
          }) ??
          false;
      return _isModelLoaded;
    } catch (e) {
      print('Error loading model: $e');
      _isModelLoaded = false;
      rethrow;
    }
  }

  /// Load an embedding model from the given path
  Future<bool> loadEmbeddingModel(String modelPath) async {
    try {
      _isEmbeddingModelLoaded =
          await _channel.invokeMethod('loadEmbeddingModel', {
                'modelPath': modelPath,
              }) ??
              false;
      return _isEmbeddingModelLoaded;
    } catch (e) {
      print('Error loading embedding model: $e');
      _isEmbeddingModelLoaded = false;
      rethrow;
    }
  }

  /// Check if a language model is loaded
  bool get isModelLoaded => _isModelLoaded;

  /// Check if an embedding model is loaded
  bool get isEmbeddingModelLoaded => _isEmbeddingModelLoaded;

  /// Generate a response from the loaded model
  Future<String> generateResponse({
    required String prompt,
    int maxTokens = 256,
    double temperature = 0.7,
  }) async {
    if (!_isModelLoaded) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    try {
      final response = await _channel.invokeMethod('generate', {
        'prompt': prompt,
        'maxTokens': maxTokens,
        'temperature': temperature,
      });
      return response?.toString() ?? '';
    } catch (e) {
      print('Error generating response: $e');
      rethrow;
    }
  }

  /// Create a vector database for storing documents
  Future<bool> createVectorDatabase({
    required String dbName,
    int embeddingDimension = 384, // Default dimension
  }) async {
    if (!_isEmbeddingModelLoaded) {
      throw Exception(
          'Embedding model not loaded. Call loadEmbeddingModel() first.');
    }

    try {
      final result = await _channel.invokeMethod('createVectorDatabase', {
        'dbName': dbName,
        'embeddingDimension': embeddingDimension,
      });
      return result ?? false;
    } catch (e) {
      print('Error creating vector database: $e');
      rethrow;
    }
  }

  /// Add content to the knowledge base for RAG
  Future<bool> addToKnowledgeBase({
    required String content,
    required String documentId,
    String? dbName,
  }) async {
    if (!_isEmbeddingModelLoaded) {
      throw Exception(
          'Embedding model not loaded. Call loadEmbeddingModel() first.');
    }

    try {
      final result = await _channel.invokeMethod('addToKnowledgeBase', {
        'content': content,
        'documentId': documentId,
        'dbName': dbName ?? 'default_db',
      });
      return result ?? false;
    } catch (e) {
      print('Error adding to knowledge base: $e');
      rethrow;
    }
  }

  /// Generate a response with RAG context
  Future<String> generateResponseWithContext({
    required String query,
    String? dbName,
    int maxTokens = 256,
    double temperature = 0.7,
    int topK = 3,
  }) async {
    if (!_isModelLoaded) {
      throw Exception('Language model not loaded. Call loadModel() first.');
    }

    if (!_isEmbeddingModelLoaded) {
      throw Exception(
          'Embedding model not loaded. Call loadEmbeddingModel() first.');
    }

    try {
      final response = await _channel.invokeMethod('generateWithContext', {
        'query': query,
        'dbName': dbName ?? 'default_db',
        'maxTokens': maxTokens,
        'temperature': temperature,
        'topK': topK,
      });
      return response?.toString() ?? '';
    } catch (e) {
      print('Error generating response with context: $e');
      rethrow;
    }
  }

  /// Search for documents similar to a query
  Future<List<Map<String, dynamic>>> searchSimilarDocuments({
    required String query,
    String? dbName,
    int topK = 5,
  }) async {
    if (!_isEmbeddingModelLoaded) {
      throw Exception(
          'Embedding model not loaded. Call loadEmbeddingModel() first.');
    }

    try {
      final result = await _channel.invokeMethod('searchSimilarDocuments', {
        'query': query,
        'dbName': dbName ?? 'default_db',
        'topK': topK,
      });

      if (result == null) return [];

      List<dynamic> resultList = result as List<dynamic>;
      return resultList
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      print('Error searching documents: $e');
      rethrow;
    }
  }

  /// Unload the current language model and free resources
  Future<bool> unloadModel() async {
    if (!_isModelLoaded) {
      return true; // Already unloaded
    }

    try {
      final result = await _channel.invokeMethod('unloadModel');
      _isModelLoaded = false;
      return result ?? true;
    } catch (e) {
      print('Error unloading model: $e');
      rethrow;
    }
  }

  /// Unload the embedding model and free resources
  Future<bool> unloadEmbeddingModel() async {
    if (!_isEmbeddingModelLoaded) {
      return true; // Already unloaded
    }

    try {
      final result = await _channel.invokeMethod('unloadEmbeddingModel');
      _isEmbeddingModelLoaded = false;
      return result ?? true;
    } catch (e) {
      print('Error unloading embedding model: $e');
      rethrow;
    }
  }
}
