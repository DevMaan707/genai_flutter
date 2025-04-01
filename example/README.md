# GenAI Flutter

A Flutter plugin for local generative AI inference with RAG capabilities on Android.

## Features

- Local Language Model inference on mobile devices
- Efficient embedding generation for RAG (Retrieval-Augmented Generation)
- Vector database for similarity search
- Knowledge base management for custom data

## Requirements

### Android
- MinSdkVersion 21
- NDK 21.0+ recommended
- CMake 3.10+

## Setup Instructions

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/genai_flutter.git
cd genai_flutter
```
2. Set up GGML
```bash
# For Android
mkdir -p android/src/main/cpp/ggml
git clone https://github.com/ggml-org/ggml.git android/src/main/cpp/ggml
```
3. Install dependencies
```bash
flutter pub get
```
4. Setup example project
```bash
cd example
flutter pub get
```
5. Run the example app
```bash
flutter run
```
## Usage
### Basic Initialization
```dart
import 'package:genai_flutter/genai_flutter.dart';

final genai = GenaiFlutter();
await genai.initialize();
Managing Models
// Download models
final llmPath = await genai.modelManager.downloadModel(
  url: 'https://huggingface.co/microsoft/phi-2/resolve/main/ggml-model-f16.gguf',
  modelName: 'phi-2-ggml.gguf',
  onProgress: (progress) => print('Download progress: \${progress * 100}%'),
);

final embeddingPath = await genai.modelManager.downloadEmbeddingModel(
  url: 'https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/model.onnx',
  modelName: 'all-MiniLM-L6-v2.onnx',
  onProgress: (progress) => print('Embedding download: \${progress * 100}%'),
);

// Load models
await genai.genaiService.loadModel(llmPath);
await genai.genaiService.loadEmbeddingModel(embeddingPath);
Text Generation
final response = await genai.genaiService.generateResponse(
  prompt: "Explain quantum computing in simple terms",
  maxTokens: 256,
  temperature: 0.7,
);
Retrieval-Augmented Generation (RAG)
// Create vector database
await genai.genaiService.createVectorDatabase(dbName: 'my_knowledge');

// Add documents to knowledge base
await genai.genaiService.addToKnowledgeBase(
  content: "Flutter is Google's UI toolkit for building applications for mobile, web, and desktop from a single codebase.",
  documentId: "flutter-info-1",
  dbName: 'my_knowledge',
);

// Generate response with context from knowledge base
final response = await genai.genaiService.generateResponseWithContext(
  query: "What is Flutter?",
  dbName: 'my_knowledge',
  maxTokens: 256,
  temperature: 0.7,
);
Search Similar Documents
final results = await genai.genaiService.searchSimilarDocuments(
  query: "mobile development frameworks",
  dbName: 'my_knowledge',
  topK: 3,
);

for (final doc in results) {
  print('ID: ${doc['id']}, Score: ${doc['score']}');
  print('Content: ${doc['content']}');
}
Cleanup
// Unload models when not needed
await genai.genaiService.unloadModel();
await genai.genaiService.unloadEmbeddingModel();

// Dispose plugin resources
await genai.dispose();
```
## Recommended Models
For the best balance between performance and quality, we recommend these models:

Language Models
- Phi-2 GGML  (~1.7GB in 4-bit quantization)
- TinyLLama  (~600MB in 4-bit quantization)
Embedding Models
- all-MiniLM-L6-v2  (~80MB)
- MobileBERT  (~25MB)
