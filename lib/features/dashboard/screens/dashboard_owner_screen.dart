import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/services/local_account_store.dart';
import 'package:forest_carbon_platform/core/services/auth_service.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/models/carbon_result_model.dart';
import 'package:forest_carbon_platform/core/models/log_entry_model.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';

class DashboardOwnerScreen extends StatefulWidget {
  const DashboardOwnerScreen({super.key});

  @override
  State<DashboardOwnerScreen> createState() => _DashboardOwnerScreenState();
}

class _DashboardOwnerScreenState extends State<DashboardOwnerScreen> {
  final _fs = FirestoreService.instance;
  late String _ownerId;
  
  ForestOwnerModel? _ownerModel;
  List<ForestProjectModel> _projects = [];
  List<CarbonResultModel> _carbonResults = [];
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
    _initStreams();
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
        // Lấy kết quả mới nhất cho mỗi dự án (chỉ lấy approved results)
        final Map<String, CarbonResultModel> latestResults = {};
        for (var r in results) {
          if (projectIds.contains(r.projectId) && r.status == CarbonApprovalStatus.approvedByOwner) {
            if (!latestResults.containsKey(r.projectId) || 
                r.calculatedAt.isAfter(latestResults[r.projectId]!.calculatedAt)) {
              latestResults[r.projectId] = r;
            }
          }
        }
        setState(() {
          _carbonResults = latestResults.values.toList();
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

    return Scaffold(
      backgroundColor: AppColors.neutral,
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
                        'Chào mừng quay lại, $ownerName',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        province.isEmpty
                            ? 'Thông tin cập nhật mới nhất của $forestName'
                            : 'Thông tin cập nhật mới nhất của $forestName tại $province',
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
                        children: [
                          AppKpiCard(
                            label: 'Dự án của tôi',
                            value: projectCount > 0 ? NumberFormat('#,###').format(projectCount) : 'Chưa có dữ liệu',
                            icon: Icons.folder_outlined,
                          ),
                          AppKpiCard(
                            label: 'Tổng diện tích',
                            value: totalArea > 0 ? NumberFormat('#,###.##').format(totalArea) : 'Chưa có dữ liệu',
                            unit: totalArea > 0 ? 'ha' : '',
                            icon: Icons.map_outlined,
                          ),
                          AppKpiCard(
                            label: 'Số cây trồng',
                            value: totalTrees > 0 ? NumberFormat('#,###').format(totalTrees) : 'Chưa có dữ liệu',
                            icon: Icons.park_outlined,
                          ),
                          AppKpiCard(
                            label: 'Carbon tích lũy',
                            value: averageCarbon > 0 ? NumberFormat('#,###.##').format(averageCarbon) : 'Chưa có dữ liệu',
                            unit: averageCarbon > 0 ? 'tCO₂e' : '',
                            icon: Icons.eco_outlined,
                            iconColor: AppColors.tertiary,
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Recent Carbon Calculations
                      Text(
                        'Tính toán carbon gần nhất',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      
                      if (_carbonResults.isEmpty)
                        AppCard(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Center(
                              child: Text(
                                'Chưa có tính toán carbon nào.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
                              ),
                            ),
                          ),
                        )
                      else
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _carbonResults.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final carbon = _carbonResults[index];
                              final project = _projects.firstWhere(
                                (p) => p.id == carbon.projectId,
                                orElse: () => ForestProjectModel(
                                  id: '', projectName: 'Dự án không xác định', ownerId: '', 
                                  province: '', district: '', commune: '', forestType: '', 
                                  treeSpecies: '', yearPlanted: 0, status: ProjectStatus.draft, 
                                  createdAt: DateTime.now(), updatedAt: DateTime.now(),
                                ),
                              );

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.tertiary.withValues(alpha: 0.1),
                                  child: Icon(Icons.eco, color: AppColors.tertiary),
                                ),
                                title: Text(project.projectName),
                                subtitle: Text(
                                  '${NumberFormat('#,###.##').format(carbon.co2eTon)} tCO₂e - ${carbon.breakdown.length} loài cây',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                trailing: Text(
                                  DateFormat('dd MMM, yyyy').format(carbon.calculatedAt),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: AppSpacing.lg),

                      // Latest Field Journal Entry
                      Text(
                        'Nhật ký hiện trường gần nhất',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      
                      if (_logEntries.isEmpty)
                        AppCard(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Center(
                              child: Text(
                                'Chưa có nhật ký hiện trường nào.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
                              ),
                            ),
                          ),
                        )
                      else
                        AppCard(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: _buildLatestLogEntry(_logEntries.first),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLatestLogEntry(LogEntryModel entry) {
    final project = _projects.firstWhere(
      (p) => p.id == entry.projectId,
      orElse: () => ForestProjectModel(
        id: '', projectName: 'Dự án không xác định', ownerId: '', 
        province: '', district: '', commune: '', forestType: '', 
        treeSpecies: '', yearPlanted: 0, status: ProjectStatus.draft, 
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loại công việc: ${entry.workType.label}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dự án: ${project.projectName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                  ),
                ],
              ),
            ),
            Text(
              DateFormat('dd/MM/yyyy').format(entry.date),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Mô tả: ${entry.description.isEmpty ? "Không có mô tả" : entry.description}',
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (entry.gps != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'GPS: ${entry.gps!.lat.toStringAsFixed(4)}, ${entry.gps!.lng.toStringAsFixed(4)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.secondary,
            ),
          ),
        ],
        if (entry.photoUrls.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ảnh: ${entry.photoUrls.length} hình',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.secondary,
            ),
          ),
        ],
      ],
    );
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
