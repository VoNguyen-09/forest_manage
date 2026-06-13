import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/shared/widgets/app_button.dart';
import 'package:forest_carbon_platform/core/services/forest_owner_service.dart';
import 'package:forest_carbon_platform/shared/widgets/empty_state.dart';

class ForestOwnersScreen extends StatefulWidget {
  const ForestOwnersScreen({super.key});

  @override
  State<ForestOwnersScreen> createState() => _ForestOwnersScreenState();
}

class _ForestOwnersScreenState extends State<ForestOwnersScreen> {
  final Stream<List<ForestOwnerModel>> _ownersStream = ForestOwnerService.instance.getOwnersStream();

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
            child: StreamBuilder<List<ForestOwnerModel>>(
              stream: _ownersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: AppColors.error)),
                  );
                }
                final owners = snapshot.data ?? [];

                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchAndFilter(),
                      const SizedBox(height: AppSpacing.md),
                      if (owners.isEmpty)
                        const AppEmptyState(title: 'Chưa có chủ rừng nào.')
                      else
                        isWeb ? _buildDataTable(owners) : _buildListView(owners),
                    ],
                  ),
                );
              }
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

  Widget _buildDataTable(List<ForestOwnerModel> owners) {
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
        rows: owners.map((owner) => DataRow(
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

  Widget _buildListView(List<ForestOwnerModel> owners) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: owners.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final owner = owners[index];
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
