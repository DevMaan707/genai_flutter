import 'package:flutter/material.dart';
import 'dart:async';
import 'package:genai_flutter/genai_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenAI Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: ThemeMode.system,
      home: const GenAILabHome(),
    );
  }
}

class ModelItem {
  final String name;
  final String displayName;
  final String type;
  final String size;
  bool isLoaded;
  String? downloadUrl;

  ModelItem({
    required this.name,
    required this.displayName,
    required this.type,
    required this.size,
    this.isLoaded = false,
    this.downloadUrl,
  });
}

class GenAILabHome extends StatefulWidget {
  const GenAILabHome({Key? key}) : super(key: key);

  @override
  State<GenAILabHome> createState() => _GenAILabHomeState();
}

class _GenAILabHomeState extends State<GenAILabHome>
    with WidgetsBindingObserver {
  final _genai = GenaiFlutter();
  bool _isInitialized = false;
  bool _isLlmLoaded = false;
  bool _isEmbeddingModelLoaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = 'Initializing...';
  List<ModelItem> _llmModels = [];
  List<ModelItem> _embeddingModels = [];
  ModelItem? _currentLlmModel;
  ModelItem? _currentEmbeddingModel;
  int _selectedTab = 0;

  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _knowledgeTextController =
      TextEditingController();
  final TextEditingController _knowledgeIdController = TextEditingController();
  String _response = '';
  bool _isProcessing = false;

  // Available models for download
  final List<ModelItem> _availableLlmModels = [
    ModelItem(
      name: 'phi-2.Q4_K_M.gguf',
      displayName: 'Phi-2 (Q4_K_M)',
      type: 'LLM',
      size: '1.8 GB',
      downloadUrl:
          'https://huggingface.co/TheBloke/Phi-2-GGUF/resolve/main/phi-2.Q4_K_M.gguf',
    ),
    ModelItem(
      name: 'llama-2-7b.Q4_0.gguf',
      displayName: 'LLaMA 2-7B (Q4)',
      type: 'LLM',
      size: '3.8 GB',
      downloadUrl:
          'https://huggingface.co/TheBloke/Llama-2-7B-GGUF/resolve/main/llama-2-7b.Q4_0.gguf',
    ),
    ModelItem(
      name: 'mistral-7b.Q4_0.gguf',
      displayName: 'Mistral 7B (Q4)',
      type: 'LLM',
      size: '3.9 GB',
      downloadUrl:
          'https://huggingface.co/TheBloke/Mistral-7B-v0.1-GGUF/resolve/main/mistral-7b-v0.1.Q4_0.gguf',
    ),
  ];

  final List<ModelItem> _availableEmbeddingModels = [
    ModelItem(
      name: 'all-MiniLM-L6-v2.bin',
      displayName: 'MiniLM-L6-v2',
      type: 'Embedding',
      size: '80 MB',
      downloadUrl:
          'https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/pytorch_model.bin',
    ),
    ModelItem(
      name: 'e5-small-v2.bin',
      displayName: 'E5-Small-v2',
      type: 'Embedding',
      size: '134 MB',
      downloadUrl:
          'https://huggingface.co/intfloat/e5-small-v2/resolve/main/pytorch_model.bin',
    ),
  ];

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
      _unloadModels();
    }
  }

  Future<void> _unloadModels() async {
    if (_isLlmLoaded) {
      await _genai.genaiService.unloadModel();
      setState(() {
        _isLlmLoaded = false;
        _currentLlmModel = null;
        _updateModelLoadedStatus();
      });
    }

    if (_isEmbeddingModelLoaded) {
      await _genai.genaiService.unloadEmbeddingModel();
      setState(() {
        _isEmbeddingModelLoaded = false;
        _currentEmbeddingModel = null;
        _updateModelLoadedStatus();
      });
    }
  }

  Future<void> _initializePlugin() async {
    try {
      await _genai.initialize();
      await _refreshModelLists();

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Ready to download or load models';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing: $e';
      });
    }
  }

  void _updateModelLoadedStatus() {
    // Update LLM models loaded status
    for (var model in _llmModels) {
      model.isLoaded = _currentLlmModel?.name == model.name;
    }

    // Update embedding models loaded status
    for (var model in _embeddingModels) {
      model.isLoaded = _currentEmbeddingModel?.name == model.name;
    }
  }

  Future<void> _refreshModelLists() async {
    try {
      final downloadedLlmNames =
          await _genai.modelManager.listDownloadedModels();
      final downloadedEmbNames =
          await _genai.modelManager.listDownloadedEmbeddingModels();

      // Create model items from downloaded models
      List<ModelItem> llmModels = [];
      for (String name in downloadedLlmNames) {
        // Try to find in available models first
        var model = _availableLlmModels.firstWhere(
          (m) => m.name == name,
          orElse: () => ModelItem(
            name: name,
            displayName: name.split('.').first,
            type: 'LLM',
            size: 'Unknown',
          ),
        );

        // Set loaded status
        model.isLoaded = _currentLlmModel?.name == name;
        llmModels.add(model);
      }

      List<ModelItem> embModels = [];
      for (String name in downloadedEmbNames) {
        // Try to find in available models first
        var model = _availableEmbeddingModels.firstWhere(
          (m) => m.name == name,
          orElse: () => ModelItem(
            name: name,
            displayName: name.split('.').first,
            type: 'Embedding',
            size: 'Unknown',
          ),
        );

        // Set loaded status
        model.isLoaded = _currentEmbeddingModel?.name == name;
        embModels.add(model);
      }

      setState(() {
        _llmModels = llmModels;
        _embeddingModels = embModels;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error refreshing models: $e';
      });
    }
  }

  Future<void> _downloadModel(ModelItem model) async {
    if (_isDownloading || model.downloadUrl == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Starting ${model.type} download: ${model.displayName}';
    });

    try {
      final downloadFunction = model.type == 'LLM'
          ? _genai.modelManager.downloadModel
          : _genai.modelManager.downloadEmbeddingModel;

      await downloadFunction(
        url: model.downloadUrl!,
        modelName: model.name,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
            _statusMessage =
                'Downloading ${model.displayName}: ${(progress * 100).toStringAsFixed(1)}%';
          });
        },
      );

      setState(() {
        _statusMessage = '${model.displayName} downloaded successfully';
      });

      await _refreshModelLists();
    } catch (e) {
      setState(() {
        _statusMessage = 'Download failed: $e';
      });
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _loadLlmModel(ModelItem model) async {
    setState(() {
      _statusMessage = 'Loading ${model.displayName}...';
      _isProcessing = true;
    });

    try {
      final modelsDir = await _genai.modelManager.modelsDir;
      final modelPath = '${modelsDir.path}/${model.name}';

      final success = await _genai.genaiService.loadModel(modelPath);
      setState(() {
        _isLlmLoaded = success;
        _currentLlmModel = success ? model : null;
        _statusMessage = success
            ? '${model.displayName} loaded successfully'
            : 'Failed to load ${model.displayName}';
        _updateModelLoadedStatus();
      });
    } catch (e) {
      setState(() {
        _isLlmLoaded = false;
        _currentLlmModel = null;
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _loadEmbeddingModel(ModelItem model) async {
    setState(() {
      _statusMessage = 'Loading ${model.displayName}...';
      _isProcessing = true;
    });

    try {
      final modelsDir = await _genai.modelManager.embeddingsDir;
      final modelPath = '${modelsDir.path}/${model.name}';

      final success = await _genai.genaiService.loadEmbeddingModel(modelPath);
      setState(() {
        _isEmbeddingModelLoaded = success;
        _currentEmbeddingModel = success ? model : null;
        _statusMessage = success
            ? '${model.displayName} loaded successfully'
            : 'Failed to load ${model.displayName}';
        _updateModelLoadedStatus();
      });

      if (success) {
        await _genai.genaiService.createVectorDatabase(dbName: 'default_db');
      }
    } catch (e) {
      setState(() {
        _isEmbeddingModelLoaded = false;
        _currentEmbeddingModel = null;
        _statusMessage = 'Error: $e';
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
      _statusMessage = 'Processing with ${_currentLlmModel?.displayName}...';
    });

    try {
      final response = await _genai.genaiService.generateResponse(
        prompt: prompt,
        maxTokens: 256,
        temperature: 0.7,
      );

      setState(() {
        _response = response;
        _statusMessage = 'Response generated';
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _statusMessage = 'Failed to generate';
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
        _statusMessage = 'Please provide both content and ID';
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
        _statusMessage = success ? 'Added to knowledge base' : 'Failed to add';
      });

      if (success) {
        _knowledgeTextController.clear();
        _knowledgeIdController.clear();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
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
      _response = 'Searching context...';
      _statusMessage =
          'Processing RAG with ${_currentLlmModel?.displayName}...';
    });

    try {
      final response = await _genai.genaiService.generateResponseWithContext(
        query: query,
        maxTokens: 512,
        temperature: 0.7,
      );

      setState(() {
        _response = response;
        _statusMessage = 'RAG response generated';
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
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
        _statusMessage = 'Please enter a search query';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _response = 'Searching...';
      _statusMessage =
          'Searching documents with ${_currentEmbeddingModel?.displayName}...';
    });

    try {
      final docs = await _genai.genaiService.searchSimilarDocuments(
        query: query,
        topK: 5,
      );

      if (docs.isEmpty) {
        setState(() {
          _response = 'No similar documents found in your knowledge base';
          _statusMessage = 'Search completed';
        });
      } else {
        final buffer = StringBuffer();
        buffer.writeln('Found ${docs.length} similar documents:');
        buffer.writeln();

        for (int i = 0; i < docs.length; i++) {
          final doc = docs[i];
          buffer.writeln('📄 Document ${i + 1}: ${doc['id']}');
          buffer.writeln(
              '⭐ Score: ${(doc['score'] as double).toStringAsFixed(4)}');
          buffer.writeln('📝 Content: ${doc['content']}');
          buffer.writeln('─' * 40);
        }

        setState(() {
          _response = buffer.toString();
          _statusMessage = 'Search completed';
        });
      }
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _statusMessage = 'Search failed';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // UI Components
  Widget _buildModelCard(
      ModelItem model, Future<void> Function(ModelItem) onLoad) {
    final theme = Theme.of(context);
    final isLoaded = model.isLoaded;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLoaded
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withOpacity(0.3),
          width: isLoaded ? 2 : 1,
        ),
      ),
      color: isLoaded
          ? theme.colorScheme.primaryContainer.withOpacity(0.5)
          : theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  model.type == 'LLM' ? Icons.smart_toy : Icons.schema,
                  color: isLoaded
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isLoaded
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        model.size,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLoaded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      isLoaded || _isProcessing ? null : () => onLoad(model),
                  icon: Icon(isLoaded ? Icons.check : Icons.play_arrow),
                  label: Text(isLoaded ? 'Active' : 'Load Model'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLoaded
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondaryContainer,
                    foregroundColor: isLoaded
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSecondaryContainer,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableModelCard(ModelItem model) {
    final theme = Theme.of(context);
    final alreadyDownloaded = (_llmModels.any((m) => m.name == model.name) ||
        _embeddingModels.any((m) => m.name == model.name));

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  model.type == 'LLM' ? Icons.smart_toy : Icons.schema,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              model.type,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            model.size,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (alreadyDownloaded)
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check),
                    label: const Text('Downloaded'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed:
                        _isDownloading ? null : () => _downloadModel(model),
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.tertiary,
                      foregroundColor: theme.colorScheme.onTertiary,
                      elevation: 0,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSection(String title, List<ModelItem> models,
      Future<void> Function(ModelItem) onLoad) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          if (models.isEmpty)
            Card(
              elevation: 0,
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 36,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No models downloaded',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Check available models in the Download tab',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: models.length,
              itemBuilder: (context, index) {
                return _buildModelCard(models[index], onLoad);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadableModelsList() {
    final llmModels = _availableLlmModels;
    final embeddingModels = _availableEmbeddingModels;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Download section title
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 16.0, top: 8.0),
            child: Text(
              'Available Models',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ),

          if (_isDownloading) ...[
            Card(
              elevation: 0,
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Downloading: ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surface
                          .withOpacity(0.4),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                            .withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // LLM Models section
          const Padding(
            padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              'LLM Models',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...llmModels.map((model) => _buildAvailableModelCard(model)).toList(),

          const SizedBox(height: 24),

          // Embedding Models section
          const Padding(
            padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              'Embedding Models',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...embeddingModels
              .map((model) => _buildAvailableModelCard(model))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildModelsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'My Models'),
              Tab(text: 'Download'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
            dividerColor: Colors.transparent,
          ),
          Expanded(
            child: TabBarView(
              children: [
                // My Models Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildModelSection(
                          'LLM Models',
                          _llmModels,
                          (ModelItem model) async =>
                              await _loadLlmModel(model)),
                      _buildModelSection(
                          'Embedding Models',
                          _embeddingModels,
                          (ModelItem model) async =>
                              await _loadEmbeddingModel(model)),
                    ],
                  ),
                ),

                // Download Tab
                _buildDownloadableModelsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowledgeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 1,
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Knowledge Base',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add documents to your knowledge base to use in RAG responses',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _knowledgeIdController,
                    decoration: InputDecoration(
                      labelText: 'Document ID',
                      hintText: 'Enter a unique identifier',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      prefixIcon: const Icon(Icons.fingerprint_outlined),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    enabled: _isEmbeddingModelLoaded && !_isProcessing,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _knowledgeTextController,
                    decoration: InputDecoration(
                      labelText: 'Document Content',
                      hintText: 'Enter content to add to the knowledge base',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 12.0, top: 12.0),
                        child: Icon(Icons.description_outlined),
                      ),
                      alignLabelWithHint: true,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 8,
                    minLines: 5,
                    enabled: _isEmbeddingModelLoaded && !_isProcessing,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isEmbeddingModelLoaded && !_isProcessing
                        ? _addToKnowledgeBase
                        : null,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Add to Knowledge Base'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_isEmbeddingModelLoaded) ...[
            const SizedBox(height: 36),
            Center(
              child: Card(
                elevation: 0,
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withOpacity(0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 42,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Embedding Model Required',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please load an embedding model to use the knowledge base features',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onErrorContainer
                              .withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedTab = 0; // Switch to Models tab
                          });
                        },
                        icon: const Icon(Icons.model_training),
                        label: const Text('Go to Models'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.onErrorContainer,
                          foregroundColor:
                              Theme.of(context).colorScheme.errorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_isEmbeddingModelLoaded) ...[
            Card(
              elevation: 0,
              color: Theme.of(context)
                  .colorScheme
                  .secondaryContainer
                  .withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.tips_and_updates,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tips',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Add multiple documents for better results\n'
                      '• Each document should have a unique ID\n'
                      '• Use the Search button in Chat tab to verify your documents\n'
                      '• Try the RAG button to generate responses based on your knowledge',
                      style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      margin: const EdgeInsets.all(0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            TextField(
              controller: _promptController,
              decoration: InputDecoration(
                hintText: 'Enter your prompt or question here',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                prefixIcon: Icon(
                  Icons.chat_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              enabled:
                  (_isLlmLoaded || _isEmbeddingModelLoaded) && !_isProcessing,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Generate',
                    Icons.chat_bubble_outline,
                    _isLlmLoaded && !_isProcessing ? _generateResponse : null,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'RAG',
                    Icons.psychology_outlined,
                    _isLlmLoaded && _isEmbeddingModelLoaded && !_isProcessing
                        ? _generateWithContext
                        : null,
                    Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'Search',
                    Icons.search,
                    _isEmbeddingModelLoaded && !_isProcessing
                        ? _searchDocuments
                        : null,
                    Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        // Response area
        Expanded(
          child: _isProcessing
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _response.isEmpty ? 'Processing...' : _response,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_isLlmLoaded && !_isEmbeddingModelLoaded) ...[
                        const SizedBox(height: 40),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.model_training_outlined,
                                size: 64,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withOpacity(0.7),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No models loaded',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground
                                      .withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Please load at least one model from the Models tab',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground
                                      .withOpacity(0.6),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedTab = 0; // Switch to Models tab
                                  });
                                },
                                icon: const Icon(Icons.model_training),
                                label: const Text('Go to Models'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_response.isEmpty) ...[
                        const SizedBox(height: 40),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withOpacity(0.7),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Ready for your prompt',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground
                                      .withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Type a message and press Generate',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground
                                      .withOpacity(0.6),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_isLlmLoaded && _currentLlmModel != null) ...[
                                const SizedBox(height: 24),
                                Chip(
                                  label: Text(
                                    'Using: ${_currentLlmModel!.displayName}',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        // Display the response
                        Card(
                          elevation: 0,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.2),
                                      radius: 16,
                                      child: Icon(
                                        Icons.smart_toy,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _currentLlmModel?.displayName ?? 'AI',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.content_copy_outlined,
                                          size: 20),
                                      onPressed: () {
                                        // Could add clipboard functionality here
                                      },
                                      tooltip: 'Copy to clipboard',
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withOpacity(0.7),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 12),
                                SelectableText(
                                  _response,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // User prompt display
                        Card(
                          elevation: 0,
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .tertiary
                                          .withOpacity(0.2),
                                      radius: 14,
                                      child: Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .tertiary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Your prompt:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .tertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _promptController.text,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),

        // Input box and buttons
        _buildChatInput(),
      ],
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, VoidCallback? onPressed, Color color) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        disabledBackgroundColor:
            Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        disabledForegroundColor:
            Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text('GenAI Lab'),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh models',
                  onPressed: _refreshModelLists,
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () {
                    // Settings dialog could be added here
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('App Information'),
                        content: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('GenAI Lab v1.0.0'),
                            SizedBox(height: 8),
                            Text(
                                'A Flutter application for on-device AI inference'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ];
        },
        body: !_isInitialized
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Status bar
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isProcessing
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.7),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isProcessing ? Icons.sync : Icons.info_outline,
                          color: _isProcessing
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: TextStyle(
                              color: _isProcessing
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              fontWeight: _isProcessing
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isLlmLoaded || _isEmbeddingModelLoaded) ...[
                          const SizedBox(width: 16),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isLlmLoaded)
                                Chip(
                                  label: const Text('LLM'),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (_isLlmLoaded && _isEmbeddingModelLoaded)
                                const SizedBox(width: 4),
                              if (_isEmbeddingModelLoaded)
                                Chip(
                                  label: const Text('EMB'),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                  ),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Main content area
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTab,
                      children: [
                        _buildModelsTab(),
                        _buildChatTab(),
                        _buildKnowledgeTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _isInitialized
          ? NavigationBar(
              selectedIndex: _selectedTab,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedTab = index;
                });
              },
              elevation: 0,
              height: 65,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.model_training_outlined),
                  selectedIcon: Icon(Icons.model_training),
                  label: 'Models',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: 'Chat',
                ),
                NavigationDestination(
                  icon: Icon(Icons.psychology_outlined),
                  selectedIcon: Icon(Icons.psychology),
                  label: 'Knowledge',
                ),
              ],
            )
          : null,
    );
  }
}
