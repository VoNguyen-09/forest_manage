import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/shared/widgets/status_badge.dart';
import 'package:forest_carbon_platform/features/accounts/widgets/account_form_dialog.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  // Mock data
  final List<Map<String, dynamic>> _mockAccounts = [
    {'id': '1', 'name': 'Nguyễn Văn Admin', 'email': 'admin@gmail.com', 'role': 'Platform Admin', 'status': 'active', 'date': '01/01/2026'},
    {'id': '2', 'name': 'Trần Thị Chủ Rừng', 'email': 'owner1@gmail.com', 'role': 'Forest Owner', 'status': 'active', 'date': '15/02/2026'},
    {'id': '3', 'name': 'Lê Văn Khảo Sát', 'email': 'surveyor@gmail.com', 'role': 'Field Surveyor', 'status': 'active', 'date': '20/03/2026'},
    {'id': '4', 'name': 'Phạm Thị B', 'email': 'owner2@gmail.com', 'role': 'Forest Owner', 'status': 'locked', 'date': '10/05/2026'},
  ];

  String _searchQuery = '';
  String _selectedRole = 'Tất cả';

  final List<String> _roles = [
    'Tất cả',
    'Platform Admin',
    'Forest Owner',
    'Field Surveyor',
  ];

  void _showAccountDialog([Map<String, dynamic>? account]) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AccountFormDialog(initialData: account),
    );

    if (result == true) {
      // TODO: Reload data
    }
  }

  void _toggleAccountStatus(Map<String, dynamic> account) {
    setState(() {
      account['status'] = account['status'] == 'active' ? 'locked' : 'active';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã ${account['status'] == 'active' ? 'mở khóa' : 'khóa'} tài khoản ${account['name']}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= AppBreakpoints.web;

    final filteredAccounts = _mockAccounts.where((acc) {
      final matchesRole = _selectedRole == 'Tất cả' || acc['role'] == _selectedRole;
      final matchesSearch = acc['name'].toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            acc['email'].toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesRole && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: const Text('Quản lý tài khoản'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAccountDialog(),
        backgroundColor: AppColors.tertiary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm tài khoản'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWeb ? AppSpacing.lg : AppSpacing.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Toolbar (Search & Filter)
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Search
                      SizedBox(
                        width: isWeb ? 300 : double.infinity,
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Tìm kiếm tên, email...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) => setState(() => _searchQuery = value),
                        ),
                      ),
                      // Filter Role
                      SizedBox(
                        width: isWeb ? 200 : double.infinity,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                          onChanged: (v) => setState(() => _selectedRole = v ?? 'Tất cả'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Data Table / List
                AppCard(
                  padding: EdgeInsets.zero,
                  child: isWeb
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AppColors.neutral),
                            columns: const [
                              DataColumn(label: Text('Tên người dùng', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Vai trò', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Ngày tạo', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Thao tác', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: filteredAccounts.map((acc) => DataRow(
                              cells: [
                                DataCell(Text(acc['name'])),
                                DataCell(Text(acc['email'])),
                                DataCell(Text(acc['role'])),
                                DataCell(AppStatusBadge(
                                  status: acc['status'] == 'active' ? BadgeStatus.active : BadgeStatus.locked,
                                )),
                                DataCell(Text(acc['date'])),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                                      tooltip: 'Chỉnh sửa',
                                      onPressed: () => _showAccountDialog(acc),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        acc['status'] == 'active' ? Icons.lock_outline : Icons.lock_open_outlined,
                                        color: acc['status'] == 'active' ? AppColors.error : AppColors.success,
                                      ),
                                      tooltip: acc['status'] == 'active' ? 'Khóa tài khoản' : 'Mở khóa',
                                      onPressed: () => _toggleAccountStatus(acc),
                                    ),
                                  ],
                                )),
                              ],
                            )).toList(),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredAccounts.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final acc = filteredAccounts[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.all(AppSpacing.md),
                              title: Text(acc['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(acc['email']),
                                  const SizedBox(height: 4),
                                  Text(acc['role'], style: const TextStyle(color: AppColors.tertiary)),
                                  const SizedBox(height: 8),
                                  AppStatusBadge(
                                    status: acc['status'] == 'active' ? BadgeStatus.active : BadgeStatus.locked,
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                                  PopupMenuItem(
                                    value: 'toggle', 
                                    child: Text(acc['status'] == 'active' ? 'Khóa tài khoản' : 'Mở khóa', style: TextStyle(color: acc['status'] == 'active' ? AppColors.error : AppColors.success)),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'edit') _showAccountDialog(acc);
                                  if (value == 'toggle') _toggleAccountStatus(acc);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
