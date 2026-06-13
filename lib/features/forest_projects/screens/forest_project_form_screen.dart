import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:uuid/uuid.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/shared/widgets/app_button.dart';
import 'package:forest_carbon_platform/shared/widgets/loading_overlay.dart';
import 'package:forest_carbon_platform/core/services/forest_project_service.dart';
import 'package:forest_carbon_platform/core/services/forest_owner_service.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';

class ForestProjectFormScreen extends StatefulWidget {
  final ForestProjectModel? project;

  const ForestProjectFormScreen({super.key, this.project});

  @override
  State<ForestProjectFormScreen> createState() => _ForestProjectFormScreenState();
}

class _ForestProjectFormScreenState extends State<ForestProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _forestTypeController;
  late TextEditingController _treeSpeciesController;
  late TextEditingController _yearController;
  late TextEditingController _provinceController;
  late TextEditingController _districtController;
  late TextEditingController _communeController;
  ProjectStatus _selectedStatus = ProjectStatus.draft;
  bool _isLoading = false;
  String? _selectedOwnerId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.projectName ?? '');
    _forestTypeController = TextEditingController(text: widget.project?.forestType ?? '');
    _treeSpeciesController = TextEditingController(text: widget.project?.treeSpecies ?? '');
    _yearController = TextEditingController(text: widget.project?.yearPlanted.toString() ?? DateTime.now().year.toString());
    _provinceController = TextEditingController(text: widget.project?.province ?? '');
    _districtController = TextEditingController(text: widget.project?.district ?? '');
    _communeController = TextEditingController(text: widget.project?.commune ?? '');
    if (widget.project != null) {
      _selectedStatus = widget.project!.status;
      _selectedOwnerId = widget.project!.ownerId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _forestTypeController.dispose();
    _treeSpeciesController.dispose();
    _yearController.dispose();
    _provinceController.dispose();
    _districtController.dispose();
    _communeController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOwnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn chủ rừng', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final project = ForestProjectModel(
        id: widget.project?.id ?? const Uuid().v4(),
        projectName: _nameController.text.trim(),
        ownerId: _selectedOwnerId!,
        province: _provinceController.text.trim(),
        district: _districtController.text.trim(),
        commune: _communeController.text.trim(),
        forestType: _forestTypeController.text.trim(),
        treeSpecies: _treeSpeciesController.text.trim(),
        yearPlanted: int.tryParse(_yearController.text.trim()) ?? DateTime.now().year,
        status: _selectedStatus,
        polygon: widget.project?.polygon ?? [],
        totalAreaHa: widget.project?.totalAreaHa ?? 0.0,
        perimeter: widget.project?.perimeter ?? 0.0,
        createdAt: widget.project?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.project == null) {
        await ForestProjectService.instance.addProject(project);
      } else {
        await ForestProjectService.instance.updateProject(project);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lưu dự án thành công!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e', style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.project != null;

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: Text(isEdit ? 'Chỉnh sửa dự án' : AppStrings.addProject),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: AppLoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thông tin dự án', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.md),
                        
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: AppStrings.projectName, border: OutlineInputBorder()),
                          validator: (val) => val == null || val.isEmpty ? AppStrings.fieldRequired : null,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        StreamBuilder<List<ForestOwnerModel>>(
                          stream: ForestOwnerService.instance.getOwnersStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            }
                            final owners = snapshot.data ?? [];
                            // Ensure selected ID exists in the list
                            if (_selectedOwnerId != null && !owners.any((o) => o.id == _selectedOwnerId)) {
                              _selectedOwnerId = null;
                            }
                            
                            return DropdownButtonFormField<String>(
                              value: _selectedOwnerId,
                              decoration: const InputDecoration(labelText: 'Chủ rừng', border: OutlineInputBorder()),
                              items: owners.map((o) => DropdownMenuItem(value: o.id, child: Text('${o.ownerCode} - ${o.ownerName}'))).toList(),
                              onChanged: (val) => setState(() => _selectedOwnerId = val),
                              validator: (val) => val == null ? AppStrings.fieldRequired : null,
                            );
                          }
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<ProjectStatus>(
                                value: _selectedStatus,
                                decoration: const InputDecoration(labelText: 'Trạng thái', border: OutlineInputBorder()),
                                items: ProjectStatus.values.map((status) {
                                  String label = '';
                                  switch(status) {
                                    case ProjectStatus.active: label = 'Đang hoạt động'; break;
                                    case ProjectStatus.surveying: label = 'Đang khảo sát'; break;
                                    case ProjectStatus.suspended: label = 'Tạm dừng'; break;
                                    case ProjectStatus.draft: label = 'Bản nháp'; break;
                                  }
                                  return DropdownMenuItem(value: status, child: Text(label));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedStatus = val);
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: _yearController,
                                decoration: const InputDecoration(labelText: AppStrings.yearPlanted, border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                validator: (val) => val == null || val.isEmpty ? AppStrings.fieldRequired : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _forestTypeController,
                                decoration: const InputDecoration(labelText: AppStrings.forestType, border: OutlineInputBorder()),
                                validator: (val) => val == null || val.isEmpty ? AppStrings.fieldRequired : null,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: _treeSpeciesController,
                                decoration: const InputDecoration(labelText: AppStrings.treeSpecies, border: OutlineInputBorder()),
                                validator: (val) => val == null || val.isEmpty ? AppStrings.fieldRequired : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Địa điểm & Ranh giới', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.md),
                        
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _provinceController,
                                decoration: const InputDecoration(labelText: 'Tỉnh/Thành phố', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: TextFormField(
                                controller: _districtController,
                                decoration: const InputDecoration(labelText: 'Quận/Huyện', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: TextFormField(
                                controller: _communeController,
                                decoration: const InputDecoration(labelText: 'Phường/Xã', border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.neutral,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.map, size: 48, color: AppColors.secondary),
                              const SizedBox(height: AppSpacing.sm),
                              const Text('Chưa có dữ liệu không gian', style: TextStyle(color: AppColors.secondary)),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text(AppStrings.uploadShapefile),
                                    onPressed: () {},
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.draw),
                                    label: const Text(AppStrings.drawPolygon),
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text(AppStrings.cancel, style: TextStyle(color: AppColors.secondary)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      AppPrimaryButton(
                        label: AppStrings.save,
                        onPressed: _saveForm,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
       ),
      ),
    );
  }
}
