import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/core/services/auth_service.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/core/services/forest_project_service.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';

class ForestWorkersScreen extends StatefulWidget {
  const ForestWorkersScreen({super.key});

  @override
  State<ForestWorkersScreen> createState() => _ForestWorkersScreenState();
}

class _ForestWorkersScreenState extends State<ForestWorkersScreen> {
  final _db = FirestoreService.instance;
  String _searchQuery = '';

  String get _currentForestName {
    final u = AuthService.instance.currentUserModel;
    if (u != null && u.forestName.isNotEmpty) return u.forestName;
    return 'Khu vực rừng của bạn';
  }

  String get _currentOwnerName {
    return AuthService.instance.currentUserModel?.fullName ?? '';
  }

  String get _currentOwnerId {
    // Use ownerId (ForestOwnerModel.id) to match how admin stores workers
    return AuthService.instance.currentUserModel?.ownerId ?? 
           AuthService.instance.currentUser?.uid ?? '';
  }

  String _displayValue(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? '-' : normalized;
  }

  // ─────────────────────── Dialog thêm/sửa worker ────────────────────────────

  void _showWorkerDialog({UserModel? worker}) {
    final isEdit = worker != null;
    final codeController = TextEditingController(text: worker?.workerCode ?? '');
    final nameController = TextEditingController(text: worker?.fullName ?? '');
    final gmailController = TextEditingController(text: worker?.email ?? '');
    final phoneController = TextEditingController(text: worker?.phone ?? '');
    final forestAreaController = TextEditingController(
      text: worker?.forestName.isNotEmpty == true ? worker!.forestName : _currentForestName,
    );
    final assignmentController = TextEditingController(text: worker?.workerAssignment ?? '');
    String status = worker?.status == UserStatus.inactive ? 'Tạm dừng' : 'Đang làm việc';
    bool createAccount = false;
    bool isSubmitting = false;
    final formKey = GlobalKey<FormState>();

    // Danh sách project được chọn
    Set<String> selectedProjectIds = Set<String>.from(worker?.assignedProjectIds ?? []);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_outlined : Icons.person_add_alt_1,
                    color: AppColors.tertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isEdit ? 'Chỉnh sửa Forest Worker' : 'Thêm Forest Worker',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Mã + Họ tên ─────────────────────────────────────────
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: codeController,
                            decoration: const InputDecoration(labelText: 'Mã worker'),
                            validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(labelText: 'Họ tên'),
                            validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // ── Gmail ────────────────────────────────────────────────
                      TextFormField(
                        controller: gmailController,
                        decoration: const InputDecoration(
                          labelText: 'Gmail',
                          prefixIcon: Icon(Icons.email_outlined, size: 18),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (!isEdit && createAccount && v?.trim().isEmpty == true) {
                            return 'Bắt buộc nhập Gmail để tạo tài khoản';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // ── SĐT ─────────────────────────────────────────────────
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: 'Số điện thoại'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),

                      // ── Khu vực rừng (locked) ────────────────────────────────
                      TextFormField(
                        controller: forestAreaController,
                        enabled: false,
                        decoration: const InputDecoration(labelText: 'Khu vực rừng phụ trách'),
                      ),
                      const SizedBox(height: 12),

                      // ── Công việc ────────────────────────────────────────────
                      TextFormField(
                        controller: assignmentController,
                        decoration: const InputDecoration(labelText: 'Công việc phụ trách'),
                      ),
                      const SizedBox(height: 12),

                      // ── Trạng thái ───────────────────────────────────────────
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Trạng thái'),
                        items: const [
                          DropdownMenuItem(value: 'Đang làm việc', child: Text('Đang làm việc')),
                          DropdownMenuItem(value: 'Tạm dừng', child: Text('Tạm dừng')),
                        ],
                        onChanged: (v) { if (v != null) setDialogState(() => status = v); },
                      ),
                      const SizedBox(height: 16),

                      // ── Gán dự án ─────────────────────────────────────────
                      Text(
                        'Gán dự án',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<ForestProjectModel>>(
                        stream: ForestProjectService.instance.getProjectsByOwnerStream(_currentOwnerId),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          }
                          final projects = snap.data ?? [];
                          if (projects.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.neutral,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                'Chưa có dự án nào. Hãy tạo dự án trước.',
                                style: GoogleFonts.inter(color: AppColors.secondary, fontSize: 13),
                              ),
                            );
                          }
                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.neutral,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: projects.map((p) {
                                final isSelected = selectedProjectIds.contains(p.id);
                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (v) {
                                    setDialogState(() {
                                      if (v == true) {
                                        selectedProjectIds.add(p.id);
                                      } else {
                                        selectedProjectIds.remove(p.id);
                                      }
                                    });
                                  },
                                  title: Text(
                                    p.projectName,
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    '${p.commune}, ${p.district} • ${p.totalAreaHa.toStringAsFixed(1)} ha',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.secondary),
                                  ),
                                  activeColor: AppColors.tertiary,
                                  controlAffinity: ListTileControlAffinity.trailing,
                                  dense: true,
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),

                      // ── Tạo tài khoản (chỉ khi thêm mới) ───────────────────
                      if (!isEdit) ...[
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                          ),
                          child: CheckboxListTile(
                            value: createAccount,
                            onChanged: (v) => setDialogState(() => createAccount = v ?? false),
                            title: Text(
                              'Tạo tài khoản đăng nhập',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 14),
                            ),
                            subtitle: Text(
                              'Mật khẩu mặc định: 123456',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.secondary),
                            ),
                            activeColor: AppColors.tertiary,
                            checkColor: AppColors.onPrimary,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            controlAffinity: ListTileControlAffinity.trailing,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: Text('Hủy', style: TextStyle(color: isSubmitting ? Colors.grey : AppColors.secondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tertiary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                onPressed: isSubmitting ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  setDialogState(() => isSubmitting = true);

                  final userModel = UserModel(
                    uid: worker?.uid ?? '',
                    fullName: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    email: gmailController.text.trim(),
                    role: UserRole.forestWorker,
                    status: status == 'Đang làm việc' ? UserStatus.active : UserStatus.inactive,
                    ownerId: _currentOwnerId,
                    ownerName: _currentOwnerName,
                    forestName: _currentForestName,
                    workerCode: codeController.text.trim(),
                    workerAssignment: assignmentController.text.trim(),
                    assignedProjectIds: selectedProjectIds.toList(),
                    createdAt: worker?.createdAt ?? DateTime.now(),
                  );

                  // Khi sửa: luôn lưu trực tiếp
                  if (isEdit) {
                    try {
                      await _db.saveUserProfile(userModel);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      _showSuccessSnack('Đã cập nhật thông tin "${userModel.fullName}"');
                    } catch (e) {
                      setDialogState(() => isSubmitting = false);
                      _showErrorSnack('Lỗi cập nhật: $e');
                    }
                    return;
                  }

                  // Khi thêm mới với tạo tài khoản
                  if (createAccount && gmailController.text.trim().isNotEmpty) {
                    try {
                      await AuthService.instance.createUser(
                        email: gmailController.text.trim(),
                        password: '123456',
                        fullName: userModel.fullName,
                        phone: userModel.phone,
                        role: UserRole.forestWorker,
                        ownerName: _currentOwnerName,
                        ownerId: _currentOwnerId,
                        forestName: _currentForestName,
                        workerCode: userModel.workerCode,
                        workerAssignment: userModel.workerAssignment,
                      );
                      // Sau khi tạo Auth, cập nhật thêm assignedProjectIds
                      // Tìm uid mới vừa tạo qua Firestore
                      if (selectedProjectIds.isNotEmpty) {
                        // Lưu assignment riêng qua một query
                        try {
                          final snap = await FirestoreService.instance.findWorkerByEmail(
                            gmailController.text.trim().toLowerCase(),
                          );
                          if (snap != null) {
                            await _db.saveUserProfile(snap.copyWith(
                              assignedProjectIds: selectedProjectIds.toList(),
                            ));
                          }
                        } catch (_) {}
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      _showSuccessSnack('Đã tạo worker & tài khoản cho "${userModel.fullName}"');
                    } catch (e) {
                      setDialogState(() => isSubmitting = false);
                      if (e.toString().contains('email-already-in-use')) {
                        _showErrorSnack('Email đã được sử dụng. Bỏ tích "Tạo tài khoản đăng nhập" nếu muốn chỉ lưu hồ sơ.');
                      } else {
                        _showErrorSnack('Lỗi tạo tài khoản: $e');
                      }
                    }
                    return;
                  }

                  // Thêm mới không tạo tài khoản
                  try {
                    await _db.saveUserProfile(userModel);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _showSuccessSnack('Đã lưu hồ sơ "${userModel.fullName}"');
                  } catch (e) {
                    setDialogState(() => isSubmitting = false);
                    _showErrorSnack('Lỗi lưu worker: $e');
                  }
                },
                child: isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2))
                    : Text(isEdit ? 'Cập nhật' : 'Lưu', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        });
      },
    );
  }

  // ─────────────────────── Confirm Delete ────────────────────────────────────

  void _confirmDelete(UserModel worker) {
    final hasEmail = worker.email.isNotEmpty;
    showDialog(
      context: context,
      builder: (context) {
        bool isDeleting = false;
        return StatefulBuilder(builder: (ctx, setSt) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
                SizedBox(width: 8),
                Text('Xóa Forest Worker', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bạn sắp xóa hoàn toàn:'),
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.person, label: worker.fullName),
                if (hasEmail) _InfoRow(icon: Icons.email_outlined, label: worker.email),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasEmail
                            ? 'Sẽ xóa cả hồ sơ Firestore & tài khoản Firebase Auth của worker này.'
                            : 'Sẽ xóa hồ sơ Firestore (worker chưa có tài khoản đăng nhập).',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(context),
                child: const Text('Hủy', style: TextStyle(color: AppColors.secondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                onPressed: isDeleting ? null : () async {
                  setSt(() => isDeleting = true);
                  Navigator.of(ctx).pop();
                  try {
                    // Xóa Firestore profile + Auth account
                    await AuthService.instance.deleteUserWithCleanup(
                      worker.uid,
                      email: hasEmail ? worker.email : null,
                      password: hasEmail ? '123456' : null,
                    );
                    if (mounted) {
                      _showSuccessSnack('Đã xóa hoàn toàn worker "${worker.fullName}"');
                    }
                  } catch (e) {
                    if (mounted) _showErrorSnack('Lỗi xóa worker: $e');
                  }
                },
                child: isDeleting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Xóa hoàn toàn', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        });
      },
    );
  }

  // ─────────────────────── Snackbars ─────────────────────────────────────────

  void _showSuccessSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.tertiary,
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
      ]),
      duration: const Duration(seconds: 4),
    ));
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.error,
      content: Text(message, style: const TextStyle(color: Colors.white)),
      duration: const Duration(seconds: 5),
    ));
  }

  // ─────────────────────── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.toLowerCase();
    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: const Text('Quản lý Forest Worker'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: StreamBuilder<List<UserModel>>(
              stream: _db.streamWorkersByOwner(_currentOwnerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lỗi tải dữ liệu: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.error)),
                  );
                }

                var workers = snapshot.data ?? [];
                if (query.isNotEmpty) {
                  workers = workers.where((w) =>
                    w.workerCode.toLowerCase().contains(query) ||
                    w.fullName.toLowerCase().contains(query) ||
                    w.email.toLowerCase().contains(query) ||
                    w.forestName.toLowerCase().contains(query)
                  ).toList();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(workers.length),
                    const SizedBox(height: AppSpacing.lg),
                    _buildSearchBar(),
                    const SizedBox(height: AppSpacing.lg),
                    if (workers.isEmpty)
                      const AppCard(child: Center(child: Text('Chưa có Forest Worker nào.')))
                    else
                      StreamBuilder<List<ForestProjectModel>>(
                        stream: ForestProjectService.instance
                            .getProjectsByOwnerStream(
                              AuthService.instance.currentUserModel?.ownerId ?? '',
                            ),
                        builder: (context, projSnap) {
                          // Tạo map id → tên dự án
                          final projectMap = <String, String>{};
                          for (final p in projSnap.data ?? []) {
                            projectMap[p.id] = p.projectName;
                          }
                          return _buildDataTable(workers, projectMap);
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWorkerDialog(),
        backgroundColor: AppColors.tertiary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Thêm worker', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.tertiary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forest_outlined, color: AppColors.tertiary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Khu vực rừng đang quản lý',
                    style: GoogleFonts.inter(color: AppColors.secondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_currentForestName,
                    style: GoogleFonts.inter(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          _SummaryBadge(label: 'Forest Worker', value: '$count'),
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
          hintText: 'Tìm kiếm worker...',
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

  Widget _buildDataTable(List<UserModel> workers, Map<String, String> projectMap) {
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
          constraints: const BoxConstraints(minWidth: 850),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.grey.shade200),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.transparent),
              dataRowMaxHeight: 60,
              dataRowMinHeight: 60,
              columnSpacing: 20,
              headingTextStyle: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
              dataTextStyle: GoogleFonts.inter(color: AppColors.primary, fontSize: 13),
              columns: const [
                DataColumn(label: Padding(padding: EdgeInsets.only(left: 16), child: Text('Mã'))),
                DataColumn(label: Text('Họ tên')),
                DataColumn(label: Text('Gmail')),
                DataColumn(label: Text('SĐT')),
                DataColumn(label: Text('Dự án')),
                DataColumn(label: Text('Công việc')),
                DataColumn(label: Text('Trạng thái')),
                DataColumn(label: Text('Thao tác')),
              ],
              rows: workers.map((w) {
                final isActive = w.status == UserStatus.active;
                final hasEmail = w.email.isNotEmpty;
                return DataRow(cells: [
                  DataCell(Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(w.workerCode.isEmpty ? '-' : w.workerCode, style: const TextStyle(fontWeight: FontWeight.w600)),
                  )),
                  DataCell(Text(w.fullName)),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    if (hasEmail) ...[
                      const Icon(Icons.verified, size: 13, color: AppColors.tertiary),
                      const SizedBox(width: 4),
                    ],
                    Flexible(child: Text(
                      _displayValue(w.email),
                      style: GoogleFonts.inter(fontSize: 12, color: hasEmail ? AppColors.secondary : Colors.grey.shade400),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ])),
                  DataCell(Text(_displayValue(w.phone))),
                  DataCell(
                    () {
                      // Lấy tên dự án đầu tiên được gán
                      if (w.assignedProjectIds.isEmpty) {
                        return Text('-', style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13));
                      }
                      final projectName = projectMap[w.assignedProjectIds.first] ?? 'Dự án #1';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.tertiary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          projectName,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.tertiary, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }(),
                  ),
                  DataCell(Text(_displayValue(w.workerAssignment))),
                  DataCell(_StatusChip(label: isActive ? 'Đang làm' : 'Tạm dừng', isActive: isActive)),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 19, color: Colors.blue),
                      tooltip: 'Chỉnh sửa',
                      onPressed: () => _showWorkerDialog(worker: w),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.error),
                      tooltip: 'Xóa',
                      onPressed: () => _confirmDelete(w),
                    ),
                  ])),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── Helper Widgets ────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 15, color: AppColors.secondary),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isActive;
  const _StatusChip({required this.label, required this.isActive});
  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.tertiary : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryBadge({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.neutral,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(color: AppColors.secondary, fontSize: 11)),
        ],
      ),
    );
  }
}
