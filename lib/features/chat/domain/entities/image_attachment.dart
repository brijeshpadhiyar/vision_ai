import 'dart:convert';

import 'package:flutter/foundation.dart';

/// In-memory multimodal image attachment for Module 20 (Camera & Visual Intelligence).
///
/// Intentionally NOT serialized into SharedPreferences history to keep storage
/// lean and protect user photo privacy.
@immutable
class ImageAttachment {
  const ImageAttachment({
    required this.base64Data,
    this.mimeType = 'image/jpeg',
    this.filePath = '',
    this.label = 'Photo',
    this.byteLength = 0,
  });

  factory ImageAttachment.fromBytes(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
    String filePath = '',
    String label = 'Photo',
  }) {
    return ImageAttachment(
      base64Data: base64Encode(bytes),
      mimeType: mimeType,
      filePath: filePath,
      label: label,
      byteLength: bytes.length,
    );
  }

  final String base64Data;
  final String mimeType;
  final String filePath;
  final String label;
  final int byteLength;

  Uint8List decodeBytes() => base64Decode(base64Data);

  String get dataUri => 'data:$mimeType;base64,$base64Data';
}
