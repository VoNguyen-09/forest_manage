class AppSecrets {
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );

  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '',
  );

  /// Preset unsigned dành riêng cho tài liệu (PDF, DOCX, GeoJSON...).
  /// Nếu không khai báo, app sẽ dùng [cloudinaryUploadPreset] để tương thích
  /// với cấu hình chỉ có một preset.
  static const String cloudinaryDocumentUploadPreset = String.fromEnvironment(
    'CLOUDINARY_DOCUMENT_UPLOAD_PRESET',
    defaultValue: '',
  );
}
