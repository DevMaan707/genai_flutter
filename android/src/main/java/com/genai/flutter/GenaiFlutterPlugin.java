package com.genai.flutter;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import android.os.Handler;
import android.os.Looper;

/** GenaiFlutterPlugin */
public class GenaiFlutterPlugin implements FlutterPlugin, MethodCallHandler {
  private MethodChannel channel;
  private long llmContextPointer = 0;
  private long embeddingModelPointer = 0;
  private boolean isLlmLoaded = false;
  private boolean isEmbeddingModelLoaded = false;
  private final ExecutorService executor = Executors.newSingleThreadExecutor();
  private final Handler mainHandler = new Handler(Looper.getMainLooper());

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "genai_flutter");
    channel.setMethodCallHandler(this);

    // Load native library
    System.loadLibrary("genai_native");
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch(call.method) {
      case "isAvailable":
        result.success(true);
        break;

      case "initialize":
        executor.execute(() -> {
          try {
            nativeInitialize();
            mainHandler.post(() -> result.success(true));
          } catch (Exception e) {
            mainHandler.post(() ->
              result.error("INIT_ERROR", "Failed to initialize: " + e.getMessage(), null));
          }
        });
        break;

      case "loadModel":
        String modelPath = call.argument("modelPath");
        if (modelPath == null) {
          result.error("ARGS_ERROR", "Model path is required", null);
          return;
        }

        executor.execute(() -> {
          try {
            File file = new File(modelPath);
            if (!file.exists()) {
              throw new Exception("Model file does not exist: " + modelPath);
            }

            // Unload previous model if any
            if (isLlmLoaded && llmContextPointer != 0) {
              nativeUnloadModel(llmContextPointer);
              isLlmLoaded = false;
              llmContextPointer = 0;
            }

            llmContextPointer = nativeLoadModel(modelPath);
            isLlmLoaded = true;

            mainHandler.post(() -> result.success(true));
          } catch (Exception e) {
            mainHandler.post(() ->
              result.error("MODEL_ERROR", "Failed to load model: " + e.getMessage(), null));
          }
        });
        break;

      case "loadEmbeddingModel":
        String embModelPath = call.argument("modelPath");
        if (embModelPath == null) {
          result.error("ARGS_ERROR", "Embedding model path is required", null);
          return;
        }

        executor.execute(() -> {
          try {
            File file = new File(embModelPath);
            if (!file.exists()) {
              throw new Exception("Embedding model file does not exist: " + embModelPath);
            }

            // Unload previous model if any
            if (isEmbeddingModelLoaded && embeddingModelPointer != 0) {
              nativeUnloadEmbeddingModel(embeddingModelPointer);
              isEmbeddingModelLoaded = false;
              embeddingModelPointer = 0;
            }

            embeddingModelPointer = nativeLoadEmbeddingModel(embModelPath);
            isEmbeddingModelLoaded = true;

            mainHandler.post(() -> result.success(true));
          } catch (Exception e) {
            mainHandler.post(() ->
              result.error("EMB_MODEL_ERROR", "Failed to load embedding model: " + e.getMessage(), null));
          }
        });
        break;

      case "unloadModel":
        executor.execute(() -> {
          try {
            if (isLlmLoaded && llmContextPointer != 0) {
              nativeUnloadModel(llmContextPointer);
              isLlmLoaded = false;
              llmContextPointer = 0;
            }

            mainHandler.post(() -> result.success(true));
          } catch (Exception e) {
            mainHandler.post(() ->
              result.error("MODEL_ERROR", "Failed to unload model: " + e.getMessage(), null));
          }
        });
        break;

      case "unloadEmbeddingModel":
        executor.execute(() -> {
          try {
            if (isEmbeddingModelLoaded && embeddingModelPointer != 0) {
              nativeUnloadEmbeddingModel(embeddingModelPointer);
              isEmbeddingModelLoaded = false;
              embeddingModelPointer = 0;
            }

            mainHandler.post(() -> result.success(true));
          } catch (Exception e) {
            mainHandler.post(() ->
              result.error("EMB_MODEL_ERROR", "Failed to unload embedding model: " + e.getMessage(), null));
          }
        });
        break;

      case "generate":
        if (!isLlmLoaded || llmContextPointer == 0) {
          result.error("MODEL_ERROR", "Model not loaded", null);
          return;
        }

        String prompt = call.argument("prompt");
        Integer maxTokens = call.argument("maxTokens");
        Double temperature = call.argument("temperature");

        if (prompt == null) {
          result.error("ARGS_ERROR", "Prompt is required", null);
          return;
        }

        executor.execute(() -> {
          try {
            String response = nativeGenerate(
              llmContextPointer,
              prompt,
              maxTokens != null ? maxTokens : 256,
              temperature != null ? temperature : 0.7
            );

            mainHandler.post(() -> result.success(response));
          } catch (Exception e) {
            mainHandler.post(() ->
              result.error("GENERATION_ERROR", "Failed to generate response: " + e.getMessage(), null));
          }
        });
        break;

      case "createVectorDatabase":
        String dbName = call.argument("dbName");
        Integer embeddingDimension = call.argument("embeddingDimension");

        if (dbName == null) {
          result.error("ARGS_ERROR", "Database name is required", null);
          return;
        }

        executor.execute(() -> {
          try {
            boolean success = nativeCreateVectorDatabase(
              dbName,
              embeddingDimension != null ? embeddingDimension : 384
            );

            mainHandler.post(() -> result.success(success));
          } catch (Exception e) {
            mainHandler.post(() ->
              result.error("DB_ERROR", "Failed to create vector database: " + e.getMessage(), null));
          }
        });
        break;

      case "addToKnowledgeBase":
        if (!isEmbeddingModelLoaded || embeddingModelPointer == 0) {
          result.error("EMB_MODEL_ERROR", "Embedding model not loaded", null);
          return;
        }

        String content = call.argument("content");
        String documentId = call.argument("documentId");
        String knowledgeDbName = call.argument("dbName");

        if (content == null || documentId == null) {
          result.error("ARGS_ERROR", "Content and document ID are required", null);
          return;
        }

        executor.execute(() -> {
          try {
            boolean success = nativeAddToKnowledgeBase(
              embeddingModelPointer,
              content,
              documentId,
              knowledgeDbName != null ? knowledgeDbName : "default_db"
            );

            mainHandler.post(() -> result.success(success));
          } catch (Exception e) {
            mainHandler.post(() ->
              result.error("RAG_ERROR", "Failed to add to knowledge base: " + e.getMessage(), null));
          }
        });
        break;

      case "generateWithContext":
        if (!isLlmLoaded || llmContextPointer == 0) {
          result.error("MODEL_ERROR", "Language model not loaded", null);
          return;
        }

        if (!isEmbeddingModelLoaded || embeddingModelPointer == 0) {
          result.error("EMB_MODEL_ERROR", "Embedding model not loaded", null);
          return;
        }

        String query = call.argument("query");
        String ragDbName = call.argument("dbName");
        Integer ragMaxTokens = call.argument("maxTokens");
        Double ragTemperature = call.argument("temperature");
        Integer topK = call.argument("topK");

        if (query == null) {
          result.error("ARGS_ERROR", "Query is required", null);
          return;
        }

        executor.execute(() -> {
          try {
            String response = nativeGenerateWithContext(
              llmContextPointer,
              embeddingModelPointer,
              query,
              ragDbName != null ? ragDbName : "default_db",
              ragMaxTokens != null ? ragMaxTokens : 256,
              ragTemperature != null ? ragTemperature : 0.7,
              topK != null ? topK : 3
            );

            mainHandler.post(() -> result.success(response));
          } catch (Exception e) {
            mainHandler.post(() ->
              result.error("RAG_ERROR", "Failed to generate with context: " + e.getMessage(), null));
          }
        });
        break;

      case "searchSimilarDocuments":
        if (!isEmbeddingModelLoaded || embeddingModelPointer == 0) {
          result.error("EMB_MODEL_ERROR", "Embedding model not loaded", null);
          return;
        }

        String searchQuery = call.argument("query");
        String searchDbName = call.argument("dbName");
        Integer searchTopK = call.argument("topK");

        if (searchQuery == null) {
          result.error("ARGS_ERROR", "Query is required", null);
          return;
        }

        executor.execute(() -> {
          try {
            ArrayList<Map<String, Object>> results = nativeSearchSimilarDocuments(
              embeddingModelPointer,
              searchQuery,
              searchDbName != null ? searchDbName : "default_db",
              searchTopK != null ? searchTopK : 5
            );

            mainHandler.post(() -> result.success(results));
          } catch (Exception e) {
            mainHandler.post(() ->
              result.error("SEARCH_ERROR", "Failed to search documents: " + e.getMessage(), null));
          }
        });
        break;

      case "dispose":
        executor.execute(() -> {
          try {
            if (isLlmLoaded && llmContextPointer != 0) {
              nativeUnloadModel(llmContextPointer);
              isLlmLoaded = false;
              llmContextPointer = 0;
            }

            if (isEmbeddingModelLoaded && embeddingModelPointer != 0) {
              nativeUnloadEmbeddingModel(embeddingModelPointer);
              isEmbeddingModelLoaded = false;
              embeddingModelPointer = 0;
            }

            nativeDispose();

            mainHandler.post(() -> result.success(true));
          } catch (Exception e) {
            mainHandler.post(() ->
              result.error("DISPOSE_ERROR", "Failed to dispose resources: " + e.getMessage(), null));
          }
        });
        break;

      default:
        result.notImplemented();
        break;
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);

    // Clean up resources
    if (isLlmLoaded && llmContextPointer != 0) {
      nativeUnloadModel(llmContextPointer);
      isLlmLoaded = false;
      llmContextPointer = 0;
    }

    if (isEmbeddingModelLoaded && embeddingModelPointer != 0) {
      nativeUnloadEmbeddingModel(embeddingModelPointer);
      isEmbeddingModelLoaded = false;
      embeddingModelPointer = 0;
    }

    nativeDispose();
    executor.shutdown();
  }

  // Native method declarations
  private native void nativeInitialize();
  private native long nativeLoadModel(String modelPath);
  private native long nativeLoadEmbeddingModel(String modelPath);
  private native String nativeGenerate(long contextPtr, String prompt, int maxTokens, double temperature);
  private native boolean nativeCreateVectorDatabase(String dbName, int embeddingDimension);
  private native boolean nativeAddToKnowledgeBase(long embModelPtr, String content, String documentId, String dbName);
  private native String nativeGenerateWithContext(long llmPtr, long embModelPtr, String query, String dbName, int maxTokens, double temperature, int topK);
  private native ArrayList<Map<String, Object>> nativeSearchSimilarDocuments(long embModelPtr, String query, String dbName, int topK);
  private native void nativeUnloadModel(long contextPtr);
  private native void nativeUnloadEmbeddingModel(long embModelPtr);
  private native void nativeDispose();
}
