import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';

class DashboardOwnerScreen extends StatelessWidget {
  const DashboardOwnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= AppBreakpoints.web;

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: const Text('Tổng quan chủ rừng'),
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
                // Welcome header
                Text(
                  'Chào mừng quay lại, Nguyễn Văn A',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Thông tin cập nhật mới nhất về các dự án của bạn',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),

                // KPI Grid
                GridView.count(
                  crossAxisCount: isWeb ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: isWeb ? 1.5 : 1.3,
                  children: const [
                    AppKpiCard(
                      label: 'Dự án của tôi',
                      value: '2',
                      icon: Icons.folder_outlined,
                    ),
                    AppKpiCard(
                      label: 'Tổng diện tích',
                      value: '120.5',
                      unit: 'ha',
                      icon: Icons.map_outlined,
                    ),
                    AppKpiCard(
                      label: 'Số cây trồng',
                      value: '45,000',
                      icon: Icons.park_outlined,
                    ),
                    AppKpiCard(
                      label: 'Carbon tích lũy',
                      value: '1,250',
                      unit: 'tCO₂e',
                      icon: Icons.eco_outlined,
                      iconColor: AppColors.tertiary,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Recent Logs
                Text(
                  'Nhật ký hiện trường gần nhất',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                
                AppCard(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 3,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surface,
                          child: Icon(
                            index == 0 ? Icons.park : index == 1 ? Icons.water_drop : Icons.bug_report,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text('Dự án Đắk Lắk 0${index+1}'),
                        subtitle: Text(
                          index == 0 ? 'Trồng mới 500 cây Keo' : index == 1 ? 'Bón phân định kỳ đợt 2' : 'Kiểm tra sâu bệnh',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: Text(
                          '1$index thg 6, 2026',
                          style: Theme.of(context).textTheme.labelSmall,
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
