import 'dart:io';
import 'dart:typed_data';

import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/models/log_entry_model.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FieldLogPdfService {
  FieldLogPdfService._();
  static final FieldLogPdfService instance = FieldLogPdfService._();

  static const _primary = PdfColor.fromInt(0xFF1E3932);
  static const _tertiary = PdfColor.fromInt(0xFF006241);
  static const _neutral = PdfColor.fromInt(0xFFF2F0EB);
  static const _surface = PdfColor.fromInt(0xFFFBF8F0);

  Future<Uint8List> buildFieldLogPdf({
    required UserModel user,
    required ForestProjectModel project,
    required LogEntryModel entry,
    required List<File> photoFiles,
  }) async {
    pw.ThemeData? theme;
    try {
      final regularFont = await PdfGoogleFonts.notoSansRegular();
      final boldFont = await PdfGoogleFonts.notoSansBold();
      theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);
    } catch (_) {
      theme = pw.ThemeData.base();
    }

    final photos = <pw.MemoryImage>[];
    for (final file in photoFiles.take(10)) {
      try {
        photos.add(pw.MemoryImage(await file.readAsBytes()));
      } catch (_) {
        // Bỏ qua ảnh lỗi để phần nhật ký vẫn tạo được PDF.
      }
    }

    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _header(),
        footer: (context) => _footer(context),
        build: (context) => [
          _title('Nhật ký hình ảnh hiện trường'),
          pw.SizedBox(height: 12),
          _infoTable([
            ['Dự án', project.projectName],
            ['Forest worker', _displayName(user)],
            ['Email', user.email],
            ['Ngày ghi nhận', _formatDate(entry.date)],
            ['Loại công việc', entry.workType.label],
            [
              'GPS',
              '${entry.gps.lat.toStringAsFixed(6)}, ${entry.gps.lng.toStringAsFixed(6)}',
            ],
            ['Số ảnh', photos.length.toString()],
          ]),
          pw.SizedBox(height: 16),
          _section('Mô tả công việc'),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _surface,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: _neutral),
            ),
            child: pw.Text(
              entry.description,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.SizedBox(height: 16),
          _section('Hình ảnh hiện trường'),
          if (photos.isEmpty)
            pw.Text('Không có ảnh đính kèm.')
          else
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: photos
                  .map(
                    (image) => pw.Container(
                      width: 158,
                      height: 118,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _neutral),
                        borderRadius: pw.BorderRadius.circular(8),
                        color: _neutral,
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 8,
                        verticalRadius: 8,
                        child: pw.Image(image, fit: pw.BoxFit.contain),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _header() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _tertiary, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Forest Carbon Platform',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
          pw.Text(
            'Xuất ngày ${_formatDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _neutral)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Tài liệu tự động từ nhật ký forest worker',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.Text(
            'Trang ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _title(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 18,
        fontWeight: pw.FontWeight.bold,
        color: _primary,
      ),
    );
  }

  pw.Widget _section(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: _tertiary,
        ),
      ),
    );
  }

  pw.Widget _infoTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: _neutral, width: 0.8),
      columnWidths: const {
        0: pw.FixedColumnWidth(110),
        1: pw.FlexColumnWidth(),
      },
      children: rows
          .map(
            (row) => pw.TableRow(
              decoration: const pw.BoxDecoration(color: _surface),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    row[0],
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    row[1],
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  String _displayName(UserModel user) {
    return user.fullName.isNotEmpty ? user.fullName : user.email;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
