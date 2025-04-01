import 'dart:async';
import 'package:flutter/services.dart';
import 'src/model_manager.dart';
import 'src/genai_service.dart';

/// Main class for the GenAI Flutter plugin
class GenaiFlutter {
  static const MethodChannel _channel = MethodChannel('genai_flutter');
  late final ModelManager modelManager;
  late final GenaiService genaiService;

  GenaiFlutter() {
    modelManager = ModelManager(_channel);
    genaiService = GenaiService(_channel);
  }

  Future<String?> getPlatformVersion() async {
    try {
      return await _channel.invokeMethod('getPlatformVersion');
    } catch (e) {
      print('Error getting platform version: $e');
      return null;
    }
  }

  /// Check if the plugin is available
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod('isAvailable') ?? false;
    } catch (e) {
      print('Error checking plugin availability: $e');
      return false;
    }
  }

  /// Initialize the plugin
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
    } catch (e) {
      print('Error initializing plugin: $e');
      throw Exception('Failed to initialize plugin: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
    } catch (e) {
      print('Error disposing plugin: $e');
    }
  }
}
