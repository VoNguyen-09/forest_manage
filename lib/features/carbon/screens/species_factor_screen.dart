import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/carbon_result_model.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/shared/widgets/confirm_dialog.dart';
import 'package:forest_carbon_platform/shared/widgets/empty_state.dart';
import 'package:forest_carbon_platform/shared/widgets/loading_overlay.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

/// Species Factor Configuration — chỉ Platform Admin mới truy cập được.
/// CRUD hệ số loài cây: Keo, Bạch đàn, Thông, ...
class SpeciesFactorScreen extends StatefulWidget {
  const SpeciesFactorScreen({super.key});

  @override
  State<SpeciesFactorScreen> createState() => _SpeciesFactorScreenState();
}

class _SpeciesFactorScreenState extends State<SpeciesFactorScreen> {
  final _db = FirestoreService.instance;
  List<SpeciesFactor> _factors = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadFactors();
  }

  Future<void> _loadFactors() async {
    setState(() => _loading = true);
    try {
      final factors = await _db.listSpeciesFactors();
      setState(() {
        _factors = factors;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.errorGeneral),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showEditDialog({SpeciesFactor? existing}) async {
    final result = await showDialog<SpeciesFactor>(
      context: context,
      builder: (_) => _SpeciesFactorDialog(existing: existing),
    );
    if (result != null) {
      setState(() => _loading = true);
      try {
        await _db.saveSpeciesFactor(result);
        await _loadFactors();
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.errorGeneral),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _delete(SpeciesFactor sf) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmDialog(
        title: 'Xóa hệ số loài',
        message: 'Bạn có chắc muốn xóa loài "${sf.speciesName}"?',
        confirmLabel: AppStrings.delete,
        cancelLabel: AppStrings.cancel,
        isDanger: true,
      ),
    );
    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await _db.deleteSpeciesFactor(sf.speciesId);
        await _loadFactors();
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.errorGeneral),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.speciesFactor),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadFactors,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showEditDialog(),
          icon: const Icon(Icons.add),
          label: Text(AppStrings.add),
          backgroundColor: AppColors.tertiary,
          foregroundColor: AppColors.onPrimary,
        ),
        body: _factors.isEmpty && !_loading
            ? AppEmptyState(
                title: 'Chưa có hệ số loài cây',
                subtitle: 'Thêm hệ số để sử dụng trong tính toán carbon.',
                icon: Icons.park_outlined,
                actionLabel: AppStrings.add,
                onAction: () => _showEditDialog(),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: _factors.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _SpeciesFactorTile(
                  factor: _factors[i],
                  onEdit: () => _showEditDialog(existing: _factors[i]),
                  onDelete: () => _delete(_factors[i]),
                ),
              ),
      ),
    );
  }
}

// ── Tile ────────────────────────────────────────────────────────────────────

class _SpeciesFactorTile extends StatelessWidget {
  final SpeciesFactor factor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SpeciesFactorTile({
    required this.factor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return AppCard(
      onTap: onEdit,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.tertiary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(Icons.park, color: AppColors.tertiary, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  factor.speciesName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Hệ số: ${factor.factor.toStringAsFixed(3)}  ·  Số cây: ${NumberFormat('#,###').format(factor.totalTreesCount)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Cập nhật: ${fmt.format(factor.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              factor.factor.toStringAsFixed(3),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.success, fontWeight: FontWeight.w700),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Dialog ──────────────────────────────────────────────────────────────────

class _SpeciesFactorDialog extends StatefulWidget {
  final SpeciesFactor? existing;
  const _SpeciesFactorDialog({this.existing});

  @override
  State<_SpeciesFactorDialog> createState() => _SpeciesFactorDialogState();
}

class _SpeciesFactorDialogState extends State<_SpeciesFactorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _factorCtrl;
  late final TextEditingController _treeCountCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.speciesName ?? '');
    _factorCtrl = TextEditingController(
        text: widget.existing?.factor.toString() ?? '');
    _treeCountCtrl = TextEditingController(
        text: widget.existing?.totalTreesCount.toString() ?? '0');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _factorCtrl.dispose();
    _treeCountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final factor = double.parse(_factorCtrl.text.trim());
    final treeCount = int.parse(_treeCountCtrl.text.trim());
    final sf = SpeciesFactor(
      speciesId: widget.existing?.speciesId ?? const Uuid().v4(),
      speciesName: _nameCtrl.text.trim(),
      factor: factor,
      totalTreesCount: treeCount,
      updatedBy: 'admin',
      updatedAt: DateTime.now(),
    );
    Navigator.of(context).pop(sf);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Chỉnh sửa hệ số loài' : 'Thêm loài cây mới'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Tên loài cây'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? AppStrings.fieldRequired : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _factorCtrl,
              decoration: const InputDecoration(
                labelText: 'Hệ số (ví dụ: 0.48)',
                hintText: '0.00 – 1.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return AppStrings.invalidNumber;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _treeCountCtrl,
              decoration: const InputDecoration(
                labelText: 'Số lượng cây',
                hintText: 'Ví dụ: 5000',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                final n = int.tryParse(v.trim());
                if (n == null || n < 0) return AppStrings.invalidNumber;
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.cancel),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(AppStrings.save),
        ),
      ],
    );
  }
}
