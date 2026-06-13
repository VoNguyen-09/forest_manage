import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:fl_chart/fl_chart.dart';

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
                          Expanded(child: _AreaByProvinceChart()),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _CarbonByProjectChart()),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _TreesBySpeciesChart()),
                        ],
                      )
                    : Column(
                        children: [
                          _AreaByProvinceChart(),
                          const SizedBox(height: AppSpacing.sm),
                          _CarbonByProjectChart(),
                          const SizedBox(height: AppSpacing.sm),
                          _TreesBySpeciesChart(),
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

class _AreaByProvinceChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: SizedBox(
        height: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Diện tích theo tỉnh (ha)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(value: 40, title: 'Đắk Lắk', color: AppColors.primary, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 12)),
                    PieChartSectionData(value: 30, title: 'Lâm Đồng', color: AppColors.tertiary, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 12)),
                    PieChartSectionData(value: 15, title: 'Gia Lai', color: AppColors.secondary, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 12)),
                    PieChartSectionData(value: 15, title: 'Khác', color: AppColors.info, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarbonByProjectChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: SizedBox(
        height: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Carbon theo dự án (tCO₂e)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const titles = ['DA 1', 'DA 2', 'DA 3', 'DA 4'];
                          if (value.toInt() >= 0 && value.toInt() < titles.length) {
                            return Text(titles[value.toInt()], style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10))),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 80, color: AppColors.primary, width: 16, borderRadius: BorderRadius.circular(4))]),
                    BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 50, color: AppColors.primary, width: 16, borderRadius: BorderRadius.circular(4))]),
                    BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 30, color: AppColors.primary, width: 16, borderRadius: BorderRadius.circular(4))]),
                    BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 90, color: AppColors.primary, width: 16, borderRadius: BorderRadius.circular(4))]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreesBySpeciesChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: SizedBox(
        height: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số lượng cây theo loài', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(value: 60, title: 'Keo', color: AppColors.primary, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 12)),
                    PieChartSectionData(value: 25, title: 'Thông', color: AppColors.tertiary, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 12)),
                    PieChartSectionData(value: 15, title: 'Bạch đàn', color: AppColors.secondary, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
