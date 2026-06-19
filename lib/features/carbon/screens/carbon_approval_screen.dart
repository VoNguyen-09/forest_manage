import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/carbon_result_model.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/core/services/auth_service.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/shared/widgets/loading_overlay.dart';
import 'package:forest_carbon_platform/features/carbon/widgets/carbon_result_card.dart';
import 'package:intl/intl.dart';

class CarbonApprovalScreen extends StatefulWidget {
  const CarbonApprovalScreen({super.key});

  @override
  State<CarbonApprovalScreen> createState() => _CarbonApprovalScreenState();
}

class _CarbonApprovalScreenState extends State<CarbonApprovalScreen> {
  final _db = FirestoreService.instance;

  List<ForestProjectModel> _projects = [];
  List<CarbonResultModel> _pendingResults = [];
  List<CarbonResultModel> _approvedResults = [];
  List<CarbonResultModel> _rejectedResults = [];

  bool _loading = false;
  bool _saving = false;

  final Set<String> _selectedResultIds = {};
  final Map<String, String> _rejectionReasons = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.instance.getCurrentUserModel();
      final projects = user?.role == UserRole.platformAdmin
          ? await _db.listForestProjects()
          : await _db.listForestProjects(ownerId: user?.ownerId);
      
      // Load all carbon results
      final allResults = await _db.streamAllCarbonResults().first;
      
      // Filter by owner's projects
      final projectIds = projects.map((p) => p.id).toSet();
      final relevantResults = allResults.where((r) => projectIds.contains(r.projectId)).toList();
      
      // Separate by status
      final pending = relevantResults.where((r) => r.status == CarbonApprovalStatus.pending).toList();
      final approved = relevantResults.where((r) => r.status == CarbonApprovalStatus.approvedByOwner).toList();
      final rejected = relevantResults.where((r) => r.status == CarbonApprovalStatus.rejectedByOwner).toList();
      
      // Sort by date descending
      pending.sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));
      approved.sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));
      rejected.sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));
      
      setState(() {
        _projects = projects;
        _pendingResults = pending;
        _approvedResults = approved;
        _rejectedResults = rejected;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  Future<void> _approveResults() async {
    if (_selectedResultIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất một kết quả để phê duyệt')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      for (final resultId in _selectedResultIds) {
        final result = _pendingResults.firstWhere((r) => r.id == resultId);
        final approvedResult = result.copyWith(
          status: CarbonApprovalStatus.approvedByOwner,
          approvedByOwnerAt: DateTime.now(),
        );
        await _db.saveCarbonResult(approvedResult);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã phê duyệt ${_selectedResultIds.length} kết quả'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() => _selectedResultIds.clear());
        _loadInitialData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi phê duyệt: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _rejectResult(String resultId) async {
    final reason = _rejectionReasons[resultId] ?? '';
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập lý do từ chối')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final result = _pendingResults.firstWhere((r) => r.id == resultId);
      final rejectedResult = result.copyWith(
        status: CarbonApprovalStatus.rejectedByOwner,
        rejectedByOwnerAt: DateTime.now(),
        ownerRejectionReason: reason,
      );
      await _db.saveCarbonResult(rejectedResult);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã từ chối kết quả'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadInitialData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi từ chối: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendToAdmin() async {
    if (_approvedResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có kết quả nào để gửi đến admin')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      for (final result in _approvedResults) {
        // Update status to approvedByAdmin (automatically sent)
        final adminApprovedResult = result.copyWith(
          status: CarbonApprovalStatus.approvedByAdmin,
          approvedByAdminAt: DateTime.now(),
        );
        await _db.saveCarbonResult(adminApprovedResult);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gửi ${_approvedResults.length} kết quả đến admin'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadInitialData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi gửi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Phê duyệt kết quả Carbon'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pending Results
                  _buildSection(
                    title: 'Chờ phê duyệt',
                    count: _pendingResults.length,
                    backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                    borderColor: AppColors.warning,
                    child: _pendingResults.isEmpty
                        ? _buildEmptyState('Không có kết quả chờ phê duyệt')
                        : _buildPendingList(),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Approved Results
                  _buildSection(
                    title: 'Đã phê duyệt',
                    count: _approvedResults.length,
                    backgroundColor: AppColors.success.withValues(alpha: 0.1),
                    borderColor: AppColors.success,
                    child: _approvedResults.isEmpty
                        ? _buildEmptyState('Không có kết quả nào được phê duyệt')
                        : _buildApprovedList(),
                  ),

                  if (_approvedResults.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: _saving ? null : _sendToAdmin,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Text('Gửi ${_approvedResults.length} kết quả đến Admin'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.tertiary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Rejected Results
                  if (_rejectedResults.isNotEmpty)
                    _buildSection(
                      title: 'Đã từ chối',
                      count: _rejectedResults.length,
                      backgroundColor: AppColors.error.withValues(alpha: 0.1),
                      borderColor: AppColors.error,
                      child: _buildRejectedList(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required int count,
    required Color backgroundColor,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: borderColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.secondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPendingList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._pendingResults.map((result) {
          final project = _projects.firstWhere(
            (p) => p.id == result.projectId,
            orElse: () => ForestProjectModel(
              id: '', projectName: 'Dự án không xác định', ownerId: '',
              province: '', district: '', commune: '', forestType: '',
              treeSpecies: '', yearPlanted: 0, status: ProjectStatus.draft,
              createdAt: DateTime.now(), updatedAt: DateTime.now(),
            ),
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildPendingResultCard(result, project),
          );
        }),
        if (_selectedResultIds.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _saving ? null : _approveResults,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.check_outlined),
            label: Text('Phê duyệt ${_selectedResultIds.length} kết quả'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPendingResultCard(CarbonResultModel result, ForestProjectModel project) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _selectedResultIds.contains(result.id),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedResultIds.add(result.id);
                    } else {
                      _selectedResultIds.remove(result.id);
                    }
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Dự án: ${project.projectName}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                DateFormat('dd/MM/yyyy - HH:mm').format(result.calculatedAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CarbonResultCard(result: result),
          const SizedBox(height: AppSpacing.md),
          ExpansionTile(
            title: Text(
              'Từ chối kết quả này?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Nhập lý do từ chối (bắt buộc)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _rejectionReasons[result.id] = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _rejectResult(result.id),
                      icon: const Icon(Icons.close_outlined),
                      label: const Text('Xác nhận từ chối'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _approvedResults.map((result) {
        final project = _projects.firstWhere(
          (p) => p.id == result.projectId,
          orElse: () => ForestProjectModel(
            id: '', projectName: 'Dự án không xác định', ownerId: '',
            province: '', district: '', commune: '', forestType: '',
            treeSpecies: '', yearPlanted: 0, status: ProjectStatus.draft,
            createdAt: DateTime.now(), updatedAt: DateTime.now(),
          ),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dự án: ${project.projectName}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy - HH:mm').format(result.calculatedAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                CarbonResultCard(result: result),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRejectedList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _rejectedResults.map((result) {
        final project = _projects.firstWhere(
          (p) => p.id == result.projectId,
          orElse: () => ForestProjectModel(
            id: '', projectName: 'Dự án không xác định', ownerId: '',
            province: '', district: '', commune: '', forestType: '',
            treeSpecies: '', yearPlanted: 0, status: ProjectStatus.draft,
            createdAt: DateTime.now(), updatedAt: DateTime.now(),
          ),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dự án: ${project.projectName}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy - HH:mm').format(result.calculatedAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                CarbonResultCard(result: result),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lý do từ chối:',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.ownerRejectionReason ?? 'Không có lý do',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
