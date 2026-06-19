import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/core/services/forest_owner_service.dart';
import 'package:forest_carbon_platform/core/services/local_account_store.dart';
import 'package:forest_carbon_platform/shared/widgets/app_button.dart';

class AccountFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const AccountFormDialog({super.key, this.initialData});

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late UserRole _selectedRole;
  String? _selectedOwnerId;
  ForestOwnerModel? _selectedOwner;
  bool _isLoading = false;

  final List<UserRole> _roles = const [
    UserRole.forestOwner,
    UserRole.forestWorker,
  ];

  bool get _isEdit => widget.initialData != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData?['name'] ?? '');
    _emailController = TextEditingController(text: widget.initialData?['email'] ?? '');
    _passwordController = TextEditingController(text: widget.initialData?['password'] ?? '');
    _selectedRole = widget.initialData?['role'] as UserRole? ?? UserRole.forestOwner;
    _selectedOwnerId = widget.initialData?['ownerId'] as String?;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _syncOwnerEmail() {
    if (_isEdit || _selectedRole != UserRole.forestOwner) return;
    final name = (_selectedOwner?.ownerName ?? _nameController.text).trim();
    if (name.isEmpty) return;
    _emailController.text = LocalAccountStore.instance.ownerEmailFromName(name);
  }

  void _selectOwner(ForestOwnerModel? owner) {
    setState(() {
      _selectedOwner = owner;
      _selectedOwnerId = owner?.id;
      if (owner != null) {
        _nameController.text = owner.ownerName;
        _emailController.text = LocalAccountStore.instance.ownerEmailFromName(owner.ownerName);
      }
    });
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;
    final account = {
      if (_isEdit) 'id': widget.initialData!['id'],
      if (_isEdit) 'date': widget.initialData!['date'],
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim().toLowerCase(),
      'password': _passwordController.text,
      'role': _selectedRole,
      if (_selectedRole == UserRole.forestOwner) 'ownerId': _selectedOwnerId,
      if (_selectedRole == UserRole.forestOwner) 'ownerName': _selectedOwner?.ownerName ?? _nameController.text.trim(),
      if (_selectedRole == UserRole.forestOwner) 'forestName': _selectedOwner?.forestName ?? widget.initialData?['forestName'] ?? '',
      if (_selectedRole == UserRole.forestOwner) 'managementProvince': _selectedOwner?.managementProvince ?? widget.initialData?['managementProvince'] ?? '',
      if (_selectedRole == UserRole.forestOwner) 'totalAreaHa': _selectedOwner?.totalAreaHa ?? widget.initialData?['totalAreaHa'] ?? 0.0,
      'status': widget.initialData?['status'] ?? UserStatus.active,
    };

    setState(() => _isLoading = false);
    context.pop(account);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEdit ? 'Chỉnh sửa tài khoản' : 'Thêm tài khoản mới',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<UserRole>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Loại tài khoản',
                    prefixIcon: Icon(Icons.manage_accounts_outlined),
                  ),
                  items: _roles.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(_roleLabel(role)),
                    );
                  }).toList(),
                  onChanged: (role) {
                    if (role == null) return;
                    setState(() {
                      _selectedRole = role;
                      if (role != UserRole.forestOwner) {
                        _selectedOwner = null;
                        _selectedOwnerId = null;
                      }
                    });
                    _syncOwnerEmail();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (_selectedRole == UserRole.forestOwner) ...[
                  StreamBuilder<List<ForestOwnerModel>>(
                    stream: ForestOwnerService.instance.getOwnersStream(),
                    builder: (context, snapshot) {
                      final owners = snapshot.data ?? [];
                      final selectedId = owners.any((owner) => owner.id == _selectedOwnerId)
                          ? _selectedOwnerId
                          : null;

                      return DropdownButtonFormField<String>(
                        initialValue: selectedId,
                        decoration: const InputDecoration(
                          labelText: 'Chủ rừng liên kết',
                          prefixIcon: Icon(Icons.forest_outlined),
                        ),
                        items: owners.map((owner) {
                          return DropdownMenuItem(
                            value: owner.id,
                            child: Text(
                              '${owner.ownerCode} - ${owner.ownerName}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (ownerId) {
                          final owner = owners.where((item) => item.id == ownerId).firstOrNull;
                          _selectOwner(owner);
                        },
                        validator: (value) {
                          if (_selectedRole == UserRole.forestOwner && value == null) {
                            return 'Vui lòng chọn chủ rừng đã tạo';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _nameController,
                  enabled: _selectedRole != UserRole.forestOwner,
                  decoration: const InputDecoration(
                    labelText: 'Tên chủ tài khoản',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  onChanged: (_) => _syncOwnerEmail(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return AppStrings.fieldRequired;
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailController,
                  enabled: !_isEdit,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email đăng nhập',
                    prefixIcon: Icon(Icons.email_outlined),
                    helperText: 'Owner: tenchurung@gmail.com',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return AppStrings.fieldRequired;
                    if (!v.contains('@')) return AppStrings.invalidEmail;
                    final duplicated = LocalAccountStore.instance.emailExists(
                      v,
                      exceptId: widget.initialData?['id'] as String?,
                    );
                    if (duplicated) return 'Email này đã tồn tại';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                    if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text(AppStrings.cancel, style: TextStyle(color: AppColors.secondary)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppPrimaryButton(
                      label: AppStrings.save,
                      onPressed: _onSave,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.platformAdmin:
        return 'Platform Admin';
      case UserRole.forestOwner:
        return 'Owner';
      case UserRole.forestWorker:
        return 'Forest Worker';
    }
  }
}
