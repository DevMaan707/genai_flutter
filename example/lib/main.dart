import 'package:flutter/material.dart';
import 'dart:async';
import 'package:genai_flutter/genai_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenAI Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _genai = GenaiFlutter();
  bool _isInitialized = false;
  bool _isLlmLoaded = false;
  bool _isEmbeddingModelLoaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = 'Initializing...';
  List<String> _downloadedModels = [];
  List<String> _downloadedEmbeddingModels = [];
  String? _currentLlmModel;
  String? _currentEmbeddingModel;

  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _knowledgeTextController =
      TextEditingController();
  final TextEditingController _knowledgeIdController = TextEditingController();
  String _response = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlugin();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _knowledgeTextController.dispose();
    _knowledgeIdController.dispose();
    _genai.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background, unload models to save memory
      _unloadModels();
    }
  }

  Future<void> _unloadModels() async {
    if (_isLlmLoaded) {
      await _genai.genaiService.unloadModel();
      setState(() {
        _isLlmLoaded = false;
        _currentLlmModel = null;
      });
    }

    if (_isEmbeddingModelLoaded) {
      await _genai.genaiService.unloadEmbeddingModel();
      setState(() {
        _isEmbeddingModelLoaded = false;
        _currentEmbeddingModel = null;
      });
    }
  }

  Future<void> _initializePlugin() async {
    try {
      await _genai.initialize();
      await _refreshModelLists();

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Plugin initialized successfully';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing plugin: $e';
      });
    }
  }

  Future<void> _refreshModelLists() async {
    final models = await _genai.modelManager.listDownloadedModels();
    final embModels = await _genai.modelManager.listDownloadedEmbeddingModels();

    setState(() {
      _downloadedModels = models;
      _downloadedEmbeddingModels = embModels;
    });
  }

  Future<void> _downloadLlmModel() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Starting LLM download...';
    });

    try {
      // Example URL for a lightweight model - replace with your preferred model
      const url =
          'https://huggingface.co/microsoft/phi-2/resolve/main/ggml-model-f16.gguf';
      const modelName = 'phi-2-ggml.gguf';

      final modelPath = await _genai.modelManager.downloadModel(
        url: url,
        modelName: modelName,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
            _statusMessage =
                'Downloading LLM: ${(progress * 100).toStringAsFixed(1)}%';
          });
        },
      );

      setState(() {
        _statusMessage = 'LLM downloaded to: $modelPath';
      });

      await _refreshModelLists();
    } catch (e) {
      setState(() {
        _statusMessage = 'LLM download failed: $e';
      });
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _downloadEmbeddingModel() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Starting embedding model download...';
    });

    try {
      // Example URL for a lightweight embedding model
      const url =
          'https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/model.onnx';
      const modelName = 'all-MiniLM-L6-v2.onnx';

      final modelPath = await _genai.modelManager.downloadEmbeddingModel(
        url: url,
        modelName: modelName,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
            _statusMessage =
                'Downloading embedding model: ${(progress * 100).toStringAsFixed(1)}%';
          });
        },
      );

      setState(() {
        _statusMessage = 'Embedding model downloaded to: $modelPath';
      });

      await _refreshModelLists();
    } catch (e) {
      setState(() {
        _statusMessage = 'Embedding model download failed: $e';
      });
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _loadLlmModel(String modelName) async {
    setState(() {
      _statusMessage = 'Loading LLM: $modelName';
      _isProcessing = true;
    });

    try {
      final modelsDir = await _genai.modelManager.modelsDir;
      final modelPath = '\${modelsDir.path}/$modelName';

      final success = await _genai.genaiService.loadModel(modelPath);
      setState(() {
        _isLlmLoaded = success;
        _currentLlmModel = success ? modelName : null;
        _statusMessage = success
            ? 'LLM loaded successfully: $modelName'
            : 'Failed to load LLM: $modelName';
      });
    } catch (e) {
      setState(() {
        _isLlmLoaded = false;
        _currentLlmModel = null;
        _statusMessage = 'Error loading LLM: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _loadEmbeddingModel(String modelName) async {
    setState(() {
      _statusMessage = 'Loading embedding model: $modelName';
      _isProcessing = true;
    });

    try {
      final modelsDir = await _genai.modelManager.embeddingsDir;
      final modelPath = '\${modelsDir.path}/$modelName';

      final success = await _genai.genaiService.loadEmbeddingModel(modelPath);
      setState(() {
        _isEmbeddingModelLoaded = success;
        _currentEmbeddingModel = success ? modelName : null;
        _statusMessage = success
            ? 'Embedding model loaded successfully: $modelName'
            : 'Failed to load embedding model: $modelName';
      });

      if (success) {
        // Create a vector database when embedding model is loaded
        await _genai.genaiService.createVectorDatabase(dbName: 'default_db');
      }
    } catch (e) {
      setState(() {
        _isEmbeddingModelLoaded = false;
        _currentEmbeddingModel = null;
        _statusMessage = 'Error loading embedding model: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _generateResponse() async {
    if (!_isLlmLoaded || _isProcessing) return;

    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a prompt';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _response = 'Generating...';
      _statusMessage = 'Processing request...';
    });

    try {
      final response = await _genai.genaiService.generateResponse(
        prompt: prompt,
        maxTokens: 256,
        temperature: 0.7,
      );

      setState(() {
        _response = response;
        _statusMessage = 'Response generated successfully';
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _statusMessage = 'Failed to generate response';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _addToKnowledgeBase() async {
    if (!_isEmbeddingModelLoaded || _isProcessing) return;

    final content = _knowledgeTextController.text.trim();
    final id = _knowledgeIdController.text.trim();

    if (content.isEmpty || id.isEmpty) {
      setState(() {
        _statusMessage = 'Please provide both content and document ID';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Adding to knowledge base...';
    });

    try {
      final success = await _genai.genaiService.addToKnowledgeBase(
        content: content,
        documentId: id,
      );

      setState(() {
        _statusMessage = success
            ? 'Added to knowledge base successfully'
            : 'Failed to add to knowledge base';
      });

      if (success) {
        _knowledgeTextController.clear();
        _knowledgeIdController.clear();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error adding to knowledge base: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _generateWithContext() async {
    if (!_isLlmLoaded || !_isEmbeddingModelLoaded || _isProcessing) return;

    final query = _promptController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a query';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _response = 'Searching for context and generating...';
      _statusMessage = 'Processing RAG request...';
    });

    try {
      final response = await _genai.genaiService.generateResponseWithContext(
        query: query,
        maxTokens: 512,
        temperature: 0.7,
      );

      setState(() {
        _response = response;
        _statusMessage = 'RAG response generated successfully';
      });
    } catch (e) {
      setState(() {
        _response = 'Error: \$e';
        _statusMessage = 'Failed to generate RAG response';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _searchDocuments() async {
    if (!_isEmbeddingModelLoaded || _isProcessing) return;

    final query = _promptController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a query';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _response = 'Searching for similar documents...';
      _statusMessage = 'Searching...';
    });

    try {
      final docs = await _genai.genaiService.searchSimilarDocuments(
        query: query,
        topK: 5,
      );

      if (docs.isEmpty) {
        setState(() {
          _response = 'No similar documents found';
          _statusMessage = 'Search completed';
        });
      } else {
        final buffer = StringBuffer();
        buffer.writeln('Found \${docs.length} similar documents:');
        buffer.writeln();

        for (int i = 0; i < docs.length; i++) {
          final doc = docs[i];
          buffer.writeln('Document ${i + 1}: ${doc['id']}');
          buffer
              .writeln('Score: ${(doc['score'] as double).toStringAsFixed(4)}');
          buffer.writeln('Content: ${doc['content']}');
          buffer.writeln('-' * 40);
        }

        setState(() {
          _response = buffer.toString();
          _statusMessage = 'Search completed';
        });
      }
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _statusMessage = 'Failed to search documents';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GenAI Flutter Demo'),
      ),
      body: !_isInitialized
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage),
                ],
              ),
            )
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status: $_statusMessage',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                                'LLM: ${_isLlmLoaded ? _currentLlmModel ?? 'Loaded' : 'Not loaded'}'),
                            Text(
                                'Embedding model: ${_isEmbeddingModelLoaded ? _currentEmbeddingModel ?? 'Loaded' : 'Not loaded'}'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Model management
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Model Management',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isDownloading
                                        ? null
                                        : _downloadLlmModel,
                                    child: const Text('Download LLM'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isDownloading
                                        ? null
                                        : _downloadEmbeddingModel,
                                    child: const Text('Download Embeddings'),
                                  ),
                                ),
                              ],
                            ),
                            if (_isDownloading) ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(value: _downloadProgress),
                              Text(
                                  '${(_downloadProgress * 100).toStringAsFixed(1)}%'),
                            ],
                            const SizedBox(height: 16),
                            const Text('LLM Models',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            if (_downloadedModels.isEmpty)
                              const Text('No LLM models downloaded')
                            else
                              for (final model in _downloadedModels)
                                ListTile(
                                  title: Text(model),
                                  trailing: ElevatedButton(
                                    onPressed: _currentLlmModel == model ||
                                            _isProcessing
                                        ? null
                                        : () => _loadLlmModel(model),
                                    child: Text(_currentLlmModel == model
                                        ? 'Loaded'
                                        : 'Load'),
                                  ),
                                ),
                            const SizedBox(height: 16),
                            const Text('Embedding Models',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            if (_downloadedEmbeddingModels.isEmpty)
                              const Text('No embedding models downloaded')
                            else
                              for (final model in _downloadedEmbeddingModels)
                                ListTile(
                                  title: Text(model),
                                  trailing: ElevatedButton(
                                    onPressed:
                                        _currentEmbeddingModel == model ||
                                                _isProcessing
                                            ? null
                                            : () => _loadEmbeddingModel(model),
                                    child: Text(_currentEmbeddingModel == model
                                        ? 'Loaded'
                                        : 'Load'),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Knowledge base
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Knowledge Base',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _knowledgeIdController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Document ID',
                                hintText: 'Enter a unique identifier',
                              ),
                              enabled:
                                  _isEmbeddingModelLoaded && !_isProcessing,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _knowledgeTextController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Document Content',
                                hintText:
                                    'Enter content to add to the knowledge base',
                              ),
                              maxLines: 3,
                              enabled:
                                  _isEmbeddingModelLoaded && !_isProcessing,
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed:
                                  _isEmbeddingModelLoaded && !_isProcessing
                                      ? _addToKnowledgeBase
                                      : null,
                              icon: const Icon(Icons.add),
                              label: const Text('Add to Knowledge Base'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(40),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Inference
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chat & Query',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _promptController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Prompt / Query',
                                hintText: 'Enter your prompt or question here',
                              ),
                              maxLines: 3,
                              enabled:
                                  (_isLlmLoaded || _isEmbeddingModelLoaded) &&
                                      !_isProcessing,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLlmLoaded && !_isProcessing
                                        ? _generateResponse
                                        : null,
                                    icon: const Icon(Icons.chat),
                                    label: const Text('Generate'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLlmLoaded &&
                                            _isEmbeddingModelLoaded &&
                                            !_isProcessing
                                        ? _generateWithContext
                                        : null,
                                    icon: const Icon(Icons.psychology),
                                    label: const Text('RAG'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isEmbeddingModelLoaded &&
                                            !_isProcessing
                                        ? _searchDocuments
                                        : null,
                                    icon: const Icon(Icons.search),
                                    label: const Text('Search'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text('Response:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.grey.shade50,
                              ),
                              constraints: const BoxConstraints(
                                minHeight: 100,
                              ),
                              child: SelectableText(
                                _response.isEmpty
                                    ? 'No response yet'
                                    : _response,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
