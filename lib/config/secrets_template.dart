// ════════════════════════════════════════════════════════════════════════════
//  secrets_template.dart — Sao chép file này thành secrets.dart rồi điền thật
//  KHÔNG commit secrets.dart lên Git (đã thêm vào .gitignore)
// ════════════════════════════════════════════════════════════════════════════

/// Sao chép file này thành `lib/config/secrets.dart` và điền thông tin thật.
/// Hướng dẫn lấy thông tin:
/// 1. Vào https://cloudinary.com và đăng nhập
/// 2. Cloud Name: hiển thị ở góc trên bên phải Dashboard
/// 3. Upload Preset: Settings → Upload → Add upload preset → Mode: Unsigned
/// 4. Với PDF/DOCX, preset phải cho phép các định dạng tài liệu cần dùng.
///    Có thể tạo preset unsigned riêng và truyền bằng
///    `CLOUDINARY_DOCUMENT_UPLOAD_PRESET` khi build/run.
class AppSecrets {
  AppSecrets._();

  // ── Cloudinary ────────────────────────────────────────────────────────────
  /// Cloud Name lấy từ Cloudinary Dashboard
  static const String cloudinaryCloudName = 'YOUR_CLOUD_NAME_HERE';

  /// Upload Preset phải ở chế độ "Unsigned"
  static const String cloudinaryUploadPreset = 'YOUR_UPLOAD_PRESET_HERE';

  /// Không bắt buộc. Dùng preset unsigned riêng cho PDF/DOCX/GeoJSON.
  /// Nếu để trống, ứng dụng dùng `cloudinaryUploadPreset` bên trên.
  static const String cloudinaryDocumentUploadPreset = '';
}
