import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';

class LlmService {
  static const _modelFileName = 'gemma3-1b-q4.gguf';
  static const _modelUrl =
      'https://huggingface.co/bartowski/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf';

  LlamaParent? _llama;

  Future<String> _modelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${dir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return '${modelsDir.path}/$_modelFileName';
  }

  Future<bool> get isModelReady async {
    final path = await _modelPath();
    return File(path).existsSync();
  }

  /// Emits download progress from 0.0 to 1.0.
  /// Downloads to a .tmp file and renames on completion to avoid partial reads.
  Stream<double> downloadModel() async* {
    final path = await _modelPath();
    final tmpPath = '$path.tmp';

    final request = http.Request('GET', Uri.parse(_modelUrl));
    final response = await request.send();
    final total = response.contentLength ?? 0;

    final sink = File(tmpPath).openWrite();
    int received = 0;

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) yield received / total;
      }
    } finally {
      await sink.close();
    }

    await File(tmpPath).rename(path);
    yield 1.0;
  }

  Future<void> loadModel() async {
    final path = await _modelPath();
    final loadCmd = LlamaLoad(
      path: path,
      modelParams: ModelParams(),
      contextParams: ContextParams(),
      samplingParams: SamplerParams(),
    );
    _llama = LlamaParent(loadCmd);
    await _llama!.init();
  }

  /// Returns a stream of token strings for the given prompt.
  /// The model must be loaded via [loadModel] before calling this.
  Stream<String> generate(String prompt) {
    final controller = StreamController<String>();

    () async {
      try {
        final llama = _llama;
        if (llama == null) {
          throw StateError('Model not loaded. Call loadModel() first.');
        }

        final promptId = await llama.sendPrompt(prompt);
        final sub = llama.stream.listen(
          controller.add,
          onError: controller.addError,
        );

        await llama.waitForCompletion(promptId);
        await sub.cancel();
        await controller.close();
      } catch (e, st) {
        controller.addError(e, st);
        await controller.close();
      }
    }();

    return controller.stream;
  }

  Future<void> dispose() async {
    await _llama?.dispose();
    _llama = null;
  }
}
