import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';

class DashboardAdminScreen extends StatelessWidget {
  const DashboardAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= AppBreakpoints.web;

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: const Text(AppStrings.dashboard),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWeb ? AppSpacing.lg : AppSpacing.md),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWeb ? AppBreakpoints.web : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section title
                Text(
                  'Tổng quan hệ thống',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Dữ liệu cập nhật theo thời gian thực',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),

                // KPI Grid
                GridView.count(
                  crossAxisCount: isWeb ? 5 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: isWeb ? 1.2 : 1.3,
                  children: const [
                    AppKpiCard(
                      label: 'Tổng chủ rừng',
                      value: '—',
                      icon: Icons.people_outline,
                    ),
                    AppKpiCard(
                      label: 'Tổng dự án',
                      value: '—',
                      icon: Icons.folder_outlined,
                    ),
                    AppKpiCard(
                      label: 'Tổng diện tích',
                      value: '—',
                      unit: 'ha',
                      icon: Icons.map_outlined,
                    ),
                    AppKpiCard(
                      label: 'Tổng số cây',
                      value: '—',
                      icon: Icons.park_outlined,
                    ),
                    AppKpiCard(
                      label: 'Carbon',
                      value: '—',
                      unit: 'tCO₂e',
                      icon: Icons.eco_outlined,
                      iconColor: AppColors.tertiary,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Charts placeholder
                Text(
                  'Biểu đồ',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),

                isWeb
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _ChartPlaceholder(label: 'Diện tích theo tỉnh')),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _ChartPlaceholder(label: 'Carbon theo dự án')),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _ChartPlaceholder(label: 'Số lượng cây theo loài')),
                        ],
                      )
                    : Column(
                        children: [
                          _ChartPlaceholder(label: 'Diện tích theo tỉnh'),
                          const SizedBox(height: AppSpacing.sm),
                          _ChartPlaceholder(label: 'Carbon theo dự án'),
                          const SizedBox(height: AppSpacing.sm),
                          _ChartPlaceholder(label: 'Số lượng cây theo loài'),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final String label;
  const _ChartPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: SizedBox(
        height: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const Expanded(
              child: Center(
                child: Text(
                  '[ fl_chart — sẽ tích hợp sau ]',
                  style: TextStyle(color: AppColors.secondary, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
