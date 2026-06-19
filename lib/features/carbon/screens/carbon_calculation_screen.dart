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

class CarbonCalculationScreen extends StatefulWidget {
  const CarbonCalculationScreen({super.key});

  @override
  State<CarbonCalculationScreen> createState() => _CarbonCalculationScreenState();
}

class _CarbonCalculationScreenState extends State<CarbonCalculationScreen> {
  final _db = FirestoreService.instance;
  final _formKey = GlobalKey<FormState>();

  List<ForestProjectModel> _projects = [];
  ForestProjectModel? _selectedProject;
  UserRole? _userRole;

  bool _loading = false;
  bool _saving = false;

  // Track selected results for sending to admin
  final Set<String> _selectedResultIds = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.instance.getCurrentUserModel();
      _userRole = user?.role;
      final projects = user?.role == UserRole.platformAdmin
          ? await _db.listForestProjects()
          : await _db.listForestProjects(ownerId: user?.ownerId);
      setState(() {
        _projects = projects;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _sendSelectedToAdmin() async {
    if (_selectedResultIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một kết quả để gửi'),
          backgroundColor: AppColors.secondary,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Get all results for selected project
      final allResults = await _db.streamCarbonResultsForProject(_selectedProject!.id).first;
      
      // Update selected results with approvedByOwner status
      for (final resultId in _selectedResultIds) {
        final result = allResults.firstWhere((r) => r.id == resultId);
        final updatedResult = result.copyWith(
          status: CarbonApprovalStatus.approvedByOwner,
          approvedByOwnerAt: DateTime.now(),
        );
        await _db.saveCarbonResult(updatedResult);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã gửi ${_selectedResultIds.length} kết quả cho admin'),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() => _selectedResultIds.clear());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi gửi: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        appBar: AppBar(title: Text(AppStrings.carbon)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInputCard(),
                    const SizedBox(height: AppSpacing.lg),
                    if (_selectedProject != null) ...[
                      _buildHistory(_selectedProject!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Card chọn dự án ───────────────────────────────────────────────────
  Widget _buildInputCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chọn dự án',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),

          // Chọn dự án
          DropdownButtonFormField<ForestProjectModel>(
            value: _selectedProject,
            decoration: const InputDecoration(labelText: 'Dự án rừng'),
            items: _projects
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.projectName, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            validator: (v) => v == null ? 'Vui lòng chọn dự án' : null,
            onChanged: (p) {
              setState(() {
                _selectedProject = p;
              });
            },
          ),

          if (_selectedProject != null) ...[
            const SizedBox(height: AppSpacing.md),
            // Hiển thị loài cây của dự án để tham khảo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.park_outlined, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Loài cây: ${_selectedProject!.treeSpecies.isNotEmpty ? _selectedProject!.treeSpecies : "Chưa xác định"}  •  '
                    'Diện tích: ${_selectedProject!.totalAreaHa.toStringAsFixed(2)} ha',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistory(ForestProjectModel project) {
    return StreamBuilder<List<CarbonResultModel>>(
      stream: _db.streamCarbonResultsForProject(project.id),
      builder: (context, snapshot) {
        var results = snapshot.data ?? [];
        
        // Admin only sees results that have been approved by owner and sent
        if (_userRole == UserRole.platformAdmin) {
          results = results.where((r) => r.status == CarbonApprovalStatus.approvedByOwner).toList();
        }
        
        if (results.isEmpty) {
          return AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Chưa có dữ liệu tính toán nào từ Forest Worker.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _userRole == UserRole.platformAdmin
                  ? 'Kết quả được chủ rừng gửi'
                  : 'Lịch sử tính toán từ Forest Worker',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            ...results.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _userRole == UserRole.platformAdmin
                      ? _buildResultViewOnly(r)
                      : _buildResultWithSelection(r),
                )),
            if (results.isNotEmpty && _userRole != UserRole.platformAdmin) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _selectedResultIds.isEmpty ? null : _sendSelectedToAdmin,
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
                label: Text('Gửi ${_selectedResultIds.length} kết quả cho Admin'),
                style: FilledButton.styleFrom(
                  backgroundColor: _selectedResultIds.isEmpty
                      ? Colors.grey
                      : AppColors.tertiary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildResultWithSelection(CarbonResultModel result) {
    final formattedDate =
        DateFormat('dd/MM/yyyy - HH:mm').format(result.calculatedAt);
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
                  'Tính toán lúc: $formattedDate',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          CarbonResultCard(result: result),
        ],
      ),
    );
  }

  Widget _buildResultViewOnly(CarbonResultModel result) {
    final formattedDate =
        DateFormat('dd/MM/yyyy - HH:mm').format(result.calculatedAt);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tính toán lúc: $formattedDate',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          CarbonResultCard(result: result),
        ],
      ),
    );
  }
}

