class AppSecrets {
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );

  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '',
  );
}
