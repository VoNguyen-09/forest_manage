import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/services/local_account_store.dart';
import 'package:forest_carbon_platform/core/services/auth_service.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/models/carbon_result_model.dart';
import 'package:forest_carbon_platform/core/models/log_entry_model.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';

class DashboardOwnerScreen extends StatefulWidget {
  const DashboardOwnerScreen({super.key});

  @override
  State<DashboardOwnerScreen> createState() => _DashboardOwnerScreenState();
}

class _OwnerHero extends StatelessWidget {
  final String ownerName;
  final String forestName;
  final String province;
  final int projectCount;

  const _OwnerHero({
    required this.ownerName,
    required this.forestName,
    required this.province,
    required this.projectCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF123D32), Color(0xFF1F6B52)],
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
            spacing: 20,
            runSpacing: 20,
            children: [
              SizedBox(
                width: compact ? constraints.maxWidth : 650,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'KHÔNG GIAN QUẢN LÝ RỪNG CỦA BẠN',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chào mừng quay lại, $ownerName',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: compact ? 25 : 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      province.isEmpty ? forestName : '$forestName · $province',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 14,
                        color: const Color(0xFFD5E7DF),
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
                    const Icon(Icons.forest_outlined, color: Color(0xFF91E5B7)),
                    const SizedBox(width: 10),
                    Text(
                      '$projectCount dự án đang quản lý',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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

class _OwnerKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color accent;

  const _OwnerKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
              style: GoogleFonts.beVietnamPro(
                fontSize: 28,
                height: 1,
                fontWeight: FontWeight.w700,
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
    );
  }
}

class _OwnerWorkerCountCard extends StatelessWidget {
  final String ownerId;

  const _OwnerWorkerCountCard({required this.ownerId});

  @override
  Widget build(BuildContext context) {
    if (ownerId.isEmpty) {
      return const _OwnerKpiCard(
        label: 'Forest Worker',
        value: '0',
        icon: Icons.groups_2_outlined,
        accent: Color(0xFF14804A),
      );
    }

    return StreamBuilder<List<UserModel>>(
      stream: FirestoreService.instance.streamWorkersByOwner(ownerId),
      builder: (context, snapshot) => _OwnerKpiCard(
        label: 'Forest Worker',
        value: NumberFormat('#,##0').format(snapshot.data?.length ?? 0),
        icon: Icons.groups_2_outlined,
        accent: const Color(0xFF14804A),
      ),
    );
  }
}

class _OwnerSurfaceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _OwnerSurfaceCard({
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
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: AppColors.secondary),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _OwnerCarbonHistoryChart extends StatelessWidget {
  final List<CarbonResultModel> results;

  const _OwnerCarbonHistoryChart({required this.results});

  @override
  Widget build(BuildContext context) {
    final chronological = results.reversed.toList();
    final maxY = chronological.fold<double>(100, (max, result) =>
        result.co2eTon > max ? result.co2eTon : max);

    return _OwnerSurfaceCard(
      title: 'Ba lần tính carbon gần nhất',
      subtitle: 'Mọi kết quả mới nhất, gồm cả bản ghi đang chờ duyệt',
      child: SizedBox(
        height: 252,
        child: chronological.isEmpty
            ? const _OwnerEmptyState(message: 'Chưa có kết quả carbon nào.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CarbonStatusLegend(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY * 1.2,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: const Color(0xFFE8EDE8),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (value, meta) => Text(
                          _shortNumber(value),
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= chronological.length) {
                            return const SizedBox();
                          }
                          final result = chronological[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              DateFormat('dd/MM').format(result.calculatedAt),
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 11,
                                height: 1,
                                color: AppColors.secondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var index = 0; index < chronological.length; index++)
                      BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: chronological[index].co2eTon,
                            width: 30,
                            color: _statusColor(chronological[index].status),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ],
                      ),
                  ],
                ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Color _statusColor(CarbonApprovalStatus status) {
    return switch (status) {
      CarbonApprovalStatus.pending => const Color(0xFFE89218),
      CarbonApprovalStatus.approvedByOwner ||
      CarbonApprovalStatus.approvedByAdmin => const Color(0xFF1D5B48),
      CarbonApprovalStatus.rejectedByOwner ||
      CarbonApprovalStatus.rejectedByAdmin => AppColors.error,
    };
  }

  String _shortNumber(double value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(0)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toInt().toString();
  }

}

class _CarbonStatusLegend extends StatelessWidget {
  const _CarbonStatusLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 5,
      children: const [
        _CarbonStatusLegendItem(
          color: Color(0xFFE89218),
          label: 'Chờ duyệt',
        ),
        _CarbonStatusLegendItem(
          color: Color(0xFF1D5B48),
          label: 'Đã duyệt',
        ),
        _CarbonStatusLegendItem(
          color: AppColors.error,
          label: 'Từ chối',
        ),
      ],
    );
  }
}

class _CarbonStatusLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _CarbonStatusLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.beVietnamPro(fontSize: 11, color: AppColors.secondary),
        ),
      ],
    );
  }
}

class _DashboardOwnerScreenState extends State<DashboardOwnerScreen> {
  final _fs = FirestoreService.instance;
  String _ownerId = '';
  
  ForestOwnerModel? _ownerModel;
  List<ForestProjectModel> _projects = [];
  List<CarbonResultModel> _carbonResults = [];
  List<CarbonResultModel> _carbonHistory = [];
  List<LogEntryModel> _logEntries = [];
  
  StreamSubscription? _ownerSub;
  StreamSubscription? _projectSub;
  StreamSubscription? _carbonSub;
  StreamSubscription? _logEntriesSub;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initOwnerId();
  }

  void _initOwnerId() async {
    // Lấy ownerId từ AuthService (Firestore) thay vì LocalAccountStore
    final userModel = AuthService.instance.currentUserModel ?? 
        await AuthService.instance.getCurrentUserModel();
    
    if (userModel != null && userModel.ownerId.isNotEmpty) {
      _ownerId = userModel.ownerId;
    } else {
      // Fallback: thử lấy từ LocalAccountStore
      final account = LocalAccountStore.instance.currentAccount;
      _ownerId = account?['ownerId'] ?? account?['uid'] ?? '';
    }
    
    if (_ownerId.isNotEmpty) {
      _initStreams();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _initStreams() {
    if (_ownerId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // Stream owner data
    _ownerSub = _fs.streamForestOwner(_ownerId).listen((owner) {
      if (mounted) setState(() => _ownerModel = owner);
    });

    // Stream projects của chủ rừng
    _projectSub = _fs.streamForestProjects(ownerId: _ownerId).listen((projs) {
      if (mounted) {
        setState(() => _projects = projs);
        
        // Khởi tạo carbon stream
        if (projs.isEmpty) {
          _carbonSub?.cancel();
          _carbonSub = null;
          if (mounted) setState(() {
            _carbonResults = [];
            _carbonHistory = [];
            _isLoading = false;
          });
        } else {
          _initCarbonStream();
        }
      }
    });
  }

  void _initCarbonStream() {
    if (_ownerId.isEmpty || _projects.isEmpty) return;
    
    _carbonSub?.cancel();
    _carbonSub = _fs.streamAllCarbonResults().listen((results) {
      if (mounted) {
        final projectIds = _projects.map((p) => p.id).toSet();
        // KPI chỉ dùng kết quả đã duyệt; biểu đồ hiển thị cả lịch sử mới nhất
        // để chủ rừng nhìn được các bản ghi đang chờ duyệt.
        final projectResults = results
            .where((result) => projectIds.contains(result.projectId))
            .toList()
          ..sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));
        final approvedResults = projectResults
            .where(
              (result) => result.status == CarbonApprovalStatus.approvedByOwner,
            )
            .toList();
        final Map<String, CarbonResultModel> latestResults = {};
        for (final result in approvedResults) {
          if (!latestResults.containsKey(result.projectId)) {
            latestResults[result.projectId] = result;
          }
        }
        setState(() {
          _carbonResults = latestResults.values.toList();
          _carbonHistory = projectResults;
        });
      }
    });
    
    // Initialize log entries stream
    _initLogEntriesStream();
  }

  void _initLogEntriesStream() {
    if (_ownerId.isEmpty || _projects.isEmpty) return;
    
    _logEntriesSub?.cancel();
    _logEntriesSub = _fs.streamAllLogEntries().listen((entries) {
      if (mounted) {
        final projectIds = _projects.map((p) => p.id).toSet();
        final relevantEntries = entries.where((e) => projectIds.contains(e.projectId)).toList();
        // Sort by date descending
        relevantEntries.sort((a, b) => b.date.compareTo(a.date));
        setState(() {
          _logEntries = relevantEntries;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _ownerSub?.cancel();
    _projectSub?.cancel();
    _carbonSub?.cancel();
    _logEntriesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= AppBreakpoints.web;
    
    // Lấy thông tin hiển thị từ owner model hoặc AuthService
    final userModel = AuthService.instance.currentUserModel;
    final ownerName = _ownerModel?.ownerName ?? userModel?.ownerName ?? userModel?.fullName ?? 'Chủ rừng';
    final forestName = _ownerModel?.forestName ?? userModel?.forestName ?? 'Khu vực rừng của bạn';
    final province = _ownerModel?.managementProvince ?? userModel?.managementProvince ?? '';
    
    // Sử dụng diện tích của chủ rừng, không phải tổng diện tích dự án
    final totalArea = _ownerModel?.totalAreaHa ?? 0.0;
    
    // Sử dụng tổng số cây từ hệ số loài của chủ rừng
    final totalTrees = _ownerModel?.totalTrees ?? 0;
    
    final projectCount = _projects.length;
    
    // Tính carbon tích lũy trung bình (không phải tổng)
    final averageCarbon = _carbonResults.isEmpty 
        ? 0.0
        : _carbonResults.fold<double>(0, (sum, res) => sum + res.co2eTon) / _carbonResults.length;

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= AppBreakpoints.tablet;
    final latestCarbon = _carbonHistory.take(3).toList();
    final latestPhotoLogs = _logEntries
        .where((entry) => entry.photoUrls.isNotEmpty)
        .take(3)
        .toList();
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
        drawer: _buildOwnerDrawer(context),
        appBar: AppBar(
          title: const Text('Tổng quan chủ rừng'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Thông báo',
              onPressed: () => context.push(AppRoutes.notifications),
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
                        _OwnerHero(
                          ownerName: ownerName,
                          forestName: forestName,
                          province: province,
                          projectCount: projectCount,
                        ),
                        const SizedBox(height: 28),
                        GridView.count(
                          crossAxisCount: isWeb ? 5 : (isTablet ? 2 : 2),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: isWeb ? 1.75 : 1.35,
                          children: [
                            _OwnerKpiCard(
                              label: 'Dự án của tôi',
                              value: NumberFormat('#,##0').format(projectCount),
                              icon: Icons.account_tree_outlined,
                              accent: const Color(0xFF2477D4),
                            ),
                            _OwnerWorkerCountCard(ownerId: _ownerId),
                            _OwnerKpiCard(
                              label: 'Tổng diện tích',
                              value: totalArea > 0 ? NumberFormat('#,##0.##').format(totalArea) : '—',
                              unit: 'ha',
                              icon: Icons.map_outlined,
                              accent: const Color(0xFF00A06A),
                            ),
                            _OwnerKpiCard(
                              label: 'Số cây trồng',
                              value: NumberFormat('#,##0').format(totalTrees),
                              icon: Icons.forest_outlined,
                              accent: const Color(0xFF7C4DCC),
                            ),
                            _OwnerKpiCard(
                              label: 'Carbon tích lũy',
                              value: averageCarbon > 0 ? _formatCarbon(averageCarbon) : '—',
                              unit: 'tCO₂e',
                              icon: Icons.eco_outlined,
                              accent: const Color(0xFFE89218),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        Text(
                          'Theo dõi khu rừng',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        isWeb
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: _OwnerCarbonHistoryChart(results: latestCarbon),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: _OwnerMapOverview(
                                      projects: _projects,
                                      onViewMap: () => context.push(AppRoutes.map),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _OwnerCarbonHistoryChart(results: latestCarbon),
                                  const SizedBox(height: 14),
                                  _OwnerMapOverview(
                                    projects: _projects,
                                    onViewMap: () => context.push(AppRoutes.map),
                                  ),
                                ],
                              ),
                        const SizedBox(height: 36),
                        Text(
                          'Nhật ký hình ảnh hiện trường gần nhất',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ba nhật ký có hình ảnh mới nhất từ khu rừng của bạn',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (latestPhotoLogs.isEmpty)
                          const _OwnerEmptyState(
                            message: 'Chưa có nhật ký hiện trường kèm hình ảnh.',
                          )
                        else if (isWeb)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var index = 0; index < latestPhotoLogs.length; index++) ...[
                                Expanded(
                                  child: _OwnerPhotoLogCard(
                                    entry: latestPhotoLogs[index],
                                    projectName: _projectNameFor(latestPhotoLogs[index].projectId),
                                  ),
                                ),
                                if (index != latestPhotoLogs.length - 1)
                                  const SizedBox(width: 16),
                              ],
                            ],
                          )
                        else
                          Column(
                            children: [
                              for (var index = 0; index < latestPhotoLogs.length; index++) ...[
                                _OwnerPhotoLogCard(
                                  entry: latestPhotoLogs[index],
                                  projectName: _projectNameFor(latestPhotoLogs[index].projectId),
                                ),
                                if (index != latestPhotoLogs.length - 1)
                                  const SizedBox(height: 14),
                              ],
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

  String _formatCarbon(double value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(2)} tỷ';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)} triệu';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)} nghìn';
    return NumberFormat('#,##0.##').format(value);
  }

  String _projectNameFor(String projectId) {
    final matches = _projects.where((project) => project.id == projectId);
    return matches.isEmpty ? 'Dự án không xác định' : matches.first.projectName;
  }

  Widget _buildOwnerDrawer(BuildContext context) {
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
          _OwnerDrawerItem(
            icon: Icons.dashboard_outlined,
            title: 'Tổng quan',
            route: AppRoutes.dashboardOwner,
          ),
          _OwnerDrawerItem(
            icon: Icons.map_outlined,
            title: 'Bản đồ',
            route: AppRoutes.map,
          ),
          _OwnerDrawerItem(
            icon: Icons.groups_2_outlined,
            title: 'Quản lý Forest Worker',
            route: AppRoutes.forestWorkers,
          ),
          _OwnerDrawerItem(
            icon: Icons.forest_outlined,
            title: 'Quản lý Dự án',
            route: AppRoutes.forestProjects,
          ),
          _OwnerDrawerItem(
            icon: Icons.folder,
            title: 'Quản lý Tài liệu',
            route: AppRoutes.fileManager,
          ),
          const Divider(),
          _OwnerDrawerItem(
            icon: Icons.eco_outlined,
            title: 'Tính toán Carbon',
            route: AppRoutes.carbon,
          ),
          _OwnerDrawerItem(
            icon: Icons.settings,
            title: 'Hệ số phát thải',
            route: AppRoutes.speciesFactors,
          ),
          _OwnerDrawerItem(
            icon: Icons.picture_as_pdf,
            title: 'Báo cáo PDF',
            route: AppRoutes.reports,
          ),
          const Divider(),
          _OwnerDrawerItem(
            icon: Icons.notifications,
            title: 'Thông báo',
            route: AppRoutes.notifications,
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

class _OwnerMapOverview extends StatelessWidget {
  final List<ForestProjectModel> projects;
  final VoidCallback onViewMap;

  const _OwnerMapOverview({
    required this.projects,
    required this.onViewMap,
  });

  static const _zoneColors = [
    Color(0xFF00A06A),
    Color(0xFF2477D4),
    Color(0xFFE89218),
    Color(0xFF7C4DCC),
  ];

  @override
  Widget build(BuildContext context) {
    final mappedProjects = projects.where((project) => project.polygon.length >= 3).toList();
    final allPoints = mappedProjects
        .expand((project) => project.polygon)
        .map((point) => LatLng(point.lat, point.lng))
        .toList();

    return _OwnerSurfaceCard(
      title: 'Bản đồ khu rừng',
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
                    initialCenter: _centerFor(allPoints),
                    initialZoom: _overviewZoom(allPoints),
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.forestcarbon.app',
                    ),
                    if (mappedProjects.isNotEmpty)
                      PolygonLayer(
                        polygons: mappedProjects.map((project) {
                          final color = _zoneColors[
                              project.ownerId.hashCode.abs() % _zoneColors.length];
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
                  ],
                ),
              ),
              if (mappedProjects.isEmpty)
                const Positioned.fill(child: ColoredBox(color: Color(0x660C342A))),
              if (mappedProjects.isEmpty)
                Center(
                  child: Text(
                    'Thêm ranh giới dự án để xem bản đồ',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
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
            ],
          ),
        ),
      ),
    );
  }

  LatLng _centerFor(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(12.6667, 108.0383);
    return LatLng(
      points.fold<double>(0, (sum, point) => sum + point.latitude) / points.length,
      points.fold<double>(0, (sum, point) => sum + point.longitude) / points.length,
    );
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

class _OwnerPhotoLogCard extends StatelessWidget {
  final LogEntryModel entry;
  final String projectName;

  const _OwnerPhotoLogCard({required this.entry, required this.projectName});

  @override
  Widget build(BuildContext context) {
    final photoUrl = entry.photoUrls.first;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: photoUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => Container(
                color: const Color(0xFFE9F1EC),
                child: const Center(
                  child: Icon(Icons.image_not_supported_outlined, color: AppColors.secondary),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2F3E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.photo_camera_outlined,
                          size: 16, color: Color(0xFF14804A)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.workType.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(entry.date),
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: AppColors.secondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF14804A),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  entry.description.isEmpty ? 'Không có mô tả cho nhật ký này.' : entry.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${entry.photoUrls.length} hình ảnh hiện trường',
                  style: GoogleFonts.beVietnamPro(fontSize: 11, color: AppColors.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerEmptyState extends StatelessWidget {
  final String message;

  const _OwnerEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 230,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDE8)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.beVietnamPro(fontSize: 14, color: AppColors.secondary),
      ),
    );
  }
}

class _OwnerDrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;

  const _OwnerDrawerItem({
    required this.icon,
    required this.title,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        context.push(route);
      },
    );
  }
}
