import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/core/services/forest_project_service.dart';
import 'package:forest_carbon_platform/core/services/auth_service.dart';
import 'package:forest_carbon_platform/shared/widgets/empty_state.dart';

class AdminForestWorkersScreen extends StatefulWidget {
  const AdminForestWorkersScreen({super.key});

  @override
  State<AdminForestWorkersScreen> createState() =>
      _AdminForestWorkersScreenState();
}

class _AdminForestWorkersScreenState extends State<AdminForestWorkersScreen> {
  final _db = FirestoreService.instance;
  String _searchQuery = '';
  UserStatus? _filterStatus;
  String? _filterOwnerId;

  void _confirmDelete(UserModel worker) {
    // Save messenger before async gap
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa Forest Worker'),
        content: Text(
          'Bạn có chắc chắn muốn xóa hồ sơ "${worker.fullName}" không?\n\n'
          'Hành động này sẽ xóa hoàn toàn hồ sơ Firestore và tài khoản đăng nhập của người này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.secondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                // Delete from Firestore and Auth
                await AuthService.instance.deleteUserWithCleanup(
                  worker.uid,
                  email: worker.email.isNotEmpty ? worker.email : null,
                  password: '123456', // default pass to re-auth
                );

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Đã xóa hoàn toàn hồ sơ và tài khoản "${worker.fullName}"',
                    ),
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Lỗi khi xóa: $e')),
                );
              }
            },
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus(UserModel worker) async {
    final next = worker.status == UserStatus.active
        ? UserStatus.locked
        : UserStatus.active;
    try {
      await _db.updateUserStatus(worker.uid, next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${next == UserStatus.active ? 'Mở khóa' : 'Khóa'} tài khoản "${worker.fullName}"',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _showWorkerDialog({
    UserModel? worker,
    UserModel? initialOwner,
    required List<UserModel> allOwners,
  }) {
    if (allOwners.isEmpty) {
      _showErrorSnack('Cần có chủ rừng trước khi thêm hoặc chỉnh sửa worker');
      return;
    }

    final isEdit = worker != null;
    String ownerKey(UserModel owner) =>
        owner.ownerId.isNotEmpty ? owner.ownerId : owner.uid;

    String selectedOwnerId = worker?.ownerId.isNotEmpty == true
        ? worker!.ownerId
        : (initialOwner?.ownerId.isNotEmpty == true
              ? ownerKey(initialOwner!)
              : ownerKey(allOwners.first));
    final codeController = TextEditingController(
      text: worker?.workerCode ?? '',
    );
    final nameController = TextEditingController(text: worker?.fullName ?? '');
    final gmailController = TextEditingController(text: worker?.email ?? '');
    final phoneController = TextEditingController(text: worker?.phone ?? '');
    final assignmentController = TextEditingController(
      text: worker?.workerAssignment ?? '',
    );
    String status = worker?.status == UserStatus.inactive
        ? 'Tạm dừng'
        : 'Đang làm việc';
    bool createAccount = false;
    bool isSubmitting = false;
    final formKey = GlobalKey<FormState>();

    Set<String> selectedProjectIds = Set<String>.from(
      worker?.assignedProjectIds ?? [],
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final selectedOwner = allOwners.firstWhere(
              (owner) =>
                  owner.ownerId == selectedOwnerId ||
                  owner.uid == selectedOwnerId,
              orElse: () => initialOwner ?? allOwners.first,
            );

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 560,
                  maxHeight: 600,
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: codeController,
                                decoration: const InputDecoration(
                                  labelText: 'Mã worker',
                                ),
                                validator: (v) => v?.trim().isEmpty == true
                                    ? 'Bắt buộc'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Họ tên',
                                ),
                                validator: (v) => v?.trim().isEmpty == true
                                    ? 'Bắt buộc'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: gmailController,
                          decoration: const InputDecoration(
                            labelText: 'Gmail',
                            prefixIcon: Icon(Icons.email_outlined, size: 18),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (!isEdit &&
                                createAccount &&
                                v?.trim().isEmpty == true) {
                              return 'Bắt buộc nhập Gmail để tạo tài khoản';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại',
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          initialValue:
                              allOwners.any(
                                (owner) => ownerKey(owner) == selectedOwnerId,
                              )
                              ? selectedOwnerId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Chủ rừng liên kết / Khu vực rừng',
                            prefixIcon: Icon(Icons.forest_outlined, size: 18),
                          ),
                          isExpanded: true,
                          items: allOwners.map((o) {
                            return DropdownMenuItem<String>(
                              value: ownerKey(o),
                              child: Text('${o.fullName} - ${o.forestName}'),
                            );
                          }).toList(),
                          onChanged: isEdit
                              ? null
                              : (v) {
                                  if (v != null) {
                                    setDialogState(() {
                                      selectedOwnerId = v;
                                      selectedProjectIds
                                          .clear(); // Reset projects when owner changes
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: assignmentController,
                          decoration: const InputDecoration(
                            labelText: 'Công việc phụ trách',
                          ),
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(
                            labelText: 'Trạng thái',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Đang làm việc',
                              child: Text('Đang làm việc'),
                            ),
                            DropdownMenuItem(
                              value: 'Tạm dừng',
                              child: Text('Tạm dừng'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setDialogState(() => status = v);
                          },
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'Gán dự án',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<List<ForestProjectModel>>(
                          stream: ForestProjectService.instance
                              .getProjectsByOwnerStream(selectedOwner.ownerId),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }
                            final projects = snap.data ?? [];
                            if (projects.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.neutral,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Text(
                                  'Chưa có dự án nào. Hãy tạo dự án trước.',
                                  style: GoogleFonts.inter(
                                    color: AppColors.secondary,
                                    fontSize: 13,
                                  ),
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
                                  final isSelected = selectedProjectIds
                                      .contains(p.id);
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
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${p.commune}, ${p.district} • ${p.totalAreaHa.toStringAsFixed(1)} ha',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    activeColor: AppColors.tertiary,
                                    controlAffinity:
                                        ListTileControlAffinity.trailing,
                                    dense: true,
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),

                        if (!isEdit) ...[
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: CheckboxListTile(
                              value: createAccount,
                              onChanged: (v) => setDialogState(
                                () => createAccount = v ?? false,
                              ),
                              title: Text(
                                'Tạo tài khoản đăng nhập',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Mật khẩu mặc định: 123456',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.secondary,
                                ),
                              ),
                              activeColor: AppColors.tertiary,
                              checkColor: AppColors.onPrimary,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              controlAffinity: ListTileControlAffinity.trailing,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                  child: Text(
                    'Hủy',
                    style: TextStyle(
                      color: isSubmitting ? Colors.grey : AppColors.secondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tertiary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final userModel = UserModel(
                            uid: worker?.uid ?? '',
                            fullName: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                            email: gmailController.text.trim(),
                            role: UserRole.forestWorker,
                            status: status == 'Đang làm việc'
                                ? UserStatus.active
                                : UserStatus.inactive,
                            ownerId: selectedOwner.ownerId,
                            ownerName: selectedOwner.fullName,
                            forestName: selectedOwner.forestName,
                            workerCode: codeController.text.trim(),
                            workerAssignment: assignmentController.text.trim(),
                            assignedProjectIds: selectedProjectIds.toList(),
                            createdAt: worker?.createdAt ?? DateTime.now(),
                          );

                          if (isEdit) {
                            try {
                              await _db.saveUserProfile(userModel);
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              _showSuccessSnack(
                                'Đã cập nhật thông tin "${userModel.fullName}"',
                              );
                            } catch (e) {
                              setDialogState(() => isSubmitting = false);
                              _showErrorSnack('Lỗi cập nhật: $e');
                            }
                            return;
                          }

                          if (createAccount &&
                              gmailController.text.trim().isNotEmpty) {
                            try {
                              await AuthService.instance.createUser(
                                email: gmailController.text.trim(),
                                password: '123456',
                                fullName: userModel.fullName,
                                phone: userModel.phone,
                                role: UserRole.forestWorker,
                                ownerName: selectedOwner.fullName,
                                ownerId: selectedOwner.ownerId,
                                forestName: selectedOwner.forestName,
                                workerCode: userModel.workerCode,
                                workerAssignment: userModel.workerAssignment,
                              );
                              if (selectedProjectIds.isNotEmpty) {
                                try {
                                  final snap = await _db.findWorkerByEmail(
                                    gmailController.text.trim().toLowerCase(),
                                  );
                                  if (snap != null) {
                                    await _db.saveUserProfile(
                                      snap.copyWith(
                                        assignedProjectIds: selectedProjectIds
                                            .toList(),
                                      ),
                                    );
                                  }
                                } catch (_) {}
                              }
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              _showSuccessSnack(
                                'Đã tạo worker & tài khoản cho "${userModel.fullName}"',
                              );
                            } catch (e) {
                              setDialogState(() => isSubmitting = false);
                              if (e.toString().contains(
                                'email-already-in-use',
                              )) {
                                _showErrorSnack('Email này đã tồn tại');
                              } else {
                                _showErrorSnack('Lỗi tạo worker: $e');
                              }
                            }
                          } else if (!createAccount) {
                            try {
                              await _db.saveUserProfile(userModel);
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              _showSuccessSnack(
                                'Đã tạo worker cho "${userModel.fullName}"',
                              );
                            } catch (e) {
                              setDialogState(() => isSubmitting = false);
                              _showErrorSnack('Lỗi tạo worker: $e');
                            }
                          }
                        },
                  child: Text(isSubmitting ? 'Đang lưu...' : 'Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSuccessSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.success),
    );
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: Text(
          'Quản lý Forest Worker',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: StreamBuilder<List<UserModel>>(
              stream: _db.streamUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Lỗi: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  );
                }

                var workers = (snapshot.data ?? [])
                    .where((u) => u.role == UserRole.forestWorker)
                    .toList();

                if (_filterStatus != null) {
                  workers = workers
                      .where((w) => w.status == _filterStatus)
                      .toList();
                }

                if (_filterOwnerId != null && _filterOwnerId!.isNotEmpty) {
                  workers = workers
                      .where((w) => w.ownerId == _filterOwnerId)
                      .toList();
                }

                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  workers = workers
                      .where(
                        (w) =>
                            w.fullName.toLowerCase().contains(q) ||
                            w.email.toLowerCase().contains(q) ||
                            w.ownerName.toLowerCase().contains(q) ||
                            w.forestName.toLowerCase().contains(q),
                      )
                      .toList();
                }

                final allWorkers = (snapshot.data ?? [])
                    .where((u) => u.role == UserRole.forestWorker)
                    .toList();
                final activeCount = allWorkers
                    .where((w) => w.status == UserStatus.active)
                    .length;
                final lockedCount = allWorkers
                    .where((w) => w.status == UserStatus.locked)
                    .length;

                // Get unique owners by ownerId because workers store ownerId, not owner uid.
                final ownersByOwnerId = <String, UserModel>{};
                for (final owner in (snapshot.data ?? []).where(
                  (u) => u.role == UserRole.forestOwner,
                )) {
                  final key = owner.ownerId.isNotEmpty
                      ? owner.ownerId
                      : owner.uid;
                  ownersByOwnerId[key] = owner;
                }
                final owners = ownersByOwnerId.values.toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatsBar(allWorkers.length, activeCount, lockedCount),
                    const SizedBox(height: AppSpacing.md),

                    _buildSearchAndFilter(owners),
                    const SizedBox(height: AppSpacing.lg),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Danh sách Forest Worker',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: owners.isEmpty
                              ? null
                              : () => _showWorkerDialog(
                                  worker: null,
                                  initialOwner: owners.first,
                                  allOwners: owners,
                                ),
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm Worker'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.tertiary,
                            foregroundColor: AppColors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    if (workers.isEmpty)
                      const AppEmptyState(
                        title: 'Chưa có Forest Worker nào hoặc không tìm thấy.',
                      )
                    else
                      _buildDataTable(workers, owners),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar(int total, int active, int locked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.groups_outlined,
              label: 'Tổng Worker',
              value: '$total',
              color: AppColors.primary,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          Expanded(
            child: _StatItem(
              icon: Icons.check_circle_outline,
              label: 'Đang hoạt động',
              value: '$active',
              color: AppColors.tertiary,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          Expanded(
            child: _StatItem(
              icon: Icons.lock_outline,
              label: 'Đã khóa',
              value: '$locked',
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(List<UserModel> owners) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, email, chủ rừng...',
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Filter by owner
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _filterOwnerId,
              hint: Text('Chủ rừng', style: GoogleFonts.inter(fontSize: 13)),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'Tất cả chủ rừng',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
                ...owners.map(
                  (owner) => DropdownMenuItem<String?>(
                    value: owner.ownerId.isNotEmpty ? owner.ownerId : owner.uid,
                    child: Text(
                      owner.fullName,
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _filterOwnerId = val),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Filter by status
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<UserStatus?>(
              value: _filterStatus,
              hint: Text('Trạng thái', style: GoogleFonts.inter(fontSize: 13)),
              items: [
                DropdownMenuItem<UserStatus?>(
                  value: null,
                  child: Text('Tất cả', style: GoogleFonts.inter(fontSize: 13)),
                ),
                DropdownMenuItem<UserStatus?>(
                  value: UserStatus.active,
                  child: Text(
                    'Hoạt động',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
                DropdownMenuItem<UserStatus?>(
                  value: UserStatus.locked,
                  child: Text(
                    'Đã khóa',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _filterStatus = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable(List<UserModel> workers, List<UserModel> owners) {
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
          constraints: const BoxConstraints(minWidth: 1100),
          child: Theme(
            data: Theme.of(
              context,
            ).copyWith(dividerColor: Colors.grey.shade200),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.transparent),
              dataRowMaxHeight: 68,
              dataRowMinHeight: 68,
              headingTextStyle: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              dataTextStyle: GoogleFonts.inter(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              columns: const [
                DataColumn(
                  label: Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text('Họ tên'),
                  ),
                ),
                DataColumn(label: Text('Gmail')),
                DataColumn(label: Text('Chủ rừng quản lý')),
                DataColumn(label: Text('Khu vực rừng')),
                DataColumn(label: Text('SĐT')),
                DataColumn(label: Text('Trạng thái')),
                DataColumn(label: Text('Thao tác')),
              ],
              rows: workers.map((worker) {
                final isActive = worker.status == UserStatus.active;
                final owner = owners.firstWhere(
                  (o) => o.ownerId == worker.ownerId || o.uid == worker.ownerId,
                  orElse: () => UserModel(
                    uid: '',
                    fullName: worker.ownerName,
                    phone: '',
                    email: '',
                    role: UserRole.forestOwner,
                    status: UserStatus.active,
                    ownerId: worker.ownerId,
                    ownerName: '',
                    forestName: '',
                    createdAt: DateTime.now(),
                  ),
                );
                return DataRow(
                  cells: [
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              child: Text(
                                worker.fullName.isNotEmpty
                                    ? worker.fullName[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(worker.fullName),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        worker.email.isEmpty ? '—' : worker.email,
                        style: GoogleFonts.inter(
                          color: AppColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(worker.ownerName.isEmpty ? '—' : worker.ownerName),
                    ),
                    DataCell(
                      Text(worker.forestName.isEmpty ? '—' : worker.forestName),
                    ),
                    DataCell(Text(worker.phone.isEmpty ? '—' : worker.phone)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.tertiary.withValues(alpha: 0.12)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? AppColors.tertiary.withValues(alpha: 0.4)
                                : Colors.orange.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          isActive ? 'Hoạt động' : 'Đã khóa',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? AppColors.tertiary
                                : Colors.orange,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            tooltip: 'Chỉnh sửa',
                            onPressed: () => _showWorkerDialog(
                              worker: worker,
                              initialOwner: owner,
                              allOwners: owners,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isActive ? Icons.lock_outline : Icons.lock_open,
                              size: 20,
                              color: isActive
                                  ? Colors.orange
                                  : AppColors.tertiary,
                            ),
                            tooltip: isActive ? 'Khóa tài khoản' : 'Mở khóa',
                            onPressed: () => _toggleStatus(worker),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 20,
                              color: Colors.red,
                            ),
                            tooltip: 'Xóa hồ sơ',
                            onPressed: () => _confirmDelete(worker),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.secondary),
        ),
      ],
    );
  }
}
