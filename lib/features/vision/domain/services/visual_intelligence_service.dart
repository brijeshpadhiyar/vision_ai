import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'package:vision_ai/features/chat/domain/entities/image_attachment.dart';

/// Provides [VisualIntelligenceService] for Module 20 (Camera & Visual Intelligence).
final visualIntelligenceServiceProvider = Provider<VisualIntelligenceService>((
  ref,
) {
  return VisualIntelligenceService();
});

/// Handles cross-OEM Android camera capture & Photo Picker (`image_picker`)
/// plus offline on-device OCR (`google_mlkit_text_recognition`).
class VisualIntelligenceService {
  VisualIntelligenceService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Captures a photo from the device camera, resized to max 1024px JPEG.
  Future<ImageAttachment?> capturePhoto() =>
      _pick(ImageSource.camera, label: 'Camera Photo');

  /// Picks an image from the Android Photo Picker / Gallery, resized to max 1024px JPEG.
  Future<ImageAttachment?> pickFromGallery() =>
      _pick(ImageSource.gallery, label: 'Gallery Photo');

  Future<ImageAttachment?> _pick(
    ImageSource source, {
    required String label,
  }) async {
    final xFile = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 82,
    );
    if (xFile == null) return null;
    final bytes = await xFile.readAsBytes();
    if (bytes.isEmpty) return null;
    return ImageAttachment.fromBytes(
      bytes,
      mimeType: 'image/jpeg',
      filePath: xFile.path,
      label: xFile.name.isNotEmpty ? xFile.name : label,
    );
  }

  /// Extracts text offline from an image file using Google ML Kit Text Recognition.
  Future<String> extractTextOffline(String imagePath) async {
    if (imagePath.trim().isEmpty) return '';
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text.trim();
    } catch (_) {
      return '';
    } finally {
      await recognizer.close();
    }
  }
}
