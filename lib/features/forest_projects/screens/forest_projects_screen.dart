import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/core/services/auth_service.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/core/services/forest_project_service.dart';
import 'package:forest_carbon_platform/shared/widgets/empty_state.dart';

class ForestProjectsScreen extends StatefulWidget {
  const ForestProjectsScreen({super.key});

  @override
  State<ForestProjectsScreen> createState() => _ForestProjectsScreenState();
}

class _ForestProjectsScreenState extends State<ForestProjectsScreen> {
  String _searchQuery = '';
  Map<String, String> _ownerNames = {}; // ownerId → ownerName

  @override
  void initState() {
    super.initState();
    // Stream danh sách chủ rừng để map tên
    FirestoreService.instance.streamForestOwners().listen((owners) {
      if (mounted) {
        setState(() {
          _ownerNames = {for (final o in owners) o.id: o.ownerName};
        });
      }
    });
  }

  // ── Admin: xóa dự án ────────────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, ForestProjectModel project) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa dự án "${project.projectName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ForestProjectService.instance.deleteProject(project.id).then((_) {
                messenger.showSnackBar(const SnackBar(content: Text('Đã xóa dự án.')));
              }).catchError((e) {
                messenger.showSnackBar(SnackBar(
                  content: Text('Lỗi xóa: $e'),
                  backgroundColor: AppColors.error,
                ));
              });
            },
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral,
      body: FutureBuilder<UserModel?>(
        future: AuthService.instance.getCurrentUserModel(throwOnError: true),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = userSnap.data;
          if (user == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Dự án rừng'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              body: const Center(child: Text('Không lấy được thông tin tài khoản.', style: TextStyle(color: AppColors.error))),
            );
          }

          final isAdmin = user.role == UserRole.platformAdmin;
          final isOwner = user.role == UserRole.forestOwner;

          // Stream projects: Admin → tất cả; Owner → dự án của mình (dùng ownerId từ users doc)
          Stream<List<ForestProjectModel>> projectsStream;
          if (isAdmin) {
            projectsStream = ForestProjectService.instance.getProjectsStream();
          } else if (isOwner) {
            // user.ownerId = forestOwners doc UUID, trùng với forestProjects.ownerId
            final ownerDocId = user.ownerId.trim();
            if (ownerDocId.isEmpty) {
              return Scaffold(
                appBar: _buildAppBar(isAdmin: false, context: context, user: user),
                body: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Tài khoản chủ rừng chưa được liên kết với hồ sơ chủ rừng.\nVui lòng liên hệ Admin để thiết lập.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              );
            }
            projectsStream = ForestProjectService.instance.getProjectsByOwnerStream(ownerDocId);
          } else {
            projectsStream = const Stream.empty();
          }

          return Scaffold(
            appBar: _buildAppBar(isAdmin: isAdmin, context: context, user: user),
            backgroundColor: AppColors.neutral,
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: StreamBuilder<List<ForestProjectModel>>(
                    stream: projectsStream,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(
                          child: Text('Lỗi: ${snap.error}', style: const TextStyle(color: AppColors.error)),
                        );
                      }

                      var projects = snap.data ?? [];
                      if (_searchQuery.isNotEmpty) {
                        final q = _searchQuery.toLowerCase();
                        projects = projects.where((p) =>
                          p.projectName.toLowerCase().contains(q) ||
                          p.forestType.toLowerCase().contains(q) ||
                          p.treeSpecies.toLowerCase().contains(q)
                        ).toList();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isOwner) _buildOwnerInfoBanner(user, snap.data?.length ?? 0),
                          if (isOwner) const SizedBox(height: AppSpacing.lg),
                          _buildSearchBar(),
                          const SizedBox(height: AppSpacing.lg),
                          if (projects.isEmpty)
                            const AppEmptyState(title: 'Chưa có dự án nào.')
                          else
                            _buildTable(projects, isAdmin: isAdmin, isOwner: isOwner, ownerDocId: user.ownerId),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({required bool isAdmin, required BuildContext context, required UserModel user}) {
    return AppBar(
      title: Text(
        isAdmin ? 'Quản lý dự án rừng' : 'Dự án của tôi',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        // Chỉ Admin mới có nút "Thêm dự án"
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.forestProjectAdd),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tertiary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: Text('Thêm dự án', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
      ],
    );
  }

  Widget _buildOwnerInfoBanner(UserModel user, int projectCount) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: AppColors.tertiary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.forest_outlined, color: AppColors.tertiary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Khu vực rừng quản lý',
                style: GoogleFonts.inter(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(user.forestName.isNotEmpty ? user.forestName : user.ownerName,
                style: GoogleFonts.inter(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Nhấn nút "Phân công" để giao dự án cho Forest Worker',
                style: GoogleFonts.inter(color: AppColors.secondary, fontSize: 12)),
            ]),
          ),
          _Badge(label: 'Dự án', value: '$projectCount'),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      height: 48,
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm dự án...',
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade500),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
          filled: true, fillColor: AppColors.surface,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(List<ForestProjectModel> projects, {required bool isAdmin, required bool isOwner, required String ownerDocId}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: isAdmin ? 1150 : 900),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.grey.shade200),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.transparent),
              dataRowMaxHeight: 68,
              dataRowMinHeight: 68,
              columnSpacing: 20,
              headingTextStyle: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
              dataTextStyle: GoogleFonts.inter(color: AppColors.primary, fontSize: 13),
              columns: [
                const DataColumn(label: Padding(padding: EdgeInsets.only(left: 16), child: Text('Tên dự án'))),
                const DataColumn(label: Text('Loại rừng')),
                const DataColumn(label: Text('Loài cây')),
                const DataColumn(label: Text('Diện tích (ha)')),
                const DataColumn(label: Text('Trạng thái')),
                if (isAdmin) const DataColumn(label: Text('Chủ rừng')),
                DataColumn(label: Text(isOwner ? 'Phân công' : 'Thao tác')),
              ],
              rows: projects.map((project) {
                return DataRow(cells: [
                  DataCell(Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(project.projectName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  )),
                  DataCell(Text(project.forestType.isNotEmpty ? project.forestType : '-')),
                  DataCell(Text(project.treeSpecies.isNotEmpty ? project.treeSpecies : '-')),
                  DataCell(Text(project.totalAreaHa > 0 ? '${project.totalAreaHa.toStringAsFixed(1)} ha' : '-')),
                  DataCell(_StatusPill(project.status)),
                  if (isAdmin)
                    DataCell(
                      Text(
                        _ownerNames[project.ownerId] ?? '—',
                        style: const TextStyle(color: AppColors.secondary),
                      ),
                    ),
                  DataCell(
                    isOwner
                      ? ElevatedButton.icon(
                          onPressed: () => context.push(AppRoutes.assignWorkers, extra: project),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.tertiary.withValues(alpha: 0.1),
                            foregroundColor: AppColors.tertiary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.assignment_ind_outlined, size: 16),
                          label: Text('Phân công', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        )
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.map, size: 19, color: AppColors.secondary),
                            onPressed: () => context.push(AppRoutes.map),
                            tooltip: 'Xem bản đồ',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 19, color: Colors.blue),
                            onPressed: () => context.push(AppRoutes.forestProjectAdd, extra: project),
                            tooltip: 'Sửa',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 19, color: Colors.red),
                            onPressed: () => _confirmDelete(context, project),
                            tooltip: 'Xóa',
                          ),
                        ]),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}




// ─────────────────────── Helper Widgets ─────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final ProjectStatus status;
  const _StatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ProjectStatus.active    => (Colors.green, 'Hoạt động'),
      ProjectStatus.surveying => (Colors.orange, 'Đang khảo sát'),
      ProjectStatus.suspended => (Colors.red, 'Tạm dừng'),
      ProjectStatus.draft     => (Colors.grey, 'Bản nháp'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final String value;
  const _Badge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.neutral,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        Text(value, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(color: AppColors.secondary, fontSize: 11)),
      ]),
    );
  }
}
