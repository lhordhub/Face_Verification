// camera_utils.dart

import 'package:camera/camera.dart';

/// Opens the front camera (or the first camera if there is no front one).
/// Throws a CameraException if permission is denied.
Future<CameraController> createFrontCameraController() async {
  final cameras = await availableCameras();
  if (cameras.isEmpty) {
    throw StateError('No camera found on this device.');
  }

  final camera = cameras.firstWhere(
    (c) => c.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );

  final controller = CameraController(
    camera,
    ResolutionPreset.medium, // small enough to upload quickly
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.jpeg,
  );
  await controller.initialize();

  try {
    await controller.setFlashMode(FlashMode.off);
  } catch (_) {
    // Some cameras (e.g. most front cameras) have no flash. Ignore.
  }
  return controller;
}
