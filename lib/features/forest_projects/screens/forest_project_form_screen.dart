import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/shared/widgets/app_button.dart';

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

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      // Mock save success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lưu thông tin dự án thành công!')),
      );
      context.pop();
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
    );
  }
}
