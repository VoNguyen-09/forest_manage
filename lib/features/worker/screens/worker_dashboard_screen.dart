import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/carbon_result_model.dart';
import 'package:forest_carbon_platform/core/models/file_document_model.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/models/gps_point.dart';
import 'package:forest_carbon_platform/core/models/log_entry_model.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/core/models/worker_location_model.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:forest_carbon_platform/core/services/auth_service.dart';
import 'package:forest_carbon_platform/core/services/cloudinary_service.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/features/worker/services/field_log_pdf_service.dart';
import 'package:forest_carbon_platform/features/worker/services/worker_offline_sync_service.dart';
import 'package:forest_carbon_platform/shared/widgets/app_button.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen>
    with WidgetsBindingObserver {
  final _auth = AuthService.instance;
  final _db = FirestoreService.instance;

  UserModel? _user;
  ForestOwnerModel? _owner;
  List<ForestProjectModel> _projects = [];
  List<ForestProjectModel> _allOwnerProjects = [];
  ForestProjectModel? _selectedProject;
  int _tabIndex = 0;
  bool _isLoading = true;
  bool _gpsSharing = false;
  Timer? _gpsTimer;
  Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsTimer?.cancel();
    final uid = _user?.uid;
    if (uid != null && uid.isNotEmpty) {
      _db.setWorkerOffline(uid);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(WorkerOfflineSyncService.instance.syncPending());
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final uid = _user?.uid;
      if (uid != null && uid.isNotEmpty) _db.setWorkerOffline(uid);
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _auth.getCurrentUserModel(throwOnError: true);
      if (user == null) {
        throw StateError('Không tìm thấy hồ sơ người dùng.');
      }
      final projects = user.assignedProjectIds.isEmpty
          ? <ForestProjectModel>[]
          : await _db.listForestProjectsByIds(user.assignedProjectIds);
      final effectiveOwnerId = projects.isNotEmpty
          ? projects.first.ownerId
          : user.ownerId;
      ForestOwnerModel? owner;
      List<ForestProjectModel> allOwnerProjects = [];
      if (effectiveOwnerId.isNotEmpty) {
        owner = await _db.getForestOwner(effectiveOwnerId);
        allOwnerProjects = await _db.listForestProjects(
          ownerId: effectiveOwnerId,
        );
      }
      final resolvedProjects = projects
          .map(
            (project) =>
                _resolveProjectWithLatestBoundary(project, allOwnerProjects),
          )
          .toList();
      await WorkerOfflineSyncService.instance.cacheWorkerContext(
        user: user,
        owner: owner,
        projects: resolvedProjects,
        allOwnerProjects: allOwnerProjects,
      );
      // Nạp sẵn hệ số để Worker vẫn tính carbon được sau khi mở lại tab lúc
      // offline, kể cả khi họ chưa từng vào Carbon ở phiên hiện tại.
      unawaited(_cacheProjectSpeciesFactors(resolvedProjects));
      await WorkerOfflineSyncService.instance.activateForWorker(user.uid);
      if (!mounted) return;
      setState(() {
        _user = user;
        _owner = owner;
        _allOwnerProjects = allOwnerProjects;
        _projects = resolvedProjects;
        _selectedProject = resolvedProjects.isNotEmpty
            ? resolvedProjects.first
            : null;
        _isLoading = false;
      });
    } catch (e) {
      final uid = _auth.currentUser?.uid;
      final cached = uid == null
          ? null
          : await WorkerOfflineSyncService.instance.getCachedWorkerContext(uid);
      if (cached != null) {
        await WorkerOfflineSyncService.instance.activateForWorker(cached.user.uid);
        if (!mounted) return;
        setState(() {
          _user = cached.user;
          _owner = cached.owner;
          _projects = cached.projects;
          _allOwnerProjects = cached.allOwnerProjects;
          _selectedProject = cached.projects.isEmpty ? null : cached.projects.first;
          _isLoading = false;
        });
        _showSuccess('Đang dùng dữ liệu đã lưu trên thiết bị.');
        return;
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Không tải được dữ liệu worker: $e');
    }
  }

  ForestProjectModel _resolveProjectWithLatestBoundary(
    ForestProjectModel project,
    List<ForestProjectModel> allOwnerProjects,
  ) {
    final sameId = allOwnerProjects.where((p) => p.id == project.id);
    if (sameId.isNotEmpty) return sameId.first;

    if (project.polygon.length >= 3) return project;

    final sameName = allOwnerProjects.where(
      (p) =>
          p.projectName.trim().toLowerCase() ==
              project.projectName.trim().toLowerCase() &&
          p.polygon.length >= 3,
    );
    if (sameName.isNotEmpty) return sameName.first;

    return project;
  }

  Future<void> _cacheProjectSpeciesFactors(
    List<ForestProjectModel> projects,
  ) async {
    try {
      for (final project in projects) {
        final species = project.treeSpecies.trim();
        if (species.isEmpty) continue;
        final factors = await _db.listSpeciesFactorsByNames([species]);
        if (factors.isNotEmpty) {
          await WorkerOfflineSyncService.instance.cacheSpeciesFactors(
            project.id,
            factors,
          );
        }
      }
    } catch (_) {
      // Không chặn màn hình chính nếu pre-cache lỗi; WorkerCarbonTab sẽ tự
      // fallback cache hoặc hiển thị lỗi rõ ràng khi người dùng mở tab.
    }
  }

  Future<void> _refreshProjectBoundaries() async {
    final current = _selectedProject;
    if (current == null) return;
    try {
      final latestSelected = await _db.getForestProject(current.id);
      final ownerId = latestSelected?.ownerId.isNotEmpty == true
          ? latestSelected!.ownerId
          : current.ownerId;
      final allOwnerProjects = ownerId.isNotEmpty
          ? await _db.listForestProjects(ownerId: ownerId)
          : _allOwnerProjects;
      final resolvedCurrent = _resolveProjectWithLatestBoundary(
        latestSelected ?? current,
        allOwnerProjects,
      );
      if (!mounted) return;
      setState(() {
        _allOwnerProjects = allOwnerProjects;
        _selectedProject = resolvedCurrent;
        _projects = _projects
            .map(
              (project) => project.id == current.id ? resolvedCurrent : project,
            )
            .toList();
      });
    } catch (e) {
      _showError('Không tải lại được ranh giới dự án: $e');
    }
  }

  Future<Position> _getCurrentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Chưa cấp quyền GPS cho ứng dụng.');
    }
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError('GPS trên điện thoại đang tắt.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    if (mounted) setState(() => _lastPosition = position);
    return position;
  }

  Future<void> _toggleGpsSharing() async {
    if (_gpsSharing) {
      _gpsTimer?.cancel();
      _gpsTimer = null;
      setState(() => _gpsSharing = false);
      final uid = _user?.uid;
      if (uid != null && uid.isNotEmpty) await _db.setWorkerOffline(uid);
      return;
    }

    try {
      await _publishWorkerLocation();
      _gpsTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        _publishWorkerLocation().catchError(
          (e) => _showError('Không cập nhật được GPS: $e'),
        );
      });
      setState(() => _gpsSharing = true);
    } catch (e) {
      _showError('Không bật được GPS: $e');
    }
  }

  Future<void> _publishWorkerLocation() async {
    final user = _user;
    final project = _selectedProject;
    if (user == null || project == null) {
      throw StateError('Worker chưa được gắn với dự án.');
    }
    final pos = await _getCurrentPosition();
    await _db.saveWorkerLocation(
      WorkerLocationModel(
        workerId: user.uid,
        workerName: user.fullName.isNotEmpty ? user.fullName : user.email,
        ownerId: project.ownerId,
        projectId: project.id,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
        isOnline: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
  }

  Future<void> _logout() async {
    _gpsTimer?.cancel();
    final uid = _user?.uid;
    if (uid != null && uid.isNotEmpty) await _db.setWorkerOffline(uid);
    if (uid != null && uid.isNotEmpty) {
      WorkerOfflineSyncService.instance.deactivateWorker(uid);
    }
    await _auth.signOut();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final project = _selectedProject;
    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: AppSpacing.md,
        title: Row(
          children: [
            const Icon(Icons.forest_outlined, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Forest Worker',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.logout,
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.neutral,
        onDestinationSelected: (index) {
          setState(() => _tabIndex = index);
          if (index == 3) {
            _refreshProjectBoundaries();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: 'Nhật ký',
          ),
          NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            selectedIcon: Icon(Icons.eco),
            label: 'Carbon',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Đã lưu',
          ),
          NavigationDestination(
            icon: Icon(Icons.gps_fixed_outlined),
            selectedIcon: Icon(Icons.gps_fixed),
            label: 'GPS',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
          ? _EmptyWorkerState(onRefresh: _loadInitialData)
          : IndexedStack(
              index: _tabIndex,
              children: [
                _buildWorkerFormTab(project!, isCarbon: false),
                _buildWorkerFormTab(project!, isCarbon: true),
                WorkerSavedRecordsTab(
                  userId: _user!.uid,
                  projectId: project!.id,
                ),
                WorkerGpsMapTab(
                  isSharing: _gpsSharing,
                  lastPosition: _lastPosition,
                  owner: _owner,
                  selectedProject: project!,
                  allOwnerProjects: _allOwnerProjects,
                  onToggle: () => _toggleGpsSharing(),
                  onRefreshPosition: () {
                    _publishWorkerLocation().catchError(
                      (e) => _showError('Không cập nhật được GPS: $e'),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildWorkerFormTab(
    ForestProjectModel project, {
    required bool isCarbon,
  }) {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _WorkerSummary(user: _user, project: project),
          const SizedBox(height: AppSpacing.md),
          if (isCarbon)
            WorkerCarbonTab(
              user: _user!,
              project: project,
              onSaved: _showSuccess,
              onError: _showError,
            )
          else
            WorkerLogbookTab(
              user: _user!,
              project: project,
              getPosition: _getCurrentPosition,
              onSaved: _showSuccess,
              onError: _showError,
            ),
        ],
      ),
    );
  }
}

class _WorkerSummary extends StatelessWidget {
  final UserModel? user;
  final ForestProjectModel? project;

  const _WorkerSummary({required this.user, required this.project});

  @override
  Widget build(BuildContext context) {
    final name = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : user?.email ?? 'Forest worker';
    final forestName = user?.forestName.isNotEmpty == true
        ? user!.forestName
        : 'Khu vực hiện trường';
    final projectName = project?.projectName ?? 'Chưa chọn dự án';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF17493C), Color(0xFF28745C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24143E33),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_ind_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const Icon(Icons.verified_rounded, color: Color(0xFF9FE3BD), size: 20),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'DỰ ÁN ĐANG THỰC HIỆN',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFC9E5D8),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            projectName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            forestName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFD8EDE3),
                ),
          ),
        ],
      ),
    );
  }
}

class WorkerSavedRecordsTab extends StatelessWidget {
  final String userId;
  final String projectId;

  const WorkerSavedRecordsTab({
    super.key,
    required this.userId,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Dữ liệu đã lưu trên thiết bị',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _syncNow(context),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Đồng bộ'),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.18)),
            ),
            child: TabBar(
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.tertiary,
                borderRadius: BorderRadius.circular(14),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.secondary,
              tabs: const [
                Tab(icon: Icon(Icons.menu_book_outlined), text: 'Nhật ký đã lưu'),
                Tab(icon: Icon(Icons.eco_outlined), text: 'Carbon đã lưu'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SavedWorkerLogs(userId: userId, projectId: projectId),
                _SavedWorkerCarbons(userId: userId, projectId: projectId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncNow(BuildContext context) async {
    final report = await WorkerOfflineSyncService.instance.syncPending();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (report.hasChanges) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Đã đồng bộ ${report.syncedLogs} nhật ký và ${report.syncedCarbons} kết quả carbon.',
          ),
        ),
      );
    } else if (report.hasErrors) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Chưa đồng bộ được. Dữ liệu vẫn được giữ an toàn để thử lại.'),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Không có dữ liệu chờ hoặc thiết bị chưa có mạng.'),
        ),
      );
    }
  }
}

class _SavedWorkerLogs extends StatelessWidget {
  final String userId;
  final String projectId;

  const _SavedWorkerLogs({required this.userId, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PendingWorkerLog>>(
      stream: WorkerOfflineSyncService.instance.watchPendingLogs(
        userId: userId,
        projectId: projectId,
      ),
      builder: (context, snapshot) {
        final pending = snapshot.data ?? const <PendingWorkerLog>[];
        return StreamBuilder<List<LogEntryModel>>(
          stream: FirestoreService.instance.streamWorkerLogEntries(userId),
          builder: (context, remoteSnapshot) {
            final logs = (remoteSnapshot.data ?? [])
                .where((entry) => entry.projectId == projectId)
                .toList();
            if (pending.isEmpty &&
                remoteSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (pending.isEmpty && logs.isEmpty) {
              return const _WorkerSavedEmptyState(
                icon: Icons.menu_book_outlined,
                message: 'Chưa có nhật ký nào được lưu cho dự án này.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: pending.length + logs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index < pending.length) {
                  return _PendingLogTile(entry: pending[index]);
                }
                return _SavedLogTile(entry: logs[index - pending.length]);
              },
            );
          },
        );
      },
    );
  }
}

class _SavedLogTile extends StatelessWidget {
  final LogEntryModel entry;

  const _SavedLogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showLogDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  entry.photoUrls.isEmpty
                      ? Icons.edit_note_outlined
                      : Icons.photo_library_outlined,
                  color: AppColors.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.workType.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.description.isEmpty ? 'Không có mô tả' : entry.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDate(entry.date),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${entry.photoUrls.length} ảnh',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.tertiary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.workType.label, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(_formatDate(entry.date), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                Text(entry.description.isEmpty ? 'Không có mô tả.' : entry.description),
                const SizedBox(height: 16),
                Text('Vị trí GPS', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${entry.gps.lat.toStringAsFixed(5)}, ${entry.gps.lng.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (entry.photoUrls.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Ảnh hiện trường (${entry.photoUrls.length})',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: entry.photoUrls.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          entry.photoUrls[index],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 120,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingLogTile extends StatelessWidget {
  final PendingWorkerLog entry;

  const _PendingLogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.sync_outlined, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.workType.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.description.isEmpty ? 'Không có mô tả' : entry.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 3),
                Text(
                  'Đang chờ đồng bộ',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatDate(entry.date), style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 5),
              Text(
                '${entry.photoCount} ảnh',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.orange.shade800,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavedWorkerCarbons extends StatelessWidget {
  final String userId;
  final String projectId;

  const _SavedWorkerCarbons({required this.userId, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CarbonResultModel>>(
      stream: WorkerOfflineSyncService.instance.watchPendingCarbons(
        workerId: userId,
        projectId: projectId,
      ),
      builder: (context, snapshot) {
        final pending = snapshot.data ?? const <CarbonResultModel>[];
        return StreamBuilder<List<CarbonResultModel>>(
          stream: FirestoreService.instance.streamCarbonResultsForProject(projectId),
          builder: (context, remoteSnapshot) {
            final results = remoteSnapshot.data ?? const <CarbonResultModel>[];
            if (pending.isEmpty &&
                remoteSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (pending.isEmpty && results.isEmpty) {
              return const _WorkerSavedEmptyState(
                icon: Icons.eco_outlined,
                message: 'Chưa có kết quả carbon nào được lưu.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: pending.length + results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index < pending.length) {
                  return _SavedCarbonTile(
                    result: pending[index],
                    isPendingSync: true,
                  );
                }
                return _SavedCarbonTile(
                  result: results[index - pending.length],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SavedCarbonTile extends StatelessWidget {
  final CarbonResultModel result;
  final bool isPendingSync;

  const _SavedCarbonTile({required this.result, this.isPendingSync = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isPendingSync ? Colors.orange : AppColors.tertiary)
              .withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isPendingSync ? Colors.orange : AppColors.tertiary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPendingSync ? Icons.sync_outlined : Icons.eco_outlined,
              color: isPendingSync ? Colors.orange : AppColors.tertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.co2eTon.toStringAsFixed(3)} tCO₂e',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${result.totalBiomassKg.toStringAsFixed(1)} kg sinh khối · ${result.breakdown.length} loài',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (isPendingSync) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Đang chờ đồng bộ',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ],
            ),
          ),
          Text(_formatDate(result.calculatedAt), style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _WorkerSavedEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _WorkerSavedEmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.secondary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class WorkerLogbookTab extends StatefulWidget {
  final UserModel user;
  final ForestProjectModel project;
  final Future<Position> Function() getPosition;
  final ValueChanged<String> onSaved;
  final ValueChanged<String> onError;

  const WorkerLogbookTab({
    super.key,
    required this.user,
    required this.project,
    required this.getPosition,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<WorkerLogbookTab> createState() => _WorkerLogbookTabState();
}

class _WorkerLogbookTabState extends State<WorkerLogbookTab> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  final _db = FirestoreService.instance;
  final _cloudinary = CloudinaryService.instance;
  final _pdfService = FieldLogPdfService.instance;

  WorkType _workType = WorkType.care;
  DateTime _date = DateTime.now();
  Position? _gps;
  List<XFile> _photos = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WorkerLogbookTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      setState(() {
        _gps = null;
        _photos = [];
        _descriptionController.clear();
      });
    }
  }

  Future<void> _pickPhotosFromGallery() async {
    final images = await _picker.pickMultiImage(imageQuality: 82);
    if (images.isEmpty) return;
    _appendPhotos(images);
  }

  Future<void> _takePhotoWithCamera() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 82,
    );
    if (image == null) return;
    _appendPhotos([image]);
  }

  void _appendPhotos(List<XFile> images) {
    final next = [..._photos, ...images];
    if (next.length > 10) {
      widget.onError('Tối đa 10 ảnh cho mỗi bản ghi nhật ký.');
    }
    setState(() => _photos = next.take(10).toList());
  }

  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      widget.onError('Vui lòng thêm ít nhất 1 ảnh hiện trường.');
      return;
    }

    setState(() => _isSaving = true);
    String? savedLogId;
    var uploadedPhotoUrls = <String>[];
    var uploadedPdfUrl = '';
    try {
      if (!await WorkerOfflineSyncService.instance.isNetworkAvailable()) {
        await _queueLogForSync();
        widget.onSaved(
          'Đã lưu nhật ký trên thiết bị. Nhật ký sẽ tự gửi cho chủ rừng khi có mạng.',
        );
        return;
      }

      final urls = <String>[];
      final photoFiles = _photos.map((x) => File(x.path)).toList();
      if (_photos.isNotEmpty) {
        urls.addAll(
          await _cloudinary.uploadImages(
            photoFiles,
            folder: 'field_logs/${widget.project.id}',
          ),
        );
      }
      uploadedPhotoUrls = urls;
      final now = DateTime.now();
      final entry = LogEntryModel(
        id: '',
        date: _date,
        userId: widget.user.uid,
        projectId: widget.project.id,
        gps: _gps != null
            ? GpsPoint(lat: _gps!.latitude, lng: _gps!.longitude)
            : const GpsPoint(lat: 0, lng: 0),
        workType: _workType,
        description: _descriptionController.text.trim(),
        photoUrls: urls,
        isSynced: true,
        createdAt: now,
        syncedAt: now,
      );
      final logId = await _db.saveLogEntry(entry);
      savedLogId = logId;
      final savedEntry = entry.copyWith(id: logId, photoUrls: urls);
      final pdfBytes = await _pdfService.buildFieldLogPdf(
        user: widget.user,
        project: widget.project,
        entry: savedEntry,
        photoFiles: photoFiles,
      );
      final pdfFileName = _buildFieldLogFileName(
        projectName: widget.project.projectName,
        date: _date,
        logId: logId,
      );
      final pdfUrl = await _cloudinary.uploadBytes(
        pdfBytes,
        identifier: pdfFileName,
        folder: 'field_log_pdfs/${widget.project.id}',
        extension: '.pdf',
      );
      uploadedPdfUrl = pdfUrl;
      await _db.saveFileDocument(
        FileDocumentModel(
          id: '',
          name: pdfFileName,
          category: 'Hình ảnh hiện trường',
          type: 'pdf',
          url: pdfUrl,
          ownerId: widget.project.ownerId,
          projectId: widget.project.id,
          uploadedBy: widget.user.uid,
          uploadedByName: widget.user.fullName.isNotEmpty
              ? widget.user.fullName
              : widget.user.email,
          source: 'workerLogbook',
          sourceLogId: logId,
          status: 'pending',
          photoUrls: urls,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (!mounted) return;
      setState(() {
        _photos = [];
        _gps = null;
        _date = DateTime.now();
        _descriptionController.clear();
      });
      widget.onSaved(
        'Đã lưu nhật ký và chuyển PDF sang Hình ảnh hiện trường. Chờ chủ rừng gửi Admin.',
      );
    } catch (e) {
      if (_shouldQueueForOffline(e)) {
        try {
          await _queueLogForSync(
            existingLogId: savedLogId,
            uploadedPhotoUrls: uploadedPhotoUrls,
            uploadedPdfUrl: uploadedPdfUrl,
          );
          widget.onSaved(
            'Không kết nối được máy chủ. Nhật ký đã lưu trên thiết bị và sẽ tự đồng bộ khi có mạng.',
          );
        } catch (queueError) {
          widget.onError('Không lưu được nhật ký: $queueError');
        }
      } else {
        widget.onError('Không lưu được nhật ký: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _queueLogForSync({
    String? existingLogId,
    List<String> uploadedPhotoUrls = const [],
    String uploadedPdfUrl = '',
  }) async {
    await WorkerOfflineSyncService.instance.queueLog(
      user: widget.user,
      project: widget.project,
      date: _date,
      workType: _workType,
      description: _descriptionController.text.trim(),
      gps: _gps != null
          ? GpsPoint(lat: _gps!.latitude, lng: _gps!.longitude)
          : const GpsPoint(lat: 0, lng: 0),
      photoSourcePaths: _photos.map((photo) => photo.path).toList(),
      jobId: existingLogId,
      uploadedPhotoUrls: uploadedPhotoUrls,
      pdfUrl: uploadedPdfUrl,
    );
    if (!mounted) return;
    setState(() {
      _photos = [];
      _gps = null;
      _date = DateTime.now();
      _descriptionController.clear();
    });
  }

  bool _shouldQueueForOffline(Object error) {
    final message = error.toString().toLowerCase();
    return error is SocketException ||
        message.contains('connection error') ||
        message.contains('network') ||
        message.contains('socket') ||
        message.contains('timed out');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.tertiary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit_note_outlined,
                          color: AppColors.tertiary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Viết nhật ký',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Ghi nhận hoạt động và ảnh hiện trường',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(_formatDate(_date)),
                  trailing: TextButton(
                    onPressed: _pickDate,
                    child: const Text('Chọn ngày'),
                  ),
                ),
                DropdownButtonFormField<WorkType>(
                  initialValue: _workType,
                  decoration: const InputDecoration(
                    labelText: 'Loại công việc',
                    prefixIcon: Icon(Icons.task_alt_outlined),
                  ),
                  items: WorkType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _workType = value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả công việc',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppStrings.fieldRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _PhotoPickerSummary(
                  photos: _photos,
                  onCamera: _takePhotoWithCamera,
                  onGallery: _pickPhotosFromGallery,
                  onRemove: (index) {
                    setState(() => _photos.removeAt(index));
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppPrimaryButton(
                  label: 'Lưu nhật ký',
                  onPressed: () => _saveLog(),
                  isLoading: _isSaving,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }
}

class WorkerCarbonTab extends StatefulWidget {
  final UserModel user;
  final ForestProjectModel project;
  final ValueChanged<String> onSaved;
  final ValueChanged<String> onError;

  const WorkerCarbonTab({
    super.key,
    required this.user,
    required this.project,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<WorkerCarbonTab> createState() => _WorkerCarbonTabState();
}

class _WorkerCarbonTabState extends State<WorkerCarbonTab> {
  final _formKey = GlobalKey<FormState>();
  final _dbhController = TextEditingController();
  final _heightController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _db = FirestoreService.instance;

  List<SpeciesFactor> _factors = [];
  SpeciesFactor? _selectedFactor;
  bool _isLoading = true;
  bool _isSaving = false;
  CarbonBreakdownItem? _preview;

  @override
  void initState() {
    super.initState();
    _loadFactors();
  }

  @override
  void dispose() {
    _dbhController.dispose();
    _heightController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadFactors() async {
    setState(() => _isLoading = true);
    final projectSpecies = widget.project.treeSpecies.trim();
    final offline = WorkerOfflineSyncService.instance;
    // Firestore có thể trả về danh sách rỗng khi mất mạng (thay vì throw), nên
    // luôn đọc cache trước để tab Carbon vẫn hoạt động sau khi bị dispose/reopen.
    final cachedFactors = await offline.getCachedSpeciesFactors(widget.project.id);

    if (!await offline.isNetworkAvailable()) {
      if (_useCachedFactors(cachedFactors)) return;
      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onError(
        'Chưa có hệ số loài trên thiết bị. Hãy mở tab Carbon một lần khi có mạng trước khi dùng offline.',
      );
      return;
    }

    try {
      // Load only species factors for this project's tree species
      final List<SpeciesFactor> factors = projectSpecies.isNotEmpty
          ? await _db.listSpeciesFactorsByNames([projectSpecies])
          : <SpeciesFactor>[];

      if (factors.isNotEmpty) {
        await WorkerOfflineSyncService.instance.cacheSpeciesFactors(
          widget.project.id,
          factors,
        );
      }

      if (!mounted) return;

      if (factors.isEmpty && projectSpecies.isNotEmpty) {
        // Trường hợp mạng vừa mất hoặc Firestore trả cache rỗng: dùng dữ liệu
        // đã lưu thay vì báo nhầm rằng Admin chưa cấu hình hệ số.
        if (_useCachedFactors(cachedFactors)) return;
        setState(() => _isLoading = false);
        widget.onError(
          'Hệ số cho loài cây "$projectSpecies" chưa được cấu hình bởi admin.',
        );
        return;
      }

      setState(() {
        _factors = factors;
        _selectedFactor = factors.isNotEmpty ? factors.first : null;
        _isLoading = false;
      });
    } catch (e) {
      if (_useCachedFactors(cachedFactors)) return;
      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onError('Không tải được hệ số loài: $e');
    }
  }

  bool _useCachedFactors(List<SpeciesFactor> factors) {
    if (factors.isEmpty || !mounted) return false;
    setState(() {
      _factors = factors;
      _selectedFactor = factors.first;
      _isLoading = false;
    });
    widget.onSaved('Đang dùng hệ số loài đã lưu trên thiết bị.');
    return true;
  }

  void _calculatePreview() {
    if (!_formKey.currentState!.validate() || _selectedFactor == null) return;
    final item = _buildBreakdownItem();
    setState(() => _preview = item);
  }

  Future<void> _saveCarbon() async {
    if (!_formKey.currentState!.validate() || _selectedFactor == null) return;
    final item = _buildBreakdownItem();
    setState(() {
      _preview = item;
      _isSaving = true;
    });
    try {
      final result = CarbonResultModel(
        id: '',
        projectId: widget.project.id,
        ownerId: widget.project.ownerId,
        workerId: widget.user.uid,
        calculatedAt: DateTime.now(),
        totalBiomassKg: item.biomassKg,
        carbonStockTon: item.carbonTon,
        co2eTon: item.co2eTon,
        breakdown: [item],
      );
      if (!await WorkerOfflineSyncService.instance.isNetworkAvailable()) {
        await WorkerOfflineSyncService.instance.queueCarbon(result: result);
        if (!mounted) return;
        widget.onSaved(
          'Đã lưu kết quả carbon trên thiết bị. Kết quả sẽ tự gửi cho chủ rừng khi có mạng.',
        );
        return;
      }

      try {
        await _db.saveCarbonResult(result);
      } catch (error) {
        if (!_shouldQueueForOffline(error)) rethrow;
        await WorkerOfflineSyncService.instance.queueCarbon(result: result);
        if (!mounted) return;
        widget.onSaved(
          'Không kết nối được máy chủ. Kết quả carbon đã lưu trên thiết bị và sẽ tự đồng bộ khi có mạng.',
        );
        return;
      }
      if (!mounted) return;
      widget.onSaved('Đã lưu ước lượng carbon.');
    } catch (e) {
      widget.onError('Không lưu được carbon: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  CarbonBreakdownItem _buildBreakdownItem() {
    final dbh = double.parse(_dbhController.text.trim());
    final height = double.parse(_heightController.text.trim());
    final quantity = int.parse(_quantityController.text.trim());
    final factor = _selectedFactor!.factor;

    // Bước 1: Biomass của 1 cây (kg)
    final biomassPerTree = 0.05 * dbh * dbh * height;

    // Bước 2: Tổng sinh khối (kg)
    final totalBiomass = biomassPerTree * quantity;

    // Bước 3: Carbon Stock (đổi ra tấn)
    final carbonTon = (totalBiomass * factor) / 1000;

    // Bước 4: CO2e (tấn)
    final co2eTon = carbonTon * 3.667;

    return CarbonBreakdownItem(
      species: _selectedFactor!.speciesName,
      dbh: dbh,
      height: height,
      quantity: quantity,
      biomassFactor: factor,
      biomassKg: totalBiomass,
      carbonTon: carbonTon,
      co2eTon: co2eTon,
    );
  }

  bool _shouldQueueForOffline(Object error) {
    final message = error.toString().toLowerCase();
    return error is SocketException ||
        message.contains('connection error') ||
        message.contains('network') ||
        message.contains('socket') ||
        message.contains('timed out');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.tertiary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.eco_outlined,
                          color: AppColors.tertiary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ước lượng carbon',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Nhập số liệu cây để tính trữ lượng carbon',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<SpeciesFactor>(
                  initialValue: _selectedFactor,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Loại cây',
                    prefixIcon: Icon(Icons.eco_outlined),
                  ),
                  items: _factors
                      .map(
                        (factor) => DropdownMenuItem(
                          value: factor,
                          child: Text(
                            '${factor.speciesName} (${factor.factor.toStringAsFixed(2)})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedFactor = value),
                  validator: (value) {
                    if (value == null) return 'Admin cần cấu hình hệ số loài.';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _dbhController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Đường kính (cm)',
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  validator: _positiveNumberValidator,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Chiều cao (m)',
                    prefixIcon: Icon(Icons.height),
                  ),
                  validator: _positiveNumberValidator,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số lượng',
                    prefixIcon: Icon(Icons.format_list_numbered),
                  ),
                  validator: (value) {
                    final number = int.tryParse(value?.trim() ?? '');
                    if (number == null || number <= 0) {
                      return AppStrings.invalidNumber;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (_preview != null) _CarbonPreview(item: _preview!),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _calculatePreview,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Tính toán Carbon'),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppPrimaryButton(
                  label: 'Lưu kết quả',
                  onPressed: () => _saveCarbon(),
                  isLoading: _isSaving,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class WorkerGpsMapTab extends StatefulWidget {
  final bool isSharing;
  final Position? lastPosition;
  final ForestOwnerModel? owner;
  final ForestProjectModel selectedProject;
  final List<ForestProjectModel> allOwnerProjects;
  final VoidCallback onToggle;
  final VoidCallback onRefreshPosition;

  const WorkerGpsMapTab({
    super.key,
    required this.isSharing,
    required this.lastPosition,
    required this.owner,
    required this.selectedProject,
    required this.allOwnerProjects,
    required this.onToggle,
    required this.onRefreshPosition,
  });

  @override
  State<WorkerGpsMapTab> createState() => _WorkerGpsMapTabState();
}

class _WorkerGpsMapTabState extends State<WorkerGpsMapTab> {
  final MapController _mapController = MapController();
  bool _isSatellite = false;

  static const List<Color> _zoneColors = [
    Color(0xFF006241),
    Color(0xFF1565C0),
    Color(0xFFF57C00),
    Color(0xFF6A1B9A),
    Color(0xFFAD1457),
    Color(0xFF00695C),
    Color(0xFF4E342E),
  ];

  Color _colorForProject(String projectId) {
    final hash = projectId.hashCode.abs();
    return _zoneColors[hash % _zoneColors.length];
  }

  void _jumpToProject(List<LatLng> polygon) {
    if (polygon.isEmpty) return;
    _mapController.move(_polygonCenter(polygon), 15.0);
  }

  @override
  Widget build(BuildContext context) {
    final selectedProject = _projectWithBoundary(
      widget.selectedProject,
      widget.allOwnerProjects,
    );
    final ownerPolygon = (widget.owner?.polygon.length ?? 0) >= 3
        ? widget.owner!.polygon.map((p) => LatLng(p.lat, p.lng)).toList()
        : <LatLng>[];

    final projectPolygons = [
      ...widget.allOwnerProjects,
      if (!widget.allOwnerProjects.any((p) => p.id == selectedProject.id))
        selectedProject,
    ].where((project) => project.polygon.length >= 3).toList();

    final selectedProjectPolygon = selectedProject.polygon.length >= 3
        ? selectedProject.polygon.map((p) => LatLng(p.lat, p.lng)).toList()
        : <LatLng>[];

    final hasBoundaryData =
        ownerPolygon.isNotEmpty || projectPolygons.isNotEmpty;

    final mapCenter = widget.lastPosition != null
        ? LatLng(widget.lastPosition!.latitude, widget.lastPosition!.longitude)
        : selectedProjectPolygon.isNotEmpty
        ? _polygonCenter(selectedProjectPolygon)
        : ownerPolygon.isNotEmpty
        ? _polygonCenter(ownerPolygon)
        : const LatLng(12.6667, 108.0383);

    return SizedBox.expand(
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: widget.lastPosition != null ? 15.0 : 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.forest_manage',
              ),
              // Vùng rừng của Chủ rừng — nền màu xanh lá nhạt, viền đậm
              if (ownerPolygon.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: ownerPolygon,
                      color: const Color(0xFF006241).withValues(alpha: 0.12),
                      borderColor: const Color(0xFF006241),
                      borderStrokeWidth: 2.5,
                    ),
                  ],
                ),
              // Các vùng dự án — vẽ đè lên trên vùng rừng
              PolygonLayer(
                polygons: projectPolygons.map((project) {
                  final color = _colorForProject(project.id);
                  final isSelected = project.id == selectedProject.id;
                  return Polygon(
                    points: project.polygon
                        .map((pt) => LatLng(pt.lat, pt.lng))
                        .toList(),
                    color: color.withValues(alpha: isSelected ? 0.34 : 0.18),
                    borderColor: color,
                    borderStrokeWidth: isSelected ? 3 : 1.5,
                  );
                }).toList(),
              ),
              if (widget.lastPosition != null ||
                  selectedProjectPolygon.isNotEmpty)
                MarkerLayer(
                  markers: [
                    if (selectedProjectPolygon.isNotEmpty)
                      Marker(
                        point: _polygonCenter(selectedProjectPolygon),
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.info,
                          size: 36,
                        ),
                      ),
                    if (widget.lastPosition != null)
                      Marker(
                        point: LatLng(
                          widget.lastPosition!.latitude,
                          widget.lastPosition!.longitude,
                        ),
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_history,
                          color: AppColors.error,
                          size: 32,
                        ),
                      ),
                  ],
                ),
            ],
          ),
          if (!hasBoundaryData)
            Positioned(
              top: AppSpacing.md,
              left: 92,
              right: AppSpacing.md,
              child: _MapNotice(message: 'Dự án chưa có ranh giới bản đồ'),
            ),
          Positioned(
            left: AppSpacing.sm,
            top: AppSpacing.md,
            bottom: AppSpacing.md,
            child: _GpsMapSidebar(
              isSharing: widget.isSharing,
              isSatellite: _isSatellite,
              position: widget.lastPosition,
              onToggle: widget.onToggle,
              onRefresh: widget.onRefreshPosition,
              onToggleSatellite: () =>
                  setState(() => _isSatellite = !_isSatellite),
              onJumpToProject: selectedProjectPolygon.isNotEmpty
                  ? () => _jumpToProject(selectedProjectPolygon)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  LatLng _polygonCenter(List<LatLng> polygon) {
    final lat =
        polygon.fold(0.0, (sum, point) => sum + point.latitude) /
        polygon.length;
    final lng =
        polygon.fold(0.0, (sum, point) => sum + point.longitude) /
        polygon.length;
    return LatLng(lat, lng);
  }

  ForestProjectModel _projectWithBoundary(
    ForestProjectModel selected,
    List<ForestProjectModel> allProjects,
  ) {
    final sameId = allProjects.where((project) => project.id == selected.id);
    if (sameId.isNotEmpty) return sameId.first;

    if (selected.polygon.length >= 3) return selected;

    final sameName = allProjects.where(
      (project) =>
          project.projectName.trim().toLowerCase() ==
              selected.projectName.trim().toLowerCase() &&
          project.polygon.length >= 3,
    );
    if (sameName.isNotEmpty) return sameName.first;

    return selected;
  }
}

class _GpsMapSidebar extends StatelessWidget {
  final bool isSharing;
  final bool isSatellite;
  final Position? position;
  final VoidCallback onToggle;
  final VoidCallback onRefresh;
  final VoidCallback onToggleSatellite;
  final VoidCallback? onJumpToProject;

  const _GpsMapSidebar({
    required this.isSharing,
    required this.isSatellite,
    required this.position,
    required this.onToggle,
    required this.onRefresh,
    required this.onToggleSatellite,
    this.onJumpToProject,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: [
            Icon(
              isSharing ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: isSharing ? AppColors.tertiary : AppColors.secondary,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isSharing ? 'ON' : 'OFF',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isSharing ? AppColors.tertiary : AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _CompactCoordinate(position: position),
            const Spacer(),
            Tooltip(
              message: isSatellite ? 'Bản đồ thường' : 'Vệ tinh',
              child: IconButton.outlined(
                onPressed: onToggleSatellite,
                icon: Icon(isSatellite ? Icons.map : Icons.satellite_alt),
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (onJumpToProject != null) ...[
              Tooltip(
                message: 'Đến vị trí dự án',
                child: IconButton.outlined(
                  onPressed: onJumpToProject,
                  icon: const Icon(Icons.forest_outlined),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Tooltip(
              message: 'Cập nhật vị trí',
              child: IconButton.outlined(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                color: AppColors.tertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Tooltip(
              message: isSharing ? 'Tắt GPS' : 'Bật GPS',
              child: IconButton.filled(
                onPressed: onToggle,
                icon: Icon(isSharing ? Icons.stop : Icons.play_arrow),
                color: AppColors.onPrimary,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.tertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactCoordinate extends StatelessWidget {
  final Position? position;

  const _CompactCoordinate({required this.position});

  @override
  Widget build(BuildContext context) {
    if (position == null) {
      return Column(
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 18,
            color: AppColors.secondary,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '--',
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Column(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 18,
          color: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          position!.latitude.toStringAsFixed(3),
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
        Text(
          position!.longitude.toStringAsFixed(3),
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '±${position!.accuracy.toStringAsFixed(0)}m',
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MapNotice extends StatelessWidget {
  final String message;

  const _MapNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline,
              size: 18,
              color: AppColors.secondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPickerSummary extends StatelessWidget {
  final List<XFile> photos;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<int> onRemove;

  const _PhotoPickerSummary({
    required this.photos,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Ảnh hiện trường (${photos.length}/10)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton.outlined(
              tooltip: 'Chụp ảnh',
              onPressed: photos.length >= 10 ? null : onCamera,
              icon: const Icon(Icons.photo_camera_outlined),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.outlined(
              tooltip: 'Chọn ảnh từ máy',
              onPressed: photos.length >= 10 ? null : onGallery,
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
          ],
        ),
        if (photos.isNotEmpty)
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(photos[index].path),
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        onPressed: () => onRemove(index),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CarbonPreview extends StatelessWidget {
  final CarbonBreakdownItem item;
  const _CarbonPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.neutral,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _MetricRow(
            label: 'Biomass / cây',
            value:
                '${(item.biomassKg / (item.quantity > 0 ? item.quantity : 1)).toStringAsFixed(2)} kg',
          ),
          _MetricRow(
            label: 'Total Biomass',
            value: '${item.biomassKg.toStringAsFixed(2)} kg',
          ),
          _MetricRow(
            label: 'Carbon Stock (tấn Carbon)',
            value: '${item.carbonTon.toStringAsFixed(2)} tC',
          ),
          _MetricRow(
            label: 'CO₂ Equivalent (tấn CO₂e)',
            value: '${item.co2eTon.toStringAsFixed(2)} tCO₂e',
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EmptyWorkerState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyWorkerState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.assignment_late_outlined,
                size: 48,
                color: AppColors.secondary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Chưa có dự án được phân công',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Admin hoặc chủ rừng cần liên kết tài khoản worker với chủ rừng/dự án trước khi ghi nhận dữ liệu.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Tải lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _positiveNumberValidator(String? value) {
  final number = double.tryParse(value?.trim() ?? '');
  if (number == null || number <= 0) return AppStrings.invalidNumber;
  return null;
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _buildFieldLogFileName({
  required String projectName,
  required DateTime date,
  required String logId,
}) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final projectSlug = projectName
      .trim()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^\w\u00C0-\u1EF9]+'), '_');
  final shortId = logId.length > 6 ? logId.substring(0, 6) : logId;
  return 'Hien_Truong_${projectSlug}_${day}_${month}_${date.year}_$shortId.pdf';
}
