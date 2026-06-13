import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/shared/widgets/app_button.dart';
import 'package:forest_carbon_platform/shared/widgets/loading_overlay.dart';
import 'package:forest_carbon_platform/core/services/cloudinary_service.dart';
import 'package:forest_carbon_platform/core/services/forest_owner_service.dart';

class ForestOwnerFormScreen extends StatefulWidget {
  final ForestOwnerModel? owner;

  const ForestOwnerFormScreen({super.key, this.owner});

  @override
  State<ForestOwnerFormScreen> createState() => _ForestOwnerFormScreenState();
}

class _ForestOwnerFormScreenState extends State<ForestOwnerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _cccdController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  OwnerType _selectedType = OwnerType.individual;
  bool _isLoading = false;
  File? _selectedAvatar;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.owner?.ownerName ?? '');
    _codeController = TextEditingController(text: widget.owner?.ownerCode ?? '');
    _cccdController = TextEditingController(text: widget.owner?.cccd ?? '');
    _phoneController = TextEditingController(text: widget.owner?.phone ?? '');
    _emailController = TextEditingController(text: widget.owner?.email ?? '');
    _addressController = TextEditingController(text: widget.owner?.address ?? '');
    if (widget.owner != null) {
      _selectedType = widget.owner!.type;
      final avatarAttachment = widget.owner!.attachments.where((a) => a['type'] == 'avatar').firstOrNull;
      if (avatarAttachment != null) {
        _avatarUrl = avatarAttachment['url'];
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _cccdController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedAvatar = File(result.files.single.path!);
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? avatarUrl = _avatarUrl;
      if (_selectedAvatar != null) {
        avatarUrl = await CloudinaryService.instance.uploadImage(_selectedAvatar!);
      }

      List<Map<String, String>> attachments = List.from(widget.owner?.attachments ?? []);
      if (avatarUrl != null) {
        attachments.removeWhere((a) => a['type'] == 'avatar');
        attachments.add({'type': 'avatar', 'url': avatarUrl, 'name': 'avatar.jpg'});
      }

      final owner = ForestOwnerModel(
        id: widget.owner?.id ?? const Uuid().v4(),
        ownerCode: _codeController.text.trim(),
        ownerName: _nameController.text.trim(),
        type: _selectedType,
        cccd: _cccdController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        attachments: attachments,
        createdAt: widget.owner?.createdAt ?? DateTime.now(),
      );

      if (widget.owner == null) {
        await ForestOwnerService.instance.addOwner(owner);
      } else {
        await ForestOwnerService.instance.updateOwner(owner);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lưu thông tin thành công!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e', style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.owner != null;

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: Text(isEdit ? 'Chỉnh sửa chủ rừng' : AppStrings.addOwner),
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
                        Text('Thông tin cơ bản', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.md),
                        
                        // Avatar upload placeholder
                        Center(
                          child: Stack(
                            children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  backgroundImage: _selectedAvatar != null 
                                      ? FileImage(_selectedAvatar!) 
                                      : (_avatarUrl != null ? NetworkImage(_avatarUrl!) as ImageProvider : null),
                                  child: (_selectedAvatar == null && _avatarUrl == null)
                                      ? const Icon(Icons.person, size: 50, color: AppColors.primary)
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.tertiary,
                                    child: IconButton(
                                      icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                      onPressed: _pickAvatar,
                                    ),
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        DropdownButtonFormField<OwnerType>(
                          value: _selectedType,
                          decoration: const InputDecoration(labelText: AppStrings.ownerType, border: OutlineInputBorder()),
                          items: OwnerType.values.map((type) {
                            String label;
                            switch (type) {
                              case OwnerType.company: label = 'Doanh nghiệp'; break;
                              case OwnerType.cooperative: label = 'Hợp tác xã'; break;
                              case OwnerType.individual:
                              default: label = 'Cá nhân'; break;
                            }
                            return DropdownMenuItem(
                              value: type,
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedType = val);
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _codeController,
                                decoration: const InputDecoration(labelText: AppStrings.ownerCode, border: OutlineInputBorder()),
                                validator: (val) => val == null || val.isEmpty ? AppStrings.fieldRequired : null,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(labelText: AppStrings.ownerName, border: OutlineInputBorder()),
                                validator: (val) => val == null || val.isEmpty ? AppStrings.fieldRequired : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        TextFormField(
                          controller: _cccdController,
                          decoration: const InputDecoration(labelText: 'CCCD / Mã số thuế', border: OutlineInputBorder()),
                          validator: (val) => val == null || val.isEmpty ? AppStrings.fieldRequired : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thông tin liên hệ', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.md),
                        
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder()),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(labelText: AppStrings.email, border: OutlineInputBorder()),
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(labelText: 'Địa chỉ', border: OutlineInputBorder()),
                          maxLines: 3,
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
