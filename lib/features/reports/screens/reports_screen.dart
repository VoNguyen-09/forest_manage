import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/features/reports/services/pdf_report_service.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/shared/widgets/loading_overlay.dart';
import 'package:intl/intl.dart';

/// Reports Screen — TV4
/// Cho phép chọn loại báo cáo, chọn dự án/date range rồi xuất PDF.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = FirestoreService.instance;
  final _pdfSvc = PdfReportService.instance;

  List<ForestProjectModel> _projects = [];
  ForestProjectModel? _selectedProject;

  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();

  bool _loading = false;
  bool _exporting = false;

  int _selectedReport = 0; // 0=Summary, 1=Inventory, 2=Activity

  static const _reportTypes = [
    _ReportType(
      icon: Icons.summarize_outlined,
      title: 'Báo cáo Tổng hợp',
      subtitle: 'Thông tin dự án, chủ rừng, carbon',
    ),
    _ReportType(
      icon: Icons.list_alt_outlined,
      title: 'Báo cáo Điều tra rừng',
      subtitle: 'Bảng ô mẫu với DBH/Chiều cao/Số lượng',
    ),
    _ReportType(
      icon: Icons.event_note_outlined,
      title: 'Báo cáo Nhật ký Hoạt động',
      subtitle: 'Nhật ký hiện trường theo khoảng thời gian',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _loading = true);
    try {
      final projects = await _db.listForestProjects();
      setState(() {
        _projects = projects;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
    }
  }

  Future<void> _export() async {
    final project = _selectedProject;
    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn dự án')),
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      switch (_selectedReport) {
        case 0:
          final owner = await _db.getForestOwner(project.ownerId);
          final carbon = await _db.getLatestCarbonResult(project.id);
          await _pdfSvc.printForestSummary(
            project: project,
            owner: owner ?? ForestOwnerModel(
              id: project.ownerId,
              ownerCode: '—',
              ownerName: '—',
              type: OwnerType.individual,
              cccd: '—',
              address: '—',
              phone: '—',
              email: '—',
              createdAt: DateTime.now(),
            ),
            carbonResult: carbon,
          );
          break;
        case 1:
          final plots = await _db.listPlots(projectId: project.id);
          await _pdfSvc.printInventoryReport(project: project, plots: plots);
          break;
        case 2:
          final entries = await _db.listLogEntries(
            projectId: project.id,
            from: _from,
            to: _to,
          );
          await _pdfSvc.printActivityReport(
            project: project,
            entries: entries,
            from: _from,
            to: _to,
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xuất PDF: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        appBar: AppBar(title: Text(AppStrings.reports)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildReportTypeSelector(),
              const SizedBox(height: AppSpacing.md),
              _buildProjectSelector(),
              if (_selectedReport == 2) ...[
                const SizedBox(height: AppSpacing.md),
                _buildDateRangePicker(),
              ],
              const SizedBox(height: AppSpacing.lg),
              _buildExportButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportTypeSelector() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chọn loại báo cáo',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ...List.generate(_reportTypes.length, (i) {
            final rt = _reportTypes[i];
            final selected = _selectedReport == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedReport = i),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.tertiary.withValues(alpha: 0.1)
                        : AppColors.neutral,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? AppColors.tertiary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        rt.icon,
                        color: selected ? AppColors.tertiary : AppColors.secondary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rt.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: selected
                                        ? AppColors.tertiary
                                        : AppColors.primary,
                                  ),
                            ),
                            Text(
                              rt.subtitle,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle, color: AppColors.tertiary),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProjectSelector() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dự án', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<ForestProjectModel>(
            value: _selectedProject,
            decoration: const InputDecoration(labelText: 'Chọn dự án'),
            items: _projects
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.projectName, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedProject = v),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    final fmt = DateFormat('dd/MM/yyyy');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Khoảng thời gian', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: true),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('Từ: ${fmt.format(_from)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: false),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('Đến: ${fmt.format(_to)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return ElevatedButton.icon(
      onPressed: _exporting ? null : _export,
      icon: _exporting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.picture_as_pdf_outlined),
      label: Text(_exporting ? 'Đang xuất PDF...' : 'Xuất báo cáo PDF'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.tertiary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

class _ReportType {
  final IconData icon;
  final String title;
  final String subtitle;
  const _ReportType({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
