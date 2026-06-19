// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Tải file về máy từ URL bất kỳ (kể cả cross-origin như Cloudinary).
/// Dùng thẻ <a> thay vì http.get để tránh lỗi CORS và 401 của Cloudinary.
Future<void> triggerDownload(String url, String filename) async {
  final anchor = html.AnchorElement(href: url)
    ..target = '_blank'
    ..setAttribute('download', filename.isEmpty ? 'document' : filename)
    ..style.display = 'none';

  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
}
