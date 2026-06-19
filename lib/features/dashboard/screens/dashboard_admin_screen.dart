import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/models/carbon_result_model.dart';
import 'package:forest_carbon_platform/core/services/local_account_store.dart';

class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({super.key});

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  final _fs = FirestoreService.instance;
  
  List<ForestOwnerModel> _owners = [];
  List<ForestProjectModel> _projects = [];
  List<CarbonResultModel> _carbonResults = [];
  List<SpeciesFactor> _speciesFactors = [];
  
  StreamSubscription? _ownerSub;
  StreamSubscription? _projectSub;
  StreamSubscription? _carbonSub;
  StreamSubscription? _speciesSub;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    _ownerSub = _fs.streamForestOwners().listen((owners) {
      if (mounted) setState(() => _owners = owners);
      _checkLoading();
    });

    _projectSub = _fs.streamForestProjects().listen((projs) {
      if (mounted) setState(() => _projects = projs);
      _checkLoading();
    });

    _carbonSub = _fs.streamAllCarbonResults().listen((results) {
      // Nhóm theo projectId, lấy bản ghi mới nhất
      final Map<String, CarbonResultModel> latestResults = {};
      for (var r in results) {
        // Chỉ lấy bản ghi có co2eTon > 0 và từ dự án tồn tại
        if (r.co2eTon > 0 && _projects.any((p) => p.id == r.projectId)) {
          if (!latestResults.containsKey(r.projectId) || r.calculatedAt.isAfter(latestResults[r.projectId]!.calculatedAt)) {
            latestResults[r.projectId] = r;
          }
        }
      }
      if (mounted) setState(() => _carbonResults = latestResults.values.toList());
      _checkLoading();
    });

    _speciesSub = _fs.streamSpeciesFactors().listen((factors) {
      if (mounted) setState(() => _speciesFactors = factors);
      _checkLoading();
    });
  }

  void _checkLoading() {
    if (_isLoading && _ownerSub != null && _projectSub != null && _carbonSub != null && _speciesSub != null) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _ownerSub?.cancel();
    _projectSub?.cancel();
    _carbonSub?.cancel();
    _speciesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= AppBreakpoints.web;

    // Lấy tổng diện tích từ quản lý chủ rừng (theo managementProvince và polygon)
    final totalArea = _owners.fold<double>(0, (sum, owner) => sum + owner.totalAreaHa);
    final totalTrees = _speciesFactors.fold<int>(0, (sum, s) => sum + s.totalTreesCount);
    
    // Tính trung bình carbon từ tất cả dự án
    final avgCarbon = _carbonResults.isEmpty 
        ? 0.0 
        : _carbonResults.fold<double>(0, (sum, res) => sum + res.co2eTon) / _carbonResults.length;

    return Scaffold(
      backgroundColor: AppColors.neutral,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: const Text('Tổng quan'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Xem Bản đồ',
            onPressed: () => context.push(AppRoutes.map),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Quản lý Chủ rừng',
            onPressed: () => context.push(AppRoutes.forestOwners),
          ),
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'Quản lý Forest Worker',
            onPressed: () => context.push(AppRoutes.adminForestWorkers),
          ),
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Quản lý Dự án',
            onPressed: () => context.push(AppRoutes.forestProjects),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(isWeb ? AppSpacing.lg : AppSpacing.md),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWeb ? AppBreakpoints.web : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  children: [
                    AppKpiCard(
                      label: 'Tổng chủ rừng',
                      value: NumberFormat('#,###').format(_owners.length),
                      icon: Icons.people_outline,
                    ),
                    AppKpiCard(
                      label: 'Tổng dự án',
                      value: NumberFormat('#,###').format(_projects.length),
                      icon: Icons.folder_outlined,
                    ),
                    AppKpiCard(
                      label: 'Tổng diện tích',
                      value: totalArea > 0 ? NumberFormat('#,###.##').format(totalArea) : '—',
                      unit: 'ha',
                      icon: Icons.map_outlined,
                    ),
                    AppKpiCard(
                      label: 'Tổng số cây',
                      value: totalTrees > 0 ? NumberFormat('#,###').format(totalTrees) : '0',
                      icon: Icons.park_outlined,
                    ),
                    AppKpiCard(
                      label: 'Carbon',
                      value: avgCarbon > 0 ? NumberFormat('#,###.##').format(avgCarbon) : '—',
                      unit: 'tCO₂e',
                      icon: Icons.eco_outlined,
                      iconColor: AppColors.tertiary,
                      onTap: () => context.push(AppRoutes.carbon),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Biểu đồ',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),

                isWeb
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildAreaChart()),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _buildCarbonChart()),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _buildSpeciesChart()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildAreaChart(),
                          const SizedBox(height: AppSpacing.sm),
                          _buildCarbonChart(),
                          const SizedBox(height: AppSpacing.sm),
                          _buildSpeciesChart(),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAreaChart() {
    final Map<String, double> areaByProvince = {};
    // Lấy diện tích từ quản lý chủ rừng theo tỉnh quản lý
    for (var owner in _owners) {
      final prov = owner.managementProvince.isNotEmpty ? owner.managementProvince : 'Khác';
      areaByProvince[prov] = (areaByProvince[prov] ?? 0) + owner.totalAreaHa;
    }

    // Default empty state if no data
    if (areaByProvince.isEmpty || areaByProvince.values.every((v) => v == 0)) {
       areaByProvince['Đang cập nhật'] = 1;
    }

    final colors = [
      AppColors.tertiary,
      AppColors.primary,
      AppColors.secondary,
      AppColors.warning,
      AppColors.info,
    ];

    int i = 0;
    final sections = areaByProvince.entries.map((e) {
      final color = colors[i % colors.length];
      i++;
      return PieChartSectionData(
        value: e.value,
        title: '${e.key}\n${NumberFormat('#,###.##').format(e.value)} ha',
        color: color,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diện tích theo tỉnh (ha)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: areaByProvince.isEmpty || areaByProvince.values.every((v) => v == 0)
                ? const Center(
                    child: Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.secondary)),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: sections,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarbonChart() {
    // Lấy top 4 dự án có carbon cao nhất
    final sortedResults = List<CarbonResultModel>.from(_carbonResults)
      ..sort((a, b) => b.co2eTon.compareTo(a.co2eTon));
    
    final topResults = sortedResults.take(4).toList();
    
    List<BarChartGroupData> barGroups = [];
    List<ForestProjectModel> barProjects = [];
    double maxY = 100;
    
    for (int i = 0; i < topResults.length; i++) {
      final res = topResults[i];
      // Chỉ thêm nếu co2eTon > 0
      if (res.co2eTon > 0) {
        if (res.co2eTon > maxY) maxY = res.co2eTon;
        
        final proj = _projects.firstWhere(
          (p) => p.id == res.projectId, 
          orElse: () => ForestProjectModel(
            id: '', projectName: 'DA ${barGroups.length + 1}', ownerId: '', province: '', district: '', 
            commune: '', forestType: '', treeSpecies: '', yearPlanted: 0, 
            status: ProjectStatus.draft, createdAt: DateTime.now(), updatedAt: DateTime.now()
          )
        );

        barGroups.add(
          BarChartGroupData(
            x: barGroups.length,
            barRods: [
              BarChartRodData(
                toY: res.co2eTon,
                color: AppColors.primary,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              )
            ],
          )
        );
        barProjects.add(proj);
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Carbon theo dự án (tCO₂e)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: barGroups.isEmpty
                ? const Center(
                    child: Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.secondary)),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY * 1.2,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= barProjects.length) return const SizedBox();
                              String name = barProjects[idx].projectName;
                              if (name.length > 10) name = '${name.substring(0, 10)}...';
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(name, style: const TextStyle(fontSize: 11)),
                              );
                            },
                            reservedSize: 28,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) =>
                                Text('${value.toInt()}', style: const TextStyle(fontSize: 10)),
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: barGroups,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesChart() {
    // Tính số lượng cây trực tiếp từ SpeciesFactor.totalTreesCount
    final Map<String, int> treesBySpecies = {};
    
    for (var species in _speciesFactors) {
      if (species.totalTreesCount > 0) {
        treesBySpecies[species.speciesName] = species.totalTreesCount;
      }
    }

    if (treesBySpecies.isEmpty) {
       treesBySpecies['Đang cập nhật'] = 1;
    }

    final colors = [
      AppColors.tertiary,
      AppColors.primary,
      AppColors.secondary,
      AppColors.warning,
      AppColors.info,
    ];

    int i = 0;
    final sections = treesBySpecies.entries.map((e) {
      final color = colors[i % colors.length];
      i++;
      return PieChartSectionData(
        value: e.value.toDouble(),
        title: '${e.key}\n${NumberFormat('#,###').format(e.value)}',
        color: color,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Số lượng cây theo loài',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: treesBySpecies.isEmpty || treesBySpecies.values.every((v) => v == 0)
                ? const Center(
                    child: Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.secondary)),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: sections,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: AppColors.primary),
            child: Text(
              'Forest Carbon\nPlatform',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Tổng quan'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.dashboardAdmin);
            },
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Bản đồ'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.map);
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Quản lý Chủ rừng'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.forestOwners);
            },
          ),
          ListTile(
            leading: const Icon(Icons.groups),
            title: const Text('Quản lý Forest Worker'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.adminForestWorkers);
            },
          ),
          ListTile(
            leading: const Icon(Icons.park),
            title: const Text('Quản lý Dự án'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.forestProjects);
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Quản lý Tài liệu'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.fileManager);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.eco_outlined, color: AppColors.primary),
            title: const Text('Tính toán Carbon'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.carbon);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: AppColors.primary),
            title: const Text('Hệ số phát thải'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.speciesFactors);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications, color: AppColors.primary),
            title: const Text('Thông báo'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.notifications);
            },
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts, color: AppColors.primary),
            title: const Text('Quản lý tài khoản'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.accounts);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Đăng xuất', style: TextStyle(color: AppColors.error)),
            onTap: () {
              LocalAccountStore.instance.signOut();
              context.go(AppRoutes.login);
            },
          ),
        ],
      ),
    );
  }
}
