import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

/// Manages LLM models (download, listing, deletion)
class ModelManager {
  final MethodChannel _channel;
  final Dio _dio = Dio();

  ModelManager(this._channel);

  /// Get models directory
  Future<Directory> get modelsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(path.join(appDir.path, 'genai_models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// Get embeddings model directory
  Future<Directory> get embeddingsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final embDir = Directory(path.join(appDir.path, 'genai_embeddings'));
    if (!await embDir.exists()) {
      await embDir.create(recursive: true);
    }
    return embDir;
  }

  /// Download a model from a URL
  Future<String> downloadModel({
    required String url,
    required String modelName,
    void Function(double progress)? onProgress,
  }) async {
    final modelsDir = await this.modelsDir;
    final modelPath = path.join(modelsDir.path, modelName);
    final modelFile = File(modelPath);

    if (await modelFile.exists()) {
      return modelPath;
    }

    try {
      await _dio.download(
        url,
        modelPath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );
      return modelPath;
    } catch (e) {
      print('Error downloading model: $e');
      rethrow;
    }
  }

  /// Download embedding model
  Future<String> downloadEmbeddingModel({
    required String url,
    required String modelName,
    void Function(double progress)? onProgress,
  }) async {
    final embDir = await this.embeddingsDir;
    final modelPath = path.join(embDir.path, modelName);
    final modelFile = File(modelPath);

    if (await modelFile.exists()) {
      return modelPath;
    }

    try {
      await _dio.download(
        url,
        modelPath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );
      return modelPath;
    } catch (e) {
      print('Error downloading embedding model: $e');
      rethrow;
    }
  }

  /// List available downloaded models
  Future<List<String>> listDownloadedModels() async {
    final modelsDir = await this.modelsDir;
    if (!await modelsDir.exists()) {
      return [];
    }

    try {
      final entities = await modelsDir.list().toList();
      return entities
          .whereType<File>()
          .map((file) => path.basename(file.path))
          .toList();
    } catch (e) {
      print('Error listing models: $e');
      return [];
    }
  }

  /// List available embedding models
  Future<List<String>> listDownloadedEmbeddingModels() async {
    final embDir = await this.embeddingsDir;
    if (!await embDir.exists()) {
      return [];
    }

    try {
      final entities = await embDir.list().toList();
      return entities
          .whereType<File>()
          .map((file) => path.basename(file.path))
          .toList();
    } catch (e) {
      print('Error listing embedding models: $e');
      return [];
    }
  }

  /// Delete a downloaded model
  Future<bool> deleteModel(String modelName) async {
    final modelsDir = await this.modelsDir;
    final modelPath = path.join(modelsDir.path, modelName);
    final modelFile = File(modelPath);

    try {
      if (await modelFile.exists()) {
        await modelFile.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting model: $e');
      return false;
    }
  }

  /// Delete an embedding model
  Future<bool> deleteEmbeddingModel(String modelName) async {
    final embDir = await this.embeddingsDir;
    final modelPath = path.join(embDir.path, modelName);
    final modelFile = File(modelPath);

    try {
      if (await modelFile.exists()) {
        await modelFile.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting embedding model: $e');
      return false;
    }
  }

  /// Get the size of a model file in MB
  Future<double> getModelSize(String modelName) async {
    final modelsDir = await this.modelsDir;
    final modelPath = path.join(modelsDir.path, modelName);
    final modelFile = File(modelPath);

    try {
      if (await modelFile.exists()) {
        final bytes = await modelFile.length();
        return bytes / (1024 * 1024); // Convert to MB
      }
      return 0.0;
    } catch (e) {
      print('Error getting model size: \$e');
      return 0.0;
    }
  }
}
