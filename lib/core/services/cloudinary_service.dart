import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

class CloudinaryService {
  // Đã điền thông tin của bạn
  final cloudinary = CloudinaryPublic(
    'dpwfoguj5', 
    'forest_worker_image', 
    cache: false,
  );

  /// Hàm tải ảnh lên Cloudinary, hỗ trợ cả Web và Mobile
  Future<String?> uploadImage(XFile imageFile) async {
    try {
      CloudinaryResponse response;
      
      if (kIsWeb) {
        // Trên Web, đọc file dưới dạng Bytes
        final bytes = await imageFile.readAsBytes();
        response = await cloudinary.uploadFile(
          CloudinaryFile.fromByteData(
            ByteData.view(bytes.buffer),
            identifier: imageFile.name,
            resourceType: CloudinaryResourceType.Image,
          ),
        );
      } else {
        // Trên Mobile (Android/iOS), dùng đường dẫn file
        response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            imageFile.path,
            resourceType: CloudinaryResourceType.Image,
          ),
        );
      }

      return response.secureUrl; // Trả về link ảnh an toàn (HTTPS)
    } on CloudinaryException catch (e) {
      print('Lỗi Cloudinary: ${e.message}');
      print('Chi tiết: ${e.request}');
      return null;
    } catch (e) {
      print('Lỗi không xác định: $e');
      return null;
    }
  }
}
