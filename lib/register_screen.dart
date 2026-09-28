// register_screen.dart
//
// Takes several selfies with the phone camera, sends them to the server,
// and saves the returned reference on the phone.

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'camera_utils.dart';
import 'config.dart';
import 'reference_store.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  CameraController? _controller;
  String? _cameraError;

  final List<String> _photoPaths = [];
  bool _uploading = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final controller = await createFrontCameraController();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _cameraError = 'Camera error: ${e.description ?? e.code}');
      }
    } catch (e) {
      if (mounted) setState(() => _cameraError = 'Camera error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _uploading) return;
    try {
      final shot = await controller.takePicture();
      if (!mounted) return;
      setState(() {
        _photoPaths.add(shot.path);
        _message = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Could not take the photo: $e';
        _messageIsError = true;
      });
    }
  }

  void _clear() {
    setState(() {
      _photoPaths.clear();
      _message = null;
    });
  }

  Future<void> _buildReference() async {
    if (_photoPaths.length < 2 || _uploading) return;

    setState(() {
      _uploading = true;
      _messageIsError = false;
      _message = 'Uploading... the server may need up to a minute to wake up.';
    });

    try {
      final result = await ApiService.register(_photoPaths);
      final reference = Map<String, dynamic>.from(result['reference'] as Map);
      await ReferenceStore.save(reference);

      final used = result['num_used'];
      final skipped = (result['skipped'] as List).length;
      final note = skipped > 0 ? ' ($skipped skipped: no face found)' : '';

      if (!mounted) return;
      setState(() {
        _messageIsError = false;
        _message = 'Reference saved from $used photo(s)$note.';
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messageIsError = true;
        _message = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messageIsError = true;
        _message = 'Could not reach the server. It may still be waking up, '
            'try again in a moment.';
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final target = AppConfig.referencePhotoCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Set up my reference')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Take $target selfies facing the camera in good, even light. '
                'Vary slightly: a small head tilt, a slight smile, a bit '
                'closer or farther.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: Center(
                child: _cameraError != null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_cameraError!,
                            style: const TextStyle(color: Colors.red)),
                      )
                    : (controller == null || !controller.value.isInitialized)
                        ? const CircularProgressIndicator()
                        : AspectRatio(
                            aspectRatio: 1 / controller.value.aspectRatio,
                            child: CameraPreview(controller),
                          ),
              ),
            ),
            SizedBox(
              height: 72,
              child: _photoPaths.isEmpty
                  ? const Center(child: Text('No photos yet'))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _photoPaths.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_photoPaths[i]),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _messageIsError ? Colors.red : Colors.green.shade700,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          (controller == null || _uploading) ? null : _capture,
                      icon: const Icon(Icons.camera),
                      label: Text('Capture (${_photoPaths.length}/$target)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed:
                        (_photoPaths.isEmpty || _uploading) ? null : _clear,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Clear photos',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: (_photoPaths.length < 2 || _uploading)
                          ? null
                          : _buildReference,
                      child: _uploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save reference'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
