import 'dart:async';
import 'package:flutter/material.dart';
import 'services/llm_service.dart';
import 'services/llm_context_service.dart';

class _ChatMessage {
  final bool isUser;
  final String text;
  _ChatMessage({required this.isUser, required this.text});
  _ChatMessage copyWith({String? text}) =>
      _ChatMessage(isUser: isUser, text: text ?? this.text);
}

enum _ModelState { checking, notDownloaded, downloading, downloaded, loading, ready, error }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _llm = LlmService();
  final _contextService = LlmContextService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  _ModelState _modelState = _ModelState.checking;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  final List<_ChatMessage> _messages = [];
  bool _isGenerating = false;
  StreamSubscription<String>? _tokenSub;

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  Future<void> _checkModel() async {
    setState(() => _modelState = _ModelState.checking);
    final ready = await _llm.isModelReady;
    if (!mounted) return;
    setState(() => _modelState = ready ? _ModelState.downloaded : _ModelState.notDownloaded);
  }

  Future<void> _downloadModel() async {
    setState(() {
      _modelState = _ModelState.downloading;
      _downloadProgress = 0.0;
    });
    try {
      await for (final p in _llm.downloadModel()) {
        if (!mounted) return;
        setState(() => _downloadProgress = p);
      }
      if (!mounted) return;
      setState(() => _modelState = _ModelState.downloaded);
    } catch (e, st) {
      debugPrint('Model download failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _modelState = _ModelState.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadModel() async {
    setState(() => _modelState = _ModelState.loading);
    try {
      await _llm.loadModel();
      if (!mounted) return;
      setState(() => _modelState = _ModelState.ready);
    } catch (e, st) {
      debugPrint('Model load failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _modelState = _ModelState.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _deleteAndRetryDownload() async {
    await _llm.deleteModel();
    if (!mounted) return;
    setState(() {
      _modelState = _ModelState.notDownloaded;
      _errorMessage = null;
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isGenerating) return;

    _inputController.clear();
    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
      _messages.add(_ChatMessage(isUser: false, text: ''));
      _isGenerating = true;
    });
    _scrollToBottom();

    try {
      final context = await _contextService.buildContext();
      final prompt =
          '<start_of_turn>user\n$context\n\nQuestion: $text<end_of_turn>\n<start_of_turn>model\n';

      _tokenSub = _llm.generate(prompt).listen(
        (token) {
          if (!mounted) return;
          setState(() {
            final last = _messages.last;
            _messages[_messages.length - 1] = last.copyWith(text: last.text + token);
          });
          _scrollToBottom();
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _messages[_messages.length - 1] =
                _ChatMessage(isUser: false, text: 'Error: $e');
            _isGenerating = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _isGenerating = false);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages[_messages.length - 1] =
            _ChatMessage(isUser: false, text: 'Error: $e');
        _isGenerating = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    _llm.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AI Advisor', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        automaticallyImplyLeading: false,
      ),
      body: switch (_modelState) {
        _ModelState.checking => const Center(child: CircularProgressIndicator()),
        _ModelState.notDownloaded => _buildDownloadPrompt(),
        _ModelState.downloading => _buildDownloadProgress(),
        _ModelState.downloaded => _buildLoadPrompt(),
        _ModelState.loading => _buildLoadingScreen(),
        _ModelState.ready => _buildChat(),
        _ModelState.error => _buildError(),
      },
    );
  }

  Widget _buildDownloadPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined, color: Colors.blueAccent, size: 64),
            const SizedBox(height: 16),
            const Text(
              'AI Model Required',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Download Gemma 3 1B (~800 MB) once to enable your spending advisor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _downloadModel,
              icon: const Icon(Icons.download),
              label: const Text('Download Model'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadProgress() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Downloading… ${(_downloadProgress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _downloadProgress),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 48),
          const SizedBox(height: 12),
          const Text('Model downloaded.', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadModel,
            icon: const Icon(Icons.memory),
            label: const Text('Load Model'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading model into memory…', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'An error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkModel,
              child: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _deleteAndRetryDownload,
              child: const Text('Delete & Re-download Model'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChat() {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    'Ask anything about your spending.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) => _buildBubble(_messages[i]),
                ),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.blueAccent : Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
        ),
        child: msg.text.isEmpty && !isUser
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(msg.text, style: const TextStyle(color: Colors.white, height: 1.4)),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: !_isGenerating,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ask about your spending…',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.grey[800],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isGenerating ? null : _sendMessage,
            icon: const Icon(Icons.send_rounded),
            color: Colors.blueAccent,
            style: IconButton.styleFrom(backgroundColor: Colors.grey[800]),
          ),
        ],
      ),
    );
  }
}
