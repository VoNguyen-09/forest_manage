import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:forest_carbon_platform/core/models/carbon_result_model.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/models/log_entry_model.dart';
import 'package:forest_carbon_platform/core/models/plot_data_model.dart';

/// PdfReportService — TV4
///
/// 3 loại báo cáo PDF:
///   a) Forest Summary — dự án + chủ rừng + carbon
///   b) Forest Inventory — bảng plot + cây
///   c) Activity Report — nhật ký hiện trường theo date range
///
/// Mỗi PDF có: header (logo + tiêu đề), bảng dữ liệu, footer số trang.
class PdfReportService {
  PdfReportService._();
  static final PdfReportService instance = PdfReportService._();

  // ── Color tokens ─────────────────────────────────────────────────────────
  static const _primaryColor  = PdfColor.fromInt(0xFF1E3932);
  static const _accentColor   = PdfColor.fromInt(0xFF006241);
  static const _bgColor       = PdfColor.fromInt(0xFFF2F0EB);
  static const _surfaceColor  = PdfColor.fromInt(0xFFFBF8F0);
  static const _white         = PdfColors.white;

  // ── Date formatter ────────────────────────────────────────────────────────
  static final _dateFmt = DateFormat('dd/MM/yyyy');
  static final _numFmt  = NumberFormat('#,##0.####');

  // ════════════════════════════════════════════════════════════════════════════
  // A) FOREST SUMMARY REPORT
  // ════════════════════════════════════════════════════════════════════════════

  /// Tạo PDF Báo cáo Tổng hợp Dự án Rừng.
  Future<void> printForestSummary({
    required ForestProjectModel project,
    required ForestOwnerModel owner,
    CarbonResultModel? carbonResult,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildForestSummaryPdf(
        project: project,
        owner: owner,
        carbonResult: carbonResult,
      ),
    );
  }

  Future<Uint8List> buildForestSummaryBytes({
    required ForestProjectModel project,
    required ForestOwnerModel owner,
    CarbonResultModel? carbonResult,
  }) => _buildForestSummaryPdf(
        project: project,
        owner: owner,
        carbonResult: carbonResult,
      );

  Future<Uint8List> _buildForestSummaryPdf({
    required ForestProjectModel project,
    required ForestOwnerModel owner,
    CarbonResultModel? carbonResult,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => _buildHeader('Báo cáo Tổng hợp Dự án Rừng'),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _sectionTitle('Thông tin Dự án'),
          _infoTable([
            ['Tên dự án', project.projectName],
            ['Tỉnh/Huyện/Xã', '${project.province} / ${project.district} / ${project.commune}'],
            ['Loại rừng', project.forestType],
            ['Loài cây chính', project.treeSpecies],
            ['Năm trồng', project.yearPlanted.toString()],
            ['Diện tích', '${_numFmt.format(project.totalAreaHa)} ha'],
            ['Trạng thái', _projectStatusLabel(project.status)],
            ['Ngày tạo', _dateFmt.format(project.createdAt)],
          ]),
          pw.SizedBox(height: 16),
          _sectionTitle('Thông tin Chủ rừng'),
          _infoTable([
            ['Tên chủ rừng', owner.ownerName],
            ['Mã chủ rừng', owner.ownerCode],
            ['Loại hình', _ownerTypeLabel(owner.type)],
            ['CCCD/GPKD', owner.cccd],
            ['Địa chỉ', owner.address],
            ['SĐT', owner.phone],
            ['Email', owner.email],
          ]),
          if (carbonResult != null) ...[
            pw.SizedBox(height: 16),
            _sectionTitle('Kết quả Carbon'),
            _infoTable([
              ['Tổng Biomass', '${_numFmt.format(carbonResult.totalBiomassKg)} kg'],
              ['Carbon Stock', '${_numFmt.format(carbonResult.carbonStockTon)} tC'],
              ['CO₂ Tương đương', '${_numFmt.format(carbonResult.co2eTon)} tCO₂e'],
              ['Ngày tính', _dateFmt.format(carbonResult.calculatedAt)],
            ]),
            if (carbonResult.breakdown.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              _sectionTitle('Chi tiết theo loài cây'),
              _buildBreakdownTable(carbonResult.breakdown),
            ],
          ],
        ],
      ),
    );

    return doc.save();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // B) FOREST INVENTORY REPORT
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> printInventoryReport({
    required ForestProjectModel project,
    required List<PlotDataModel> plots,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildInventoryPdf(project: project, plots: plots),
    );
  }

  Future<Uint8List> buildInventoryBytes({
    required ForestProjectModel project,
    required List<PlotDataModel> plots,
  }) => _buildInventoryPdf(project: project, plots: plots);

  Future<Uint8List> _buildInventoryPdf({
    required ForestProjectModel project,
    required List<PlotDataModel> plots,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => _buildHeader('Báo cáo Điều tra Rừng — Inventory'),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _sectionTitle('Dự án: ${project.projectName}'),
          _infoTable([
            ['Tỉnh', project.province],
            ['Loài cây chính', project.treeSpecies],
            ['Số ô mẫu', plots.length.toString()],
          ]),
          pw.SizedBox(height: 16),
          ...plots.map((plot) => _buildPlotSection(plot)),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _buildPlotSection(PlotDataModel plot) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Ô mẫu: ${plot.plotCode}'),
        pw.Row(children: [
          pw.Text('GPS: ${plot.gps.lat.toStringAsFixed(6)}, ${plot.gps.lng.toStringAsFixed(6)}  '),
          pw.Text('Diện tích: ${_numFmt.format(plot.areaSqm)} m²'),
        ]),
        pw.SizedBox(height: 8),
        if (plot.trees.isEmpty)
          pw.Text('Chưa có dữ liệu cây.')
        else
          pw.TableHelper.fromTextArray(
            headers: ['Loài cây', 'DBH (cm)', 'Chiều cao (m)', 'Số lượng'],
            data: plot.trees.map((t) => [
              t.species,
              t.dbh.toString(),
              t.height.toString(),
              t.quantity.toString(),
            ]).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: _white,
            ),
            headerDecoration: const pw.BoxDecoration(color: _accentColor),
            rowDecoration: const pw.BoxDecoration(color: _surfaceColor),
            oddRowDecoration: const pw.BoxDecoration(color: _bgColor),
          ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // C) ACTIVITY REPORT (Nhật ký hiện trường)
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> printActivityReport({
    required ForestProjectModel project,
    required List<LogEntryModel> entries,
    required DateTime from,
    required DateTime to,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildActivityPdf(
        project: project, entries: entries, from: from, to: to),
    );
  }

  Future<Uint8List> buildActivityBytes({
    required ForestProjectModel project,
    required List<LogEntryModel> entries,
    required DateTime from,
    required DateTime to,
  }) => _buildActivityPdf(project: project, entries: entries, from: from, to: to);

  Future<Uint8List> _buildActivityPdf({
    required ForestProjectModel project,
    required List<LogEntryModel> entries,
    required DateTime from,
    required DateTime to,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => _buildHeader('Báo cáo Nhật ký Hoạt động Hiện trường'),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _sectionTitle('Dự án: ${project.projectName}'),
          _infoTable([
            ['Khoảng thời gian', '${_dateFmt.format(from)} → ${_dateFmt.format(to)}'],
            ['Số bản ghi', entries.length.toString()],
          ]),
          pw.SizedBox(height: 16),
          if (entries.isEmpty)
            pw.Text('Không có nhật ký trong khoảng thời gian này.')
          else
            pw.TableHelper.fromTextArray(
              headers: ['Ngày', 'Loại công việc', 'Mô tả', 'GPS (lat, lng)', 'Ảnh'],
              data: entries.map((e) => [
                _dateFmt.format(e.date),
                e.workType.label,
                e.description,
                '${e.gps.lat.toStringAsFixed(4)}, ${e.gps.lng.toStringAsFixed(4)}',
                e.photoUrls.length.toString(),
              ]).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: _white,
              ),
              headerDecoration: const pw.BoxDecoration(color: _primaryColor),
              rowDecoration: const pw.BoxDecoration(color: _surfaceColor),
              oddRowDecoration: const pw.BoxDecoration(color: _bgColor),
              columnWidths: {
                0: const pw.FixedColumnWidth(60),
                1: const pw.FixedColumnWidth(80),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FixedColumnWidth(90),
                4: const pw.FixedColumnWidth(30),
              },
            ),
        ],
      ),
    );

    return doc.save();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SHARED PDF BUILDING BLOCKS
  // ════════════════════════════════════════════════════════════════════════════

  pw.Widget _buildHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _accentColor, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '🌿 Forest Carbon Platform',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                title,
                style: pw.TextStyle(fontSize: 12, color: _accentColor),
              ),
            ],
          ),
          pw.Text(
            'Ngày xuất: ${_dateFmt.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _bgColor)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Forest Carbon Platform — Tài liệu nội bộ',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
          pw.Text(
            'Trang ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: _primaryColor,
        ),
      ),
    );
  }

  pw.Widget _infoTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: _bgColor, width: 0.5),
      children: rows.map((row) => pw.TableRow(
        decoration: const pw.BoxDecoration(color: _surfaceColor),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              row[0],
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(row[1], style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      )).toList(),
    );
  }

  pw.Widget _buildBreakdownTable(List<CarbonBreakdownItem> items) {
    return pw.TableHelper.fromTextArray(
      headers: ['Loài', 'DBH (cm)', 'H (m)', 'SL', 'Biomass (kg)', 'Carbon (tC)', 'CO₂e (tCO₂e)'],
      data: items.map((b) => [
        b.species,
        b.dbh.toString(),
        b.height.toString(),
        b.quantity.toString(),
        _numFmt.format(b.biomassKg),
        _numFmt.format(b.carbonTon),
        _numFmt.format(b.co2eTon),
      ]).toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: _white,
        fontSize: 9,
      ),
      headerDecoration: const pw.BoxDecoration(color: _accentColor),
      cellStyle: const pw.TextStyle(fontSize: 9),
      rowDecoration: const pw.BoxDecoration(color: _surfaceColor),
      oddRowDecoration: const pw.BoxDecoration(color: _bgColor),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _projectStatusLabel(ProjectStatus s) => switch (s) {
    ProjectStatus.draft     => 'Nháp',
    ProjectStatus.surveying => 'Đang khảo sát',
    ProjectStatus.active    => 'Đang hoạt động',
    ProjectStatus.suspended => 'Tạm dừng',
  };

  String _ownerTypeLabel(OwnerType t) => switch (t) {
    OwnerType.individual  => 'Cá nhân',
    OwnerType.company     => 'Doanh nghiệp',
    OwnerType.cooperative => 'Hợp tác xã',
  };
}
