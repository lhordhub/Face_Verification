// live_verify_screen.dart
//
// Near-live verification: keeps taking a picture with the front camera,
// sends it to the server, and shows the verdict plus the live gradient
// (Sobel) and edge (Canny) images returned by the server pipeline.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'camera_utils.dart';
import 'config.dart';
import 'reference_store.dart';

class LiveVerifyScreen extends StatefulWidget {
  const LiveVerifyScreen({super.key});

  @override
  State<LiveVerifyScreen> createState() => _LiveVerifyScreenState();
}

class _LiveVerifyScreenState extends State<LiveVerifyScreen> {
  CameraController? _controller;
  Map<String, dynamic>? _reference;
  String? _fatalError; // camera / missing reference
  String? _requestError; // temporary network problem

  bool _running = false;
  int _loopId = 0; // lets an old loop notice it has been replaced

  final List<double> _recentScores = [];
  bool _faceDetected = false;
  bool? _isMatch;
  double? _smoothScore;
  Uint8List? _edgeBytes;
  Uint8List? _gradientBytes;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final reference = await ReferenceStore.load();
    if (reference == null) {
      if (mounted) {
        setState(() => _fatalError =
            'No reference saved yet. Go back and set up your reference first.');
      }
      return;
    }

    try {
      final controller = await createFrontCameraController();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _reference = reference;
        _controller = controller;
      });
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _fatalError = 'Camera error: ${e.description ?? e.code}');
      }
    } catch (e) {
      if (mounted) setState(() => _fatalError = 'Camera error: $e');
    }
  }

  @override
  void dispose() {
    _running = false;
    _loopId++;
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      setState(() => _running = false);
      return;
    }
    final id = ++_loopId;
    setState(() {
      _running = true;
      _requestError = null;
    });
    _loop(id);
  }

  bool _stillCurrent(int id) => mounted && _running && id == _loopId;

  Future<void> _loop(int id) async {
    final controller = _controller;
    final reference = _reference;
    if (controller == null || reference == null) return;

    while (_stillCurrent(id)) {
      final started = DateTime.now();

      try {
        final shot = await controller.takePicture();
        final result = await ApiService.verify(shot.path, reference);
        try {
          await File(shot.path).delete();
        } catch (_) {}

        if (!_stillCurrent(id)) break;
        _applyResult(result);
      } catch (e) {
        if (!_stillCurrent(id)) break;
        setState(() {
          _requestError = e is ApiException
              ? e.message
              : e is CameraException
                  ? 'Camera error: ${e.description ?? e.code}'
                  : 'Could not reach the server.';
        });
        await Future.delayed(const Duration(seconds: 2));
      }

      final elapsed = DateTime.now().difference(started).inMilliseconds;
      final wait = AppConfig.frameIntervalMs - elapsed;
      if (wait > 0) await Future.delayed(Duration(milliseconds: wait));
    }
  }

  void _applyResult(Map<String, dynamic> result) {
    if (result['face_detected'] != true) {
      setState(() {
        _requestError = null;
        _faceDetected = false;
        _isMatch = null;
        _smoothScore = null;
        _recentScores.clear();
      });
      return;
    }

    final score = (result['score'] as num).toDouble();
    final threshold = (result['threshold'] as num).toDouble();

    _recentScores.add(score);
    if (_recentScores.length > AppConfig.smoothingFrames) {
      _recentScores.removeAt(0);
    }
    final smooth =
        _recentScores.reduce((a, b) => a + b) / _recentScores.length;

    setState(() {
      _requestError = null;
      _faceDetected = true;
      _smoothScore = smooth;
      _isMatch = smooth <= threshold;
      _edgeBytes = base64Decode(result['edge_image'] as String);
      _gradientBytes = base64Decode(result['gradient_image'] as String);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_fatalError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live verify')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_fatalError!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live verify')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Live verify')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1 / controller.value.aspectRatio,
                  child: CameraPreview(controller),
                ),
              ),
            ),
            _buildVerdict(),
            if (_requestError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_requestError!,
                    style: const TextStyle(color: Colors.red)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _thumb('Gradient (Sobel)', _gradientBytes),
                  _thumb('Edges (Canny)', _edgeBytes),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _toggle,
                  icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                  label: Text(_running ? 'Stop' : 'Start'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerdict() {
    String text;
    Color color;

    if (!_running) {
      text = 'Press Start';
      color = Colors.grey;
    } else if (!_faceDetected) {
      text = 'No face detected';
      color = Colors.orange;
    } else if (_isMatch == true) {
      text = 'MY FACE';
      color = Colors.green;
    } else {
      text = 'NOT MY FACE';
      color = Colors.red;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          if (_running && _faceDetected && _smoothScore != null)
            Text(
              'score ${_smoothScore!.toStringAsFixed(2)} '
              '(lower = closer to you)',
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _thumb(String label, Uint8List? bytes) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          color: Colors.black,
          child: bytes == null
              ? const SizedBox.shrink()
              : Image.memory(
                  bytes,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.none,
                  fit: BoxFit.cover,
                ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
