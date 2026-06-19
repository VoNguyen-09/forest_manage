import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/core/services/auth_service.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/shared/widgets/status_badge.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final _db = FirestoreService.instance;
  final _auth = AuthService.instance;
  String _searchQuery = '';
  UserRole? _selectedRole;

  final List<UserRole?> _roles = const [
    null,
    UserRole.forestOwner,
    UserRole.forestWorker,
  ];

  Future<void> _toggleAccountStatus(UserModel account) async {
    final nextStatus =
        account.status == UserStatus.active ? UserStatus.locked : UserStatus.active;

    try {
      await _db.updateUserStatus(account.uid, nextStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã ${nextStatus == UserStatus.active ? 'mở khóa' : 'khóa'} tài khoản ${account.fullName}',
          ),
        ),
      );
    } catch (e) {
      _showError('Không cập nhật được trạng thái: $e');
    }
  }

  void _confirmDelete(UserModel account) {
    // Lưu ScaffoldMessenger trước khi mở dialog để tránh deactivated widget
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Xóa tài khoản'),
          content: Text(
            'Bạn có chắc chắn muốn xóa tài khoản "${account.email}" không?\n\n'
            'Hành động này sẽ xóa hoàn toàn hồ sơ Firestore của tài khoản này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy', style: TextStyle(color: AppColors.secondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await AuthService.instance.deleteUserWithCleanup(
                    account.uid,
                    email: account.email.isNotEmpty ? account.email : null,
                    password: '123456',
                  );
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Đã xóa tài khoản thành công.')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Không xóa được tài khoản: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= AppBreakpoints.web;

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(title: const Text('Quản lý tài khoản')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWeb ? AppSpacing.lg : AppSpacing.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: StreamBuilder(
              stream: _auth.authStateChanges,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) {
                  return const AppCard(
                    child: Center(child: Text('Vui lòng đăng nhập lại để xem tài khoản.')),
                  );
                }

                return StreamBuilder<List<UserModel>>(
                  stream: _db.streamUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return AppCard(
                        child: Center(
                          child: Text(
                            'Lỗi: ${snapshot.error}',
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      );
                    }

                    final accounts = _filteredAccounts(snapshot.data ?? []);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildToolbar(isWeb),
                        const SizedBox(height: AppSpacing.lg),
                        if (accounts.isEmpty)
                          const AppCard(
                            child: Center(child: Text('Chưa có tài khoản nào hoặc không tìm thấy.')),
                          )
                        else if (isWeb)
                          _buildDataTable(accounts)
                        else
                          _buildMobileList(accounts),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<UserModel> _filteredAccounts(List<UserModel> accounts) {
    final query = _searchQuery.toLowerCase();
    return accounts.where((account) {
      if (account.role == UserRole.platformAdmin) return false;
      final matchesRole = _selectedRole == null || account.role == _selectedRole;
      final matchesSearch = query.isEmpty ||
          account.fullName.toLowerCase().contains(query) ||
          account.ownerName.toLowerCase().contains(query) ||
          account.email.toLowerCase().contains(query);
      return matchesRole && matchesSearch;
    }).toList();
  }

  Widget _buildToolbar(bool isWeb) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: isWeb ? 320 : double.infinity,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm tên, email...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          SizedBox(
            width: isWeb ? 220 : double.infinity,
            child: DropdownButtonFormField<UserRole?>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Loại tài khoản',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _roles.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role == null ? 'Tất cả' : _roleLabel(role)),
                );
              }).toList(),
              onChanged: (role) => setState(() => _selectedRole = role),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<UserModel> accounts) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 840),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.neutral),
            columns: const [
              DataColumn(label: Text('Tên chủ tài khoản', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Email đăng nhập', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Loại tài khoản', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Ngày tạo', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Thao tác', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: accounts.map((account) {
              return DataRow(cells: [
                DataCell(Text(_displayName(account))),
                DataCell(Text(account.email)),
                DataCell(Text(_roleLabel(account.role))),
                DataCell(AppStatusBadge(
                  status: account.status == UserStatus.active
                      ? BadgeStatus.active
                      : BadgeStatus.locked,
                )),
                DataCell(Text(_formatDate(account.createdAt))),
                DataCell(_AccountActions(
                  account: account,
                  onToggle: () => _toggleAccountStatus(account),
                  onDelete: () => _confirmDelete(account),
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(List<UserModel> accounts) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: accounts.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final account = accounts[index];
          return ListTile(
            contentPadding: const EdgeInsets.all(AppSpacing.md),
            title: Text(_displayName(account), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(account.email),
                const SizedBox(height: 4),
                Text(_roleLabel(account.role), style: const TextStyle(color: AppColors.tertiary)),
                const SizedBox(height: 8),
                AppStatusBadge(
                  status: account.status == UserStatus.active
                      ? BadgeStatus.active
                      : BadgeStatus.locked,
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'toggle') _toggleAccountStatus(account);
                if (value == 'delete') _confirmDelete(account);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(account.status == UserStatus.active ? 'Khóa tài khoản' : 'Mở khóa'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Xóa', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _displayName(UserModel account) {
    if (account.fullName.trim().isNotEmpty) return account.fullName;
    if (account.ownerName.trim().isNotEmpty) return account.ownerName;
    return account.email;
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.error,
      ),
    );
  }
}

class _AccountActions extends StatelessWidget {
  final UserModel account;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _AccountActions({
    required this.account,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = account.status == UserStatus.active;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            isActive ? Icons.lock_outline : Icons.lock_open_outlined,
            color: isActive ? AppColors.error : AppColors.success,
          ),
          tooltip: isActive ? 'Khóa tài khoản' : 'Mở khóa',
          onPressed: onToggle,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          tooltip: 'Xóa',
          onPressed: onDelete,
        ),
      ],
    );
  }
}
