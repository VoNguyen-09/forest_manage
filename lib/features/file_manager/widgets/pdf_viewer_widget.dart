import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;

class PdfViewerWidget extends StatefulWidget {
  final String url;
  final String fileName;

  const PdfViewerWidget({
    required this.url,
    required this.fileName,
    super.key,
  });

  @override
  State<PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<PdfViewerWidget> {
  late Future<Uint8List> _pdfBytes;

  @override
  void initState() {
    super.initState();
    _pdfBytes = _loadPdf();
  }

  Future<Uint8List> _loadPdf() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('HTTP ${response.statusCode}');
      }
      return response.bodyBytes;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _pdfBytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Lỗi khi tải PDF: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text('Không có dữ liệu PDF'),
          );
        }

        return PdfPreview(
          build: (_) => snapshot.data!,
          pdfFileName: widget.fileName,
        );
      },
    );
  }
}
