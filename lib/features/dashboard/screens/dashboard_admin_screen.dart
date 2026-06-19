import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/config/constants.dart';
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

class _DashboardHero extends StatelessWidget {
  final int totalProjects;
  final int totalOwners;

  const _DashboardHero({
    required this.totalProjects,
    required this.totalOwners,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF123D32), Color(0xFF1D5B48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A123D32),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 20,
            children: [
              SizedBox(
                width: compact ? constraints.maxWidth : 580,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'BẢNG ĐIỀU KHIỂN QUẢN TRỊ',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tổng quan hệ thống rừng',
                      style: GoogleFonts.beVietnamPro(
                        color: Colors.white,
                        fontSize: compact ? 24 : 30,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Theo dõi dữ liệu dự án, diện tích và trữ lượng carbon\ntrên một không gian trực quan, rõ ràng.',
                      style: GoogleFonts.beVietnamPro(
                        color: const Color(0xFFD5E7DF),
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insights_outlined, color: Color(0xFF91E5B7)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$totalProjects dự án · $totalOwners chủ rừng',
                          style: GoogleFonts.beVietnamPro(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dữ liệu đang được đồng bộ',
                          style: GoogleFonts.beVietnamPro(
                            color: const Color(0xFFD5E7DF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const _DashboardKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.unit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EDE8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(height: 2),
                Text(
                  unit!,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  height: 1.05,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _DashboardChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.beVietnamPro(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ProjectMapOverview extends StatelessWidget {
  final List<ForestProjectModel> projects;
  final VoidCallback onViewMap;

  const _ProjectMapOverview({
    required this.projects,
    required this.onViewMap,
  });

  static const _zoneColors = [
    Color(0xFF00A06A),
    Color(0xFF2477D4),
    Color(0xFFE89218),
    Color(0xFF7C4DCC),
    Color(0xFFD95064),
  ];

  Color _colorForProject(ForestProjectModel project) {
    return _zoneColors[project.ownerId.hashCode.abs() % _zoneColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final mappedProjects = projects.where((project) => project.polygon.length >= 3).toList();
    final mapPoints = mappedProjects
        .expand((project) => project.polygon)
        .map((point) => LatLng(point.lat, point.lng))
        .toList();
    final center = _centerFor(mapPoints);

    return _DashboardChartCard(
      title: 'Bản đồ dự án',
      subtitle: mappedProjects.isEmpty
          ? 'Chưa có ranh giới dự án để hiển thị'
          : '${mappedProjects.length} vùng rừng đã được định vị',
      child: SizedBox(
        height: 230,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _overviewZoom(mapPoints),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.forestcarbon.app',
                    ),
                    if (mappedProjects.isNotEmpty)
                      PolygonLayer(
                        polygons: mappedProjects.map((project) {
                          final color = _colorForProject(project);
                          return Polygon(
                            points: project.polygon
                                .map((point) => LatLng(point.lat, point.lng))
                                .toList(),
                            color: color.withValues(alpha: 0.32),
                            borderColor: color,
                            borderStrokeWidth: 2,
                          );
                        }).toList(),
                      ),
                    if (mappedProjects.isNotEmpty)
                      MarkerLayer(
                        markers: mappedProjects.map((project) {
                          final polygonPoints = project.polygon
                              .map((point) => LatLng(point.lat, point.lng))
                              .toList();
                          return Marker(
                            point: _centerFor(polygonPoints),
                            width: 30,
                            height: 30,
                            child: Icon(
                              Icons.location_on_rounded,
                              color: _colorForProject(project),
                              size: 28,
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onViewMap,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_in_full_rounded, size: 15),
                          const SizedBox(width: 5),
                          Text(
                            'Xem bản đồ',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (mappedProjects.isEmpty)
                const Positioned.fill(
                  child: ColoredBox(color: Color(0x660C342A)),
                ),
              if (mappedProjects.isEmpty)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.map_outlined, color: Colors.white, size: 30),
                      const SizedBox(height: 6),
                      Text(
                        'Thêm ranh giới dự án để xem tổng quan',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  LatLng _centerFor(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(12.6667, 108.0383);
    final latitude = points.fold<double>(0, (sum, point) => sum + point.latitude) /
        points.length;
    final longitude = points.fold<double>(0, (sum, point) => sum + point.longitude) /
        points.length;
    return LatLng(latitude, longitude);
  }

  double _overviewZoom(List<LatLng> points) {
    if (points.length < 2) return 11;
    final latitudes = points.map((point) => point.latitude);
    final longitudes = points.map((point) => point.longitude);
    final spread = [
      latitudes.reduce((a, b) => a > b ? a : b) - latitudes.reduce((a, b) => a < b ? a : b),
      longitudes.reduce((a, b) => a > b ? a : b) - longitudes.reduce((a, b) => a < b ? a : b),
    ].reduce((a, b) => a > b ? a : b);

    if (spread < 0.03) return 13;
    if (spread < 0.15) return 11;
    if (spread < 0.7) return 9;
    if (spread < 2.5) return 7;
    return 5;
  }
}

class _DonutChartWithLegend<T extends num> extends StatelessWidget {
  final List<PieChartSectionData> sections;
  final List<MapEntry<String, T>> entries;
  final List<Color> colors;
  final String centerValue;
  final String centerLabel;
  final String Function(T value) valueFormatter;

  const _DonutChartWithLegend({
    required this.sections,
    required this.entries,
    required this.colors,
    required this.centerValue,
    required this.centerLabel,
    required this.valueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final legendItems = entries.take(4).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 350;
          final chart = SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 47,
                    startDegreeOffset: -90,
                    sections: sections,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerValue,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      centerLabel,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 10,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          final legend = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < legendItems.length; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          legendItems[index].key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        valueFormatter(legendItems[index].value),
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );

          if (isCompact) {
            return SizedBox(
              height: 340,
              child: Column(
                children: [
                  chart,
                  const SizedBox(height: 6),
                  Expanded(child: legend),
                ],
              ),
            );
          }
          return SizedBox(
            height: 230,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                chart,
                SizedBox(width: 220, child: legend),
              ],
            ),
          );
      },
    );
  }
}

class _DashboardEmptyChart extends StatelessWidget {
  const _DashboardEmptyChart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Chưa có dữ liệu để hiển thị',
        style: GoogleFonts.beVietnamPro(fontSize: 14, color: AppColors.secondary),
      ),
    );
  }
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth >= AppBreakpoints.web;
    final isTablet = screenWidth >= AppBreakpoints.tablet;

    // Lấy tổng diện tích từ quản lý chủ rừng (theo managementProvince và polygon)
    final totalArea = _owners.fold<double>(0, (sum, owner) => sum + owner.totalAreaHa);
    final totalTrees = _speciesFactors.fold<int>(0, (sum, s) => sum + s.totalTreesCount);
    
    // Tính trung bình carbon từ tất cả dự án
    final avgCarbon = _carbonResults.isEmpty 
        ? 0.0 
        : _carbonResults.fold<double>(0, (sum, res) => sum + res.co2eTon) / _carbonResults.length;

    final dashboardTheme = Theme.of(context).copyWith(
      textTheme: GoogleFonts.beVietnamProTextTheme(Theme.of(context).textTheme),
      appBarTheme: Theme.of(context).appBarTheme.copyWith(
            titleTextStyle: GoogleFonts.beVietnamPro(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.onPrimary,
            ),
          ),
    );

    return Theme(
      data: dashboardTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F2),
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
              tooltip: 'Thông báo',
              onPressed: () {},
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isWeb ? 40 : AppSpacing.md,
                  isWeb ? 32 : AppSpacing.md,
                  isWeb ? 40 : AppSpacing.md,
                  40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DashboardHero(
                          totalProjects: _projects.length,
                          totalOwners: _owners.length,
                        ),
                        const SizedBox(height: 28),
                        GridView.count(
                          crossAxisCount: isWeb ? 5 : (isTablet ? 3 : 2),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: isWeb ? 1.75 : (isTablet ? 1.85 : 1.28),
                          children: [
                            _DashboardKpiCard(
                              label: 'Chủ rừng',
                              value: NumberFormat('#,##0').format(_owners.length),
                              icon: Icons.people_alt_outlined,
                              accent: const Color(0xFF14804A),
                            ),
                            _DashboardKpiCard(
                              label: 'Dự án rừng',
                              value: NumberFormat('#,##0').format(_projects.length),
                              icon: Icons.account_tree_outlined,
                              accent: const Color(0xFF2477D4),
                            ),
                            _DashboardKpiCard(
                              label: 'Tổng diện tích',
                              value: totalArea > 0
                                  ? NumberFormat('#,##0.##').format(totalArea)
                                  : '—',
                              unit: 'ha',
                              icon: Icons.map_outlined,
                              accent: const Color(0xFF00A06A),
                            ),
                            _DashboardKpiCard(
                              label: 'Tổng số cây',
                              value: NumberFormat('#,##0').format(totalTrees),
                              icon: Icons.forest_outlined,
                              accent: const Color(0xFF7C4DCC),
                            ),
                            _DashboardKpiCard(
                              label: 'Carbon ước tính',
                              value: avgCarbon > 0 ? _formatLargeNumber(avgCarbon) : '—',
                              unit: 'tCO₂e',
                              icon: Icons.eco_outlined,
                              accent: const Color(0xFFE89218),
                              onTap: () => context.push(AppRoutes.carbon),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        Row(
                          children: [
                            Text(
                              'Phân tích tài nguyên rừng',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2F3E9),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                'Cập nhật trực tiếp',
                                style: GoogleFonts.beVietnamPro(
                                  color: const Color(0xFF14804A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        isWeb
                            ? Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 7, child: _buildCarbonChart()),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 5,
                                        child: _ProjectMapOverview(
                                          projects: _projects,
                                          onViewMap: () => context.push(AppRoutes.map),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _buildAreaChart()),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildSpeciesChart()),
                                    ],
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildCarbonChart(),
                                  const SizedBox(height: 14),
                                  _ProjectMapOverview(
                                    projects: _projects,
                                    onViewMap: () => context.push(AppRoutes.map),
                                  ),
                                  const SizedBox(height: 14),
                                  _buildAreaChart(),
                                  const SizedBox(height: 14),
                                  _buildSpeciesChart(),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  String _formatLargeNumber(double value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(2)} tỷ';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)} triệu';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)} nghìn';
    return NumberFormat('#,##0.##').format(value);
  }

  Widget _buildAreaChart() {
    final Map<String, double> areaByProvince = {};
    // Lấy diện tích từ quản lý chủ rừng theo tỉnh quản lý
    for (var owner in _owners) {
      final prov = owner.managementProvince.isNotEmpty ? owner.managementProvince : 'Khác';
      areaByProvince[prov] = (areaByProvince[prov] ?? 0) + owner.totalAreaHa;
    }

    final hasData =
        areaByProvince.isNotEmpty && areaByProvince.values.any((value) => value > 0);
    if (!hasData) areaByProvince['Đang cập nhật'] = 1;

    final colors = [
      AppColors.tertiary,
      AppColors.primary,
      AppColors.secondary,
      AppColors.warning,
      AppColors.info,
    ];

    final entries = areaByProvince.entries.toList();
    final totalArea = entries.fold<double>(0, (sum, item) => sum + item.value);
    final sections = entries.asMap().entries.map((item) {
      final color = colors[item.key % colors.length];
      return PieChartSectionData(
        value: item.value.value,
        title: '',
        color: color,
        radius: 56,
      );
    }).toList();

    return _DashboardChartCard(
      title: 'Diện tích theo tỉnh',
      subtitle: 'Phân bố diện tích quản lý',
      child: _DonutChartWithLegend(
        sections: sections,
        entries: entries,
        colors: colors,
        centerValue: hasData ? NumberFormat('#,##0.##').format(totalArea) : '—',
        centerLabel: 'ha tổng diện tích',
        valueFormatter: (value) => '${NumberFormat('#,##0.##').format(value)} ha',
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
                width: 28,
                borderRadius: BorderRadius.circular(6),
              )
            ],
          )
        );
        barProjects.add(proj);
      }
    }

    return _DashboardChartCard(
      title: 'Carbon theo dự án',
      subtitle: 'Top dự án có trữ lượng carbon cao nhất (tCO₂e)',
      child: SizedBox(
        height: 230,
        child: barGroups.isEmpty
            ? const _DashboardEmptyChart()
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
                          final index = value.toInt();
                          if (index < 0 || index >= barProjects.length) {
                            return const SizedBox();
                          }
                          final name = _shortProjectName(barProjects[index].projectName);
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 12,
                                color: AppColors.secondary,
                              ),
                            ),
                          );
                        },
                        reservedSize: 34,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) => Text(
                          _shortAxisNumber(value),
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: const Color(0xFFE8EDE8),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
      ),
    );
  }

  String _shortProjectName(String name) {
    if (name.length <= 12) return name;
    return '${name.substring(0, 11)}…';
  }

  String _shortAxisNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(0)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toInt().toString();
  }

  Widget _buildSpeciesChart() {
    // Tính số lượng cây trực tiếp từ SpeciesFactor.totalTreesCount
    final Map<String, int> treesBySpecies = {};
    
    for (var species in _speciesFactors) {
      if (species.totalTreesCount > 0) {
        treesBySpecies[species.speciesName] = species.totalTreesCount;
      }
    }

    final hasData =
        treesBySpecies.isNotEmpty && treesBySpecies.values.any((value) => value > 0);
    if (!hasData) treesBySpecies['Đang cập nhật'] = 1;

    final colors = [
      AppColors.tertiary,
      AppColors.primary,
      AppColors.secondary,
      AppColors.warning,
      AppColors.info,
    ];

    final entries = treesBySpecies.entries.toList();
    final totalTrees = entries.fold<int>(0, (sum, item) => sum + item.value);
    final sections = entries.asMap().entries.map((item) {
      final color = colors[item.key % colors.length];
      return PieChartSectionData(
        value: item.value.value.toDouble(),
        title: '',
        color: color,
        radius: 56,
      );
    }).toList();

    return _DashboardChartCard(
      title: 'Cơ cấu loài cây',
      subtitle: 'Số lượng cây theo loài',
      child: _DonutChartWithLegend(
        sections: sections,
        entries: entries,
        colors: colors,
        centerValue: hasData ? NumberFormat('#,##0').format(totalTrees) : '—',
        centerLabel: 'cây đã ghi nhận',
        valueFormatter: (value) => NumberFormat('#,##0').format(value),
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
