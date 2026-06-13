import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/shared/widgets/app_button.dart';
import 'package:forest_carbon_platform/shared/widgets/status_badge.dart';
import 'package:forest_carbon_platform/core/services/forest_project_service.dart';
import 'package:forest_carbon_platform/shared/widgets/empty_state.dart';

class ForestProjectsScreen extends StatefulWidget {
  const ForestProjectsScreen({super.key});

  @override
  State<ForestProjectsScreen> createState() => _ForestProjectsScreenState();
}

class _ForestProjectsScreenState extends State<ForestProjectsScreen> {
  final Stream<List<ForestProjectModel>> _projectsStream = ForestProjectService.instance.getProjectsStream();

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
            child: StreamBuilder<List<ForestProjectModel>>(
              stream: _projectsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: AppColors.error)),
                  );
                }
                final projects = snapshot.data ?? [];

                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchAndFilter(),
                      const SizedBox(height: AppSpacing.md),
                      if (projects.isEmpty)
                        const AppEmptyState(title: 'Chưa có dự án nào.')
                      else
                        isWeb ? _buildDataTable(projects) : _buildListView(projects),
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

  Widget _buildDataTable(List<ForestProjectModel> projects) {
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
        rows: projects.map((proj) => DataRow(
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

  Widget _buildListView(List<ForestProjectModel> projects) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: projects.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final proj = projects[index];
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
