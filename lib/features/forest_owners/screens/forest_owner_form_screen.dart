import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/models/gps_point.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/shared/widgets/app_button.dart';
import 'package:forest_carbon_platform/shared/widgets/loading_overlay.dart';
import 'package:forest_carbon_platform/core/services/auth_service.dart';
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
  late TextEditingController _forestNameController;
  late TextEditingController _managementProvinceController;
  late TextEditingController _totalTreesController;
  late TextEditingController _cccdController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  OwnerType _selectedType = OwnerType.individual;
  bool _isLoading = false;
  File? _selectedAvatar;
  String? _avatarUrl;

  List<GpsPoint> _currentPolygon = [];
  double _currentArea = 0.0;
  double _currentPerimeter = 0.0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.owner?.ownerName ?? '');
    _codeController = TextEditingController(text: widget.owner?.ownerCode ?? '');
    _forestNameController = TextEditingController(text: widget.owner?.forestName ?? '');
    _managementProvinceController = TextEditingController(text: widget.owner?.managementProvince ?? '');
    _totalTreesController = TextEditingController(text: widget.owner != null ? widget.owner!.totalTrees.toString() : '');
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
      _currentPolygon = List.from(widget.owner!.polygon);
      _currentArea = widget.owner!.totalAreaHa;
      _currentPerimeter = widget.owner!.perimeter;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _forestNameController.dispose();
    _managementProvinceController.dispose();
    _totalTreesController.dispose();
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

  Future<void> _openMapForBoundary() async {
    final result = await context.push(
      AppRoutes.map,
      extra: {
        'isSelectingForForm': true,
        'initialPolygon': _currentPolygon,
      },
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _currentPolygon = result['polygon'] as List<GpsPoint>;
        _currentArea = result['area'] as double;
        _currentPerimeter = result['perimeter'] as double;
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
        forestName: _forestNameController.text.trim(),
        managementProvince: _managementProvinceController.text.trim(),
        type: _selectedType,
        cccd: _cccdController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        attachments: attachments,
        polygon: _currentPolygon,
        totalAreaHa: _currentArea,
        perimeter: _currentPerimeter,
        totalTrees: int.tryParse(_totalTreesController.text.replaceAll(',', '')) ?? 0,
        createdAt: widget.owner?.createdAt ?? DateTime.now(),
      );

      if (widget.owner == null) {
        await AuthService.instance.createUser(
          email: owner.email,
          password: '123456',
          fullName: owner.ownerName,
          phone: owner.phone,
          role: UserRole.forestOwner,
          ownerId: owner.id,
          ownerName: owner.ownerName,
          forestName: owner.forestName,
          managementProvince: owner.managementProvince,
          totalAreaHa: owner.totalAreaHa,
        );
        await ForestOwnerService.instance.addOwner(owner);
      } else {
        await ForestOwnerService.instance.updateOwner(owner);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.owner == null
                  ? 'Đã thêm chủ rừng và tạo tài khoản mặc định 123456.'
                  : 'Lưu thông tin thành công!',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_saveErrorMessage(e), style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
          ),
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
                        const SizedBox(height: AppSpacing.md),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _forestNameController,
                                decoration: const InputDecoration(labelText: 'Tên rừng', border: OutlineInputBorder()),
                                validator: (val) => val == null || val.isEmpty ? AppStrings.fieldRequired : null,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: _managementProvinceController,
                                decoration: const InputDecoration(labelText: 'Tỉnh/Thành quản lý', border: OutlineInputBorder()),
                                validator: (val) => val == null || val.isEmpty ? AppStrings.fieldRequired : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _totalTreesController,
                          decoration: const InputDecoration(labelText: 'Tổng số cây', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Ranh giới quản lý', style: Theme.of(context).textTheme.titleLarge),
                            ElevatedButton.icon(
                              onPressed: _openMapForBoundary,
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const Text('Vẽ bản đồ'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.tertiary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (_currentPolygon.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Đã vẽ ranh giới quản lý (${_currentPolygon.length} điểm)\nTổng diện tích: ${_currentArea.toStringAsFixed(2)} ha',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Vẽ vùng ranh giới trên bản đồ để xác định khu vực rừng mà chủ rừng này quản lý.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
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
                                decoration: const InputDecoration(
                                  labelText: 'Email đăng nhập',
                                  helperText: 'Tài khoản owner sẽ dùng email này, mật khẩu mặc định 123456',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (val) {
                                  final email = val?.trim() ?? '';
                                  if (email.isEmpty) return AppStrings.fieldRequired;
                                  if (!email.contains('@')) return AppStrings.invalidEmail;
                                  return null;
                                },
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

  String _saveErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'Email này đã có tài khoản Firebase Authentication.';
        case 'invalid-email':
          return 'Email không hợp lệ.';
        case 'weak-password':
          return 'Mật khẩu mặc định quá yếu theo cấu hình Firebase.';
        case 'operation-not-allowed':
          return 'Firebase Authentication chưa bật phương thức Email/Password.';
        default:
          return 'Không tạo được tài khoản owner: ${error.message ?? error.code}';
      }
    }
    return 'Lỗi: $error';
  }
}
