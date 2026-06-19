import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/core/services/auth_service.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';

class AssignWorkersScreen extends StatefulWidget {
  final ForestProjectModel project;

  const AssignWorkersScreen({super.key, required this.project});

  @override
  State<AssignWorkersScreen> createState() => _AssignWorkersScreenState();
}

class _AssignWorkersScreenState extends State<AssignWorkersScreen> {
  final _db = FirestoreService.instance;
  bool _saving = false;
  String _searchQuery = '';

  // Danh sách uid đang được chọn
  Set<String> _selectedUids = {};
  bool _initialized = false;

  void _initSelection(List<UserModel> workers) {
    if (_initialized) return;
    _initialized = true;
    _selectedUids = workers
        .where((w) => w.assignedProjectIds.contains(widget.project.id))
        .map((w) => w.uid)
        .toSet();
  }

  Future<void> _save(List<UserModel> allWorkers) async {
    setState(() => _saving = true);
    try {
      for (final w in allWorkers) {
        final hadProject = w.assignedProjectIds.contains(widget.project.id);
        final shouldHave = _selectedUids.contains(w.uid);
        if (hadProject == shouldHave) continue;

        final updated = List<String>.from(w.assignedProjectIds);
        if (shouldHave) {
          updated.add(widget.project.id);
        } else {
          updated.remove(widget.project.id);
        }
        await _db.saveUser(w.copyWith(assignedProjectIds: updated));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Đã phân công ${_selectedUids.length} worker cho dự án "${widget.project.projectName}"',
        ),
        backgroundColor: AppColors.tertiary,
      ));
      Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Lỗi phân công: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phân công Forest Worker',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            Text(widget.project.projectName,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70), overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ElevatedButton.icon(
              onPressed: _saving ? null : () async {
                final snap = await _db.streamWorkersByOwner(widget.project.ownerId).first;
                await _save(snap);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tertiary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              ),
              icon: _saving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text('Lưu phân công',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: _db.streamWorkersByOwner(widget.project.ownerId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Lỗi: ${snap.error}', style: const TextStyle(color: AppColors.error)));
          }

          final workers = snap.data ?? [];

          // Khởi tạo lần đầu
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_initialized && mounted) {
              setState(() => _initSelection(workers));
            }
          });

          if (workers.isEmpty) {
            return _buildEmpty();
          }

          // Lọc tìm kiếm
          final filtered = _searchQuery.isEmpty
              ? workers
              : workers.where((w) =>
                  w.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  w.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  w.workerCode.toLowerCase().contains(_searchQuery.toLowerCase())
                ).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProjectCard(),
              _buildStats(workers),
              _buildSearchBar(),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Không tìm thấy worker nào.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _buildWorkerCard(filtered[i], workers),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProjectCard() {
    final statusColors = {
      ProjectStatus.active:    (Colors.green.shade100, Colors.green.shade700, 'Đang hoạt động'),
      ProjectStatus.surveying: (Colors.orange.shade100, Colors.orange.shade700, 'Đang khảo sát'),
      ProjectStatus.suspended: (Colors.red.shade100, Colors.red.shade700, 'Tạm dừng'),
      ProjectStatus.draft:     (Colors.grey.shade100, Colors.grey.shade700, 'Bản nháp'),
    };
    final (bgColor, txtColor, label) = statusColors[widget.project.status]!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.eco_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.project.projectName,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
              const SizedBox(height: 4),
              Row(children: [
                _Tag(icon: Icons.forest_outlined, text: widget.project.forestType),
                const SizedBox(width: 8),
                _Tag(icon: Icons.grass_outlined, text: widget.project.treeSpecies),
                const SizedBox(width: 8),
                if (widget.project.totalAreaHa > 0)
                  _Tag(icon: Icons.square_foot, text: '${widget.project.totalAreaHa.toStringAsFixed(1)} ha'),
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: txtColor.withValues(alpha: 0.3)),
            ),
            child: Text(label, style: GoogleFonts.inter(color: txtColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(List<UserModel> workers) {
    final assigned = workers.where((w) => _selectedUids.contains(w.uid)).length;
    final total = workers.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.group_outlined,
            label: 'Tổng worker',
            value: '$total',
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          _StatChip(
            icon: Icons.assignment_ind_outlined,
            label: 'Đã phân công',
            value: '$assigned',
            color: AppColors.tertiary,
          ),
          const SizedBox(width: 10),
          _StatChip(
            icon: Icons.person_off_outlined,
            label: 'Chưa phân công',
            value: '${total - assigned}',
            color: Colors.grey,
          ),
          const Spacer(),
          // Nút chọn tất cả / bỏ tất cả
          TextButton.icon(
            onPressed: () {
              setState(() {
                if (_selectedUids.length == total) {
                  _selectedUids.clear();
                } else {
                  _selectedUids = workers.map((w) => w.uid).toSet();
                }
              });
            },
            icon: Icon(
              _selectedUids.length == total ? Icons.deselect : Icons.select_all,
              size: 16,
            ),
            label: Text(
              _selectedUids.length == total ? 'Bỏ tất cả' : 'Chọn tất cả',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SizedBox(
        height: 46,
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Tìm worker theo tên, mã, email...',
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: 20),
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
      ),
    );
  }

  Widget _buildWorkerCard(UserModel worker, List<UserModel> allWorkers) {
    final isSelected = _selectedUids.contains(worker.uid);
    final isActive = worker.status == UserStatus.active;
    final projectCount = worker.assignedProjectIds.length;

    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedUids.remove(worker.uid);
        } else {
          _selectedUids.add(worker.uid);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tertiary.withValues(alpha: 0.07) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.tertiary.withValues(alpha: 0.4) : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.tertiary.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isSelected
                      ? AppColors.tertiary.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.08),
                  child: Text(
                    worker.fullName.isNotEmpty ? worker.fullName[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.tertiary : AppColors.primary,
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 18, height: 18,
                      decoration: const BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(worker.fullName,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? 'Đang làm' : 'Tạm dừng',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                if (worker.email.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.email_outlined, size: 13, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text(worker.email,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.secondary)),
                  ]),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [
                  if (worker.workerCode.isNotEmpty)
                    _Tag(icon: Icons.badge_outlined, text: worker.workerCode),
                  if (worker.workerAssignment.isNotEmpty)
                    _Tag(icon: Icons.work_outline, text: worker.workerAssignment),
                  _Tag(
                    icon: Icons.folder_special_outlined,
                    text: '$projectCount dự án',
                    color: projectCount > 0 ? AppColors.tertiary : Colors.grey,
                  ),
                ]),
              ]),
            ),

            // Checkbox
            const SizedBox(width: 10),
            Transform.scale(
              scale: 1.15,
              child: Checkbox(
                value: isSelected,
                activeColor: AppColors.tertiary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedUids.add(worker.uid);
                  } else {
                    _selectedUids.remove(worker.uid);
                  }
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_off_outlined, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('Chưa có Forest Worker nào',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(height: 8),
          Text('Hãy thêm worker trước khi phân công dự án.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.secondary)),
        ],
      ),
    );
  }
}

// ── Helper Widgets ───────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _Tag({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.inter(fontSize: 11, color: c, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: color.withValues(alpha: 0.7))),
        ]),
      ]),
    );
  }
}
