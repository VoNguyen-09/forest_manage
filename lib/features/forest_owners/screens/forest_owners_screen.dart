import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/shared/widgets/app_button.dart';

class ForestOwnersScreen extends StatefulWidget {
  const ForestOwnersScreen({super.key});

  @override
  State<ForestOwnersScreen> createState() => _ForestOwnersScreenState();
}

class _ForestOwnersScreenState extends State<ForestOwnersScreen> {
  // Dữ liệu mẫu (Mock Data)
  final List<ForestOwnerModel> _owners = [
    ForestOwnerModel(
      id: '1',
      ownerCode: 'CR001',
      ownerName: 'Nguyễn Văn A',
      type: OwnerType.individual,
      cccd: '012345678910',
      address: 'Đắk Lắk',
      phone: '0901234567',
      email: 'nva@example.com',
      createdAt: DateTime.now(),
    ),
    ForestOwnerModel(
      id: '2',
      ownerCode: 'CR002',
      ownerName: 'Cty Lâm Nghiệp B',
      type: OwnerType.company,
      cccd: '0312345678',
      address: 'Lâm Đồng',
      phone: '0909876543',
      email: 'contact@ctyb.com',
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= AppBreakpoints.web;

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: const Text(AppStrings.forestOwnerManagement),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          if (isWeb)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: AppPrimaryButton(
                label: AppStrings.addOwner,
                onPressed: () {
                  context.push(AppRoutes.forestOwnerAdd);
                },
              ),
            ),
        ],
      ),
      floatingActionButton: isWeb ? null : FloatingActionButton(
        onPressed: () => context.push(AppRoutes.forestOwnerAdd),
        backgroundColor: AppColors.tertiary,
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.web,
            ),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchAndFilter(),
                  const SizedBox(height: AppSpacing.md),
                  isWeb ? _buildDataTable() : _buildListView(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: AppStrings.search,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () {},
          tooltip: AppStrings.filter,
        ),
      ],
    );
  }

  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text(AppStrings.ownerCode)),
          DataColumn(label: Text(AppStrings.ownerName)),
          DataColumn(label: Text(AppStrings.ownerType)),
          DataColumn(label: Text('SĐT')),
          DataColumn(label: Text('Địa chỉ')),
          DataColumn(label: Text('Thao tác')),
        ],
        rows: _owners.map((owner) => DataRow(
          cells: [
            DataCell(Text(owner.ownerCode)),
            DataCell(Text(owner.ownerName)),
            DataCell(Text(owner.type == OwnerType.company ? 'Doanh nghiệp' : (owner.type == OwnerType.cooperative ? 'Hợp tác xã' : 'Cá nhân'))),
            DataCell(Text(owner.phone)),
            DataCell(Text(owner.address)),
            DataCell(
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: AppColors.info),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: AppColors.error),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        )).toList(),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _owners.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final owner = _owners[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Icon(
              owner.type == OwnerType.company ? Icons.business : (owner.type == OwnerType.cooperative ? Icons.group : Icons.person),
              color: AppColors.primary,
            ),
          ),
          title: Text(owner.ownerName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${owner.ownerCode} • ${owner.phone}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Xem chi tiết / Sửa
          },
        );
      },
    );
  }
}
