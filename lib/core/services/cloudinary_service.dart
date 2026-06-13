import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../config/secrets.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CloudinaryService — Dùng chung cho TV2 & TV3
//  Đặt tại: lib/core/services/cloudinary_service.dart
//
//  Cách dùng (singleton):
//    final url = await CloudinaryService.instance.uploadImage(imageFile);
//    final url = await CloudinaryService.instance.uploadFile(docFile, folder: 'owners');
// ════════════════════════════════════════════════════════════════════════════

class CloudinaryService {
  CloudinaryService._();
  static final CloudinaryService instance = CloudinaryService._();

  CloudinaryPublic? _cloudinary;

  CloudinaryPublic get _client {
    _cloudinary ??= CloudinaryPublic(
      AppSecrets.cloudinaryCloudName,
      AppSecrets.cloudinaryUploadPreset,
      cache: false,
    );
    return _cloudinary!;
  }

  // ── Upload 1 ảnh (tự nén < 1MB) ─────────────────────────────────────────
  /// Upload ảnh lên Cloudinary. Tự nén về dưới 1MB trước khi upload.
  /// - [folder]: Thư mục lưu trên Cloudinary (mặc định: 'field_photos').
  /// - Trả về `secureUrl` (https://res.cloudinary.com/...).
  Future<String> uploadImage(
    File file, {
    String folder = 'field_photos',
  }) async {
    try {
      // Nén nếu ảnh > 1MB
      File uploadFile = file;
      final compressed = await _compressImage(file);
      if (compressed != null) uploadFile = compressed;

      final response = await _client.uploadFile(
        CloudinaryFile.fromFile(
          uploadFile.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      // Xóa file nén tạm nếu có
      if (compressed != null) {
        try {
          await compressed.delete();
        } catch (_) {}
      }

      return response.secureUrl;
    } on CloudinaryException catch (e) {
      debugPrint('[CloudinaryService] uploadImage thất bại: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[CloudinaryService] uploadImage lỗi: $e');
      rethrow;
    }
  }

  // ── Upload nhiều ảnh (tối đa 10) ─────────────────────────────────────────
  /// Upload danh sách ảnh. Tối đa 10 ảnh theo quy định dự án.
  Future<List<String>> uploadImages(
    List<File> files, {
    String folder = 'field_photos',
  }) async {
    if (files.length > 10) {
      throw ArgumentError('Tối đa 10 ảnh mỗi lần upload. Hiện tại: ${files.length}');
    }
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadImage(file, folder: folder);
      urls.add(url);
    }
    return urls;
  }

  // ── Upload tài liệu (PDF, DOCX, KML, GeoJSON, v.v.) ─────────────────────
  /// Upload tài liệu tổng quát.
  /// - [folder]: Thư mục lưu (mặc định: 'documents').
  /// - Trả về `secureUrl`.
  Future<String> uploadFile(
    File file, {
    String folder = 'documents',
  }) async {
    try {
      final ext = p.extension(file.path).toLowerCase();
      final resourceType = _getResourceType(ext);

      final response = await _client.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder: folder,
          resourceType: resourceType,
        ),
      );

      return response.secureUrl;
    } on CloudinaryException catch (e) {
      debugPrint('[CloudinaryService] uploadFile thất bại: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[CloudinaryService] uploadFile lỗi: $e');
      rethrow;
    }
  }

  // ── Nội bộ: Nén ảnh xuống < 1MB ─────────────────────────────────────────
  Future<File?> _compressImage(File file) async {
    const maxBytes = 1 * 1024 * 1024; // 1 MB
    final fileSize = await file.length();

    if (fileSize <= maxBytes) return null; // Đã đủ nhỏ

    try {
      final dir = await getTemporaryDirectory();
      final ext = p.extension(file.path).toLowerCase();
      final isPng = ext == '.png';
      final format = isPng ? CompressFormat.png : CompressFormat.jpeg;
      final targetPath =
          '${dir.path}/cld_${DateTime.now().millisecondsSinceEpoch}$ext';

      // Tính quality phù hợp (giới hạn 20–85)
      final quality = ((maxBytes / fileSize) * 90).clamp(20.0, 85.0).toInt();

      final xfile = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: quality,
        format: format,
      );

      if (xfile == null) return null;

      final resultFile = File(xfile.path);
      final resultSize = await resultFile.length();

      // Nếu vẫn > 1MB, nén thêm 1 lần với quality=40
      if (resultSize > maxBytes) {
        final targetPath2 =
            '${dir.path}/cld2_${DateTime.now().millisecondsSinceEpoch}$ext';
        final xfile2 = await FlutterImageCompress.compressAndGetFile(
          xfile.path,
          targetPath2,
          quality: 40,
          format: format,
        );
        try {
          await resultFile.delete();
        } catch (_) {}
        return xfile2 != null ? File(xfile2.path) : null;
      }

      return resultFile;
    } catch (e) {
      debugPrint('[CloudinaryService] Nén ảnh thất bại, dùng ảnh gốc: $e');
      return null;
    }
  }

  // ── Nội bộ: Xác định resource type theo phần mở rộng ────────────────────
  CloudinaryResourceType _getResourceType(String ext) {
    const imageExts = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.heif'};
    const videoExts = {'.mp4', '.mov', '.avi', '.mkv', '.wmv'};
    if (imageExts.contains(ext)) return CloudinaryResourceType.Image;
    if (videoExts.contains(ext)) return CloudinaryResourceType.Video;
    return CloudinaryResourceType.Raw; // PDF, DOCX, KML, GeoJSON, ...
  }
}
