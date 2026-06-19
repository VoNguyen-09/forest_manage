import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
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

  /// Remove Vietnamese diacritics to prevent font rendering issues
  static String _removeVietnameseDiacritics(String text) {
    const diacritics = {
      'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
      'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
      'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
      'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
      'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
      'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
      'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
      'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
      'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
      'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
      'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
      'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
      'đ': 'd',
      'À': 'A', 'Á': 'A', 'Ả': 'A', 'Ã': 'A', 'Ạ': 'A',
      'Ă': 'A', 'Ằ': 'A', 'Ắ': 'A', 'Ẳ': 'A', 'Ẵ': 'A', 'Ặ': 'A',
      'Â': 'A', 'Ầ': 'A', 'Ấ': 'A', 'Ẩ': 'A', 'Ẫ': 'A', 'Ậ': 'A',
      'È': 'E', 'É': 'E', 'Ẻ': 'E', 'Ẽ': 'E', 'Ẹ': 'E',
      'Ê': 'E', 'Ề': 'E', 'Ế': 'E', 'Ể': 'E', 'Ễ': 'E', 'Ệ': 'E',
      'Ì': 'I', 'Í': 'I', 'Ỉ': 'I', 'Ĩ': 'I', 'Ị': 'I',
      'Ò': 'O', 'Ó': 'O', 'Ỏ': 'O', 'Õ': 'O', 'Ọ': 'O',
      'Ô': 'O', 'Ồ': 'O', 'Ố': 'O', 'Ổ': 'O', 'Ỗ': 'O', 'Ộ': 'O',
      'Ơ': 'O', 'Ờ': 'O', 'Ớ': 'O', 'Ở': 'O', 'Ỡ': 'O', 'Ợ': 'O',
      'Ù': 'U', 'Ú': 'U', 'Ủ': 'U', 'Ũ': 'U', 'Ụ': 'U',
      'Ư': 'U', 'Ừ': 'U', 'Ứ': 'U', 'Ử': 'U', 'Ữ': 'U', 'Ự': 'U',
      'Ỳ': 'Y', 'Ý': 'Y', 'Ỷ': 'Y', 'Ỹ': 'Y', 'Ỵ': 'Y',
      'Đ': 'D',
    };
    
    return text.split('').map((char) => diacritics[char] ?? char).join('');
  }

  // ── Font cache ─────────────────────────────────────────────────────────────
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  // Use Courier as ultimate fallback (will be overridden by async loading)
  static pw.Font get regularFont => _regularFont ?? pw.Font.courier();
  static pw.Font get boldFont => _boldFont ?? pw.Font.courierBold();

  // Load Noto Sans font (best support for Vietnamese)
  static Future<pw.Font> _getRegularFont() async {
    if (_regularFont != null) return _regularFont!;
    
    final urls = [
      // NotoSans from Google Fonts (best for Vietnamese)
      'https://fonts.gstatic.com/s/notosans/v27/o-0IIpQlx3QUlC1A0MH-hefvfUZ5PNJWqEEn5g-b-FI.ttf',
      // Alternative: Roboto from Google Fonts
      'https://fonts.gstatic.com/s/roboto/v30/KFOmCnqEu92Fr1Mu4mxP.ttf',
      // jsDelivr mirrors
      'https://cdn.jsdelivr.net/npm/@fontsource/noto-sans@latest/files/noto-sans-vietnamese-400-normal.ttf',
    ];
    
    for (final url in urls) {
      try {
        print('⏳ Loading font from: $url');
        final response = await http.get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          try {
            _regularFont = pw.Font.ttf(response.bodyBytes.buffer.asByteData());
            print('✓ Font loaded: ${response.bodyBytes.length} bytes');
            return _regularFont!;
          } catch (e) {
            print('✗ Font parse failed: $e');
          }
        }
      } catch (e) {
        print('✗ Font download failed: $e');
      }
    }
    
    // Fallback to Courier
    _regularFont = pw.Font.courier();
    print('⚠ Using Courier fallback');
    return _regularFont!;
  }

  static Future<pw.Font> _getBoldFont() async {
    if (_boldFont != null) return _boldFont!;
    
    final urls = [
      // NotoSans Bold from Google Fonts
      'https://fonts.gstatic.com/s/notosans/v27/o-0NIpQlx3QUlC1A0MH-hefvfUZ5PNJWqEEn5g-b-FI.ttf',
      // Alternative: Roboto Bold
      'https://fonts.gstatic.com/s/roboto/v30/KFOlCnqEu92Fr1MmEU9fBBc-.ttf',
    ];
    
    for (final url in urls) {
      try {
        print('⏳ Loading bold font from: $url');
        final response = await http.get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          try {
            _boldFont = pw.Font.ttf(response.bodyBytes.buffer.asByteData());
            print('✓ Bold font loaded: ${response.bodyBytes.length} bytes');
            return _boldFont!;
          } catch (e) {
            print('✗ Bold font parse failed: $e');
          }
        }
      } catch (e) {
        print('✗ Bold font download failed: $e');
      }
    }
    
    // Fallback to Courier Bold
    _boldFont = pw.Font.courierBold();
    print('⚠ Using Courier Bold fallback');
    return _boldFont!;
  }

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
    // Load fonts
    _regularFont = await _getRegularFont();
    _boldFont = await _getBoldFont();
    
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => _buildHeader('Forest Project Summary Report'),
        footer: (ctx) => _buildFooter(ctx),
        build: (_) {
          // Build content inline to ensure fonts are properly initialized
          return [
            _sectionTitle('Project Information'),
            _infoTable([
              ['Project Name', _removeVietnameseDiacritics(project.projectName)],
              ['Province/District/Commune', '${project.province} / ${project.district} / ${project.commune}'],
              ['Forest Type', project.forestType],
              ['Main Tree Species', _removeVietnameseDiacritics(project.treeSpecies)],
              ['Year Planted', project.yearPlanted.toString()],
              ['Area', '${_numFmt.format(project.totalAreaHa)} ha'],
              ['Status', _projectStatusLabel(project.status)],
              ['Created Date', _dateFmt.format(project.createdAt)],
            ]),
            pw.SizedBox(height: 16),
            _sectionTitle('Forest Owner Information'),
            _infoTable([
              ['Owner Name', _removeVietnameseDiacritics(owner.ownerName)],
              ['Owner Code', owner.ownerCode],
              ['Type', _ownerTypeLabel(owner.type)],
              ['ID/Registration', owner.cccd],
              ['Address', owner.address],
              ['Phone', owner.phone],
              ['Email', owner.email],
            ]),
            if (carbonResult != null) ...[
              pw.SizedBox(height: 16),
              _sectionTitle('Carbon Results'),
              _infoTable([
                ['Total Biomass', '${_numFmt.format(carbonResult.totalBiomassKg)} kg'],
                ['Carbon Stock', '${_numFmt.format(carbonResult.carbonStockTon)} tC'],
                ['CO2 Equivalent', '${_numFmt.format(carbonResult.co2eTon)} tCO2e'],
                ['Calculation Date', _dateFmt.format(carbonResult.calculatedAt)],
              ]),
              if (carbonResult.breakdown.isNotEmpty) ...[
                pw.SizedBox(height: 16),
                _sectionTitle('Carbon Breakdown by Species'),
                _buildBreakdownTable(carbonResult.breakdown),
              ],
            ],
          ];
        },
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
    // Load fonts
    _regularFont = await _getRegularFont();
    _boldFont = await _getBoldFont();
    
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => _buildHeader('Forest Inventory Report'),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _sectionTitle('Project: ${_removeVietnameseDiacritics(project.projectName)}'),
          _infoTable([
            ['Province', project.province],
            ['Main Tree Species', _removeVietnameseDiacritics(project.treeSpecies)],
            ['Number of Plots', plots.length.toString()],
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
        _sectionTitle('Plot: ${_removeVietnameseDiacritics(plot.plotCode)}'),
        pw.Row(children: [
          pw.Text(
            'GPS: ${plot.gps.lat.toStringAsFixed(6)}, ${plot.gps.lng.toStringAsFixed(6)}  ',
            style: pw.TextStyle(font: regularFont),
          ),
          pw.Text(
            'Area: ${_numFmt.format(plot.areaSqm)} m2',
            style: pw.TextStyle(font: regularFont),
          ),
        ]),
        pw.SizedBox(height: 8),
        if (plot.trees.isEmpty)
          pw.Text(
            'No tree data.',
            style: pw.TextStyle(font: regularFont),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: ['Species', 'DBH (cm)', 'Height (m)', 'Quantity'],
            data: plot.trees.map((t) => [
              _removeVietnameseDiacritics(t.species),
              t.dbh.toString(),
              t.height.toString(),
              t.quantity.toString(),
            ]).toList(),
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontWeight: pw.FontWeight.bold,
              color: _white,
            ),
            cellStyle: pw.TextStyle(
              font: regularFont,
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
    // Load fonts
    _regularFont = await _getRegularFont();
    _boldFont = await _getBoldFont();
    
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => _buildHeader('Activity Log Report'),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _sectionTitle('Project: ${_removeVietnameseDiacritics(project.projectName)}'),
          _infoTable([
            ['Date Range', '${_dateFmt.format(from)} → ${_dateFmt.format(to)}'],
            ['Total Records', entries.length.toString()],
          ]),
          pw.SizedBox(height: 16),
          if (entries.isEmpty)
            pw.Text(
              'No activity records in this period.',
              style: pw.TextStyle(font: regularFont),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Work Type', 'Description', 'GPS (lat, lng)', 'Photos'],
              data: entries.map((e) => [
                _dateFmt.format(e.date),
                _removeVietnameseDiacritics(e.workType.label),
                _removeVietnameseDiacritics(e.description),
                '${e.gps.lat.toStringAsFixed(4)}, ${e.gps.lng.toStringAsFixed(4)}',
                e.photoUrls.length.toString(),
              ]).toList(),
              headerStyle: pw.TextStyle(
                font: boldFont,
                fontWeight: pw.FontWeight.bold,
                color: _white,
              ),
              cellStyle: pw.TextStyle(
                font: regularFont,
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
                'Forest Carbon Platform',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                title,
                style: pw.TextStyle(font: regularFont, fontSize: 12, color: _accentColor),
              ),
            ],
          ),
          pw.Text(
            'Export Date: ${_dateFmt.format(DateTime.now())}',
            style: pw.TextStyle(font: regularFont, fontSize: 10, color: PdfColors.grey600),
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
            'Forest Carbon Platform - Internal Document',
            style: pw.TextStyle(font: regularFont, fontSize: 9, color: PdfColors.grey500),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(font: regularFont, fontSize: 9, color: PdfColors.grey500),
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
          font: boldFont,
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: _primaryColor,
        ),
      ),
    );
  }

  pw.Widget _infoTable(List<List<String>> rows) {
    // Convert to format for TableHelper: [labels...] and [values...]
    final labels = rows.map((r) => r[0]).toList();
    final values = [rows.map((r) => r[1]).toList()];
    
    return pw.TableHelper.fromTextArray(
      headers: labels,
      data: values,
      headerStyle: pw.TextStyle(
        font: boldFont,
        fontWeight: pw.FontWeight.bold,
        color: _white,
        fontSize: 10,
      ),
      cellStyle: pw.TextStyle(
        font: regularFont,
        fontSize: 10,
      ),
      headerDecoration: const pw.BoxDecoration(color: _primaryColor),
      rowDecoration: const pw.BoxDecoration(color: _surfaceColor),
      oddRowDecoration: const pw.BoxDecoration(color: _bgColor),
      border: pw.TableBorder.all(color: _bgColor, width: 0.5),
    );
  }

  pw.Widget _buildBreakdownTable(List<CarbonBreakdownItem> items) {
    return pw.TableHelper.fromTextArray(
      headers: ['Species', 'DBH (cm)', 'H (m)', 'Qty', 'Biomass (kg)', 'Carbon (tC)', 'CO2e (tCO2e)'],
      data: items.map((b) => [
        _removeVietnameseDiacritics(b.species),
        b.dbh.toString(),
        b.height.toString(),
        b.quantity.toString(),
        _numFmt.format(b.biomassKg),
        _numFmt.format(b.carbonTon),
        _numFmt.format(b.co2eTon),
      ]).toList(),
      headerStyle: pw.TextStyle(
        font: boldFont,
        fontWeight: pw.FontWeight.bold,
        color: _white,
        fontSize: 9,
      ),
      cellStyle: pw.TextStyle(
        font: regularFont,
        fontSize: 9,
      ),
      headerDecoration: const pw.BoxDecoration(color: _accentColor),
      rowDecoration: const pw.BoxDecoration(color: _surfaceColor),
      oddRowDecoration: const pw.BoxDecoration(color: _bgColor),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _projectStatusLabel(ProjectStatus s) => switch (s) {
    ProjectStatus.draft     => 'Draft',
    ProjectStatus.surveying => 'Surveying',
    ProjectStatus.active    => 'Active',
    ProjectStatus.suspended => 'Suspended',
  };

  String _ownerTypeLabel(OwnerType t) => switch (t) {
    OwnerType.individual  => 'Individual',
    OwnerType.company     => 'Company',
    OwnerType.cooperative => 'Cooperative',
  };
}
