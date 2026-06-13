import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/shared/widgets/app_button.dart';
import 'package:forest_carbon_platform/shared/widgets/status_badge.dart';

class ForestProjectsScreen extends StatefulWidget {
  const ForestProjectsScreen({super.key});

  @override
  State<ForestProjectsScreen> createState() => _ForestProjectsScreenState();
}

class _ForestProjectsScreenState extends State<ForestProjectsScreen> {
  // Dữ liệu mẫu (Mock Data)
  final List<ForestProjectModel> _projects = [
    ForestProjectModel(
      id: '1',
      projectName: 'Dự án Rừng Keo Đắk Lắk',
      ownerId: '1',
      province: 'Đắk Lắk',
      district: 'Buôn Ma Thuột',
      commune: 'Ea Tu',
      forestType: 'Rừng trồng',
      treeSpecies: 'Keo lai',
      yearPlanted: 2020,
      status: ProjectStatus.active,
      totalAreaHa: 50.5,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ForestProjectModel(
      id: '2',
      projectName: 'Dự án Thông Lâm Đồng',
      ownerId: '2',
      province: 'Lâm Đồng',
      district: 'Đà Lạt',
      commune: 'Xuân Thọ',
      forestType: 'Rừng phòng hộ',
      treeSpecies: 'Thông ba lá',
      yearPlanted: 2018,
      status: ProjectStatus.surveying,
      totalAreaHa: 120.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= AppBreakpoints.web;

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: const Text(AppStrings.forestProjectManagement),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          if (isWeb)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: AppPrimaryButton(
                label: AppStrings.addProject,
                onPressed: () {
                  context.push(AppRoutes.forestProjectAdd);
                },
              ),
            ),
        ],
      ),
      floatingActionButton: isWeb ? null : FloatingActionButton(
        onPressed: () => context.push(AppRoutes.forestProjectAdd),
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
          DataColumn(label: Text(AppStrings.projectName)),
          DataColumn(label: Text(AppStrings.forestType)),
          DataColumn(label: Text(AppStrings.treeSpecies)),
          DataColumn(label: Text('Diện tích (ha)')),
          DataColumn(label: Text('Trạng thái')),
          DataColumn(label: Text('Thao tác')),
        ],
        rows: _projects.map((proj) => DataRow(
          cells: [
            DataCell(Text(proj.projectName, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(proj.forestType)),
            DataCell(Text(proj.treeSpecies)),
            DataCell(Text(proj.totalAreaHa.toString())),
            DataCell(_buildStatusBadge(proj.status)),
            DataCell(
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.map, size: 20, color: AppColors.secondary),
                    onPressed: () {},
                    tooltip: 'Xem bản đồ',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: AppColors.info),
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
      itemCount: _projects.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final proj = _projects[index];
        return ListTile(
          title: Text(proj.projectName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('${proj.treeSpecies} • ${proj.totalAreaHa} ha'),
              const SizedBox(height: 4),
              _buildStatusBadge(proj.status),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          isThreeLine: true,
          onTap: () {
            // Xem chi tiết / Sửa
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(ProjectStatus status) {
    BadgeStatus badgeStatus;
    switch (status) {
      case ProjectStatus.active:
        badgeStatus = BadgeStatus.active;
        break;
      case ProjectStatus.surveying:
        badgeStatus = BadgeStatus.surveying;
        break;
      case ProjectStatus.suspended:
        badgeStatus = BadgeStatus.suspended;
        break;
      case ProjectStatus.draft:
      default:
        badgeStatus = BadgeStatus.draft;
        break;
    }
    return AppStatusBadge(status: badgeStatus);
  }
}
