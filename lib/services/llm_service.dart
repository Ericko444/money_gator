import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';

class LlmService {
  static const _modelFileName = 'gemma3-1b-q4.gguf';
  // bartowski/gemma-3-1b-it-GGUF now requires HF auth (401) and was silently
  // being "downloaded" as its ~29-byte error body. unsloth's repo is public.
  static const _modelUrl =
      'https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf';

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

  Future<void> deleteModel() async {
    final path = await _modelPath();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Emits download progress from 0.0 to 1.0.
  /// Downloads to a .tmp file and renames on completion to avoid partial reads.
  /// Throws if the stream ends before the expected byte count is reached,
  /// so a dropped connection can never masquerade as a complete model file.
  Stream<double> downloadModel() async* {
    final path = await _modelPath();
    final tmpPath = '$path.tmp';

    final request = http.Request('GET', Uri.parse(_modelUrl));
    final response = await request.send();
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception(
          'Download failed: HTTP ${response.statusCode} — $body');
    }
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

    if (total > 0 && received != total) {
      await File(tmpPath).delete();
      throw Exception(
          'Download incomplete: received $received of $total bytes.');
    }

    await File(tmpPath).rename(path);
    yield 1.0;
  }

  Future<void> loadModel() async {
    final path = await _modelPath();
    final loadCmd = LlamaLoad(
      path: path,
      // nGpuLayers=0: force CPU-only. Android has no working GPU backend here,
      // and leaving the package default (99) stalls model load indefinitely
      // trying to init a GPU backend that never comes up.
      modelParams: ModelParams()..nGpuLayers = 0,
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
