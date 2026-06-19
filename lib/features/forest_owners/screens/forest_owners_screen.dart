import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/services/forest_owner_service.dart';
import 'package:forest_carbon_platform/core/services/forest_project_service.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/shared/widgets/empty_state.dart';

class ForestOwnersScreen extends StatefulWidget {
  const ForestOwnersScreen({super.key});

  @override
  State<ForestOwnersScreen> createState() => _ForestOwnersScreenState();
}

class _ForestOwnersScreenState extends State<ForestOwnersScreen> {
  final Stream<List<ForestOwnerModel>> _ownersStream = ForestOwnerService.instance.getOwnersStream();
  String _searchQuery = '';
  String? _selectedProvince;

  void _confirmDelete(BuildContext context, ForestOwnerModel owner) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa chủ rừng "${owner.ownerName}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy', style: TextStyle(color: AppColors.secondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ForestOwnerService.instance.deleteOwner(owner.id);
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
      appBar: AppBar(
        title: Text(
          'Quản lý chủ rừng',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: ElevatedButton(
              onPressed: () => context.push(AppRoutes.forestOwnerAdd),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tertiary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              child: Text(
                'Thêm chủ rừng',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: StreamBuilder<List<ForestOwnerModel>>(
              stream: _ownersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: AppColors.error)),
                  );
                }

                final allOwners = snapshot.data ?? [];
                final provinces = allOwners
                    .map((o) => o.managementProvince.trim())
                    .where((province) => province.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                var owners = List<ForestOwnerModel>.from(allOwners);

                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  owners = owners.where((o) =>
                    o.ownerName.toLowerCase().contains(query) ||
                    o.ownerCode.toLowerCase().contains(query) ||
                    o.forestName.toLowerCase().contains(query) ||
                    o.managementProvince.toLowerCase().contains(query)
                  ).toList();
                }

                final provinceFilter =
                    provinces.contains(_selectedProvince) ? _selectedProvince : null;
                if (provinceFilter != null) {
                  owners = owners
                      .where((o) => o.managementProvince.trim() == provinceFilter)
                      .toList();
                }

                return StreamBuilder<List<ForestProjectModel>>(
                  stream: ForestProjectService.instance.getProjectsStream(),
                  builder: (context, projectSnap) {
                    final allProjects = projectSnap.data ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSearchAndFilter(provinces),
                        const SizedBox(height: AppSpacing.lg),
                        if (owners.isEmpty)
                          const AppEmptyState(title: 'Chưa có chủ rừng nào hoặc không tìm thấy.')
                        else
                          _buildDataTable(owners, allProjects),
                      ],
                    );
                  },
                );
              }
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter(List<String> provinces) {
    final selectedProvince =
        provinces.contains(_selectedProvince) ? _selectedProvince : null;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm',
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 230,
          height: 48,
          child: DropdownButtonFormField<String>(
            initialValue: selectedProvince,
            decoration: InputDecoration(
              hintText: 'Tất cả tỉnh/thành',
              hintStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon: Icon(Icons.filter_list, color: Colors.grey.shade600),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Tất cả tỉnh/thành'),
              ),
              ...provinces.map(
                (province) => DropdownMenuItem<String>(
                  value: province,
                  child: Text(
                    province,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _selectedProvince = value),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable(List<ForestOwnerModel> owners, List<ForestProjectModel> allProjects) {
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
          constraints: const BoxConstraints(minWidth: 980),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.grey.shade200,
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.transparent),
              dataRowMaxHeight: 65,
              dataRowMinHeight: 65,
              headingTextStyle: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              dataTextStyle: GoogleFonts.inter(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              columns: const [
                DataColumn(label: Padding(padding: EdgeInsets.only(left: 16), child: Text('Mã chủ rừng'))),
                DataColumn(label: Text('Tên chủ rừng')),
                DataColumn(label: Text('Tên rừng')),
                DataColumn(label: Text('Tỉnh/Thành')),
                DataColumn(label: Text('Diện tích (ha)')),
                DataColumn(label: Text('Số dự án')),
                DataColumn(label: Text('SĐT')),
                DataColumn(label: Text('Thao tác')),
              ],
              rows: owners.map((owner) {
                final projectCount = allProjects.where((p) => p.ownerId == owner.id).length;
                return DataRow(
                  cells: [
                    DataCell(Padding(padding: const EdgeInsets.only(left: 16), child: Text(owner.ownerCode))),
                    DataCell(Text(owner.ownerName)),
                    DataCell(Text(owner.forestName.isEmpty ? '—' : owner.forestName)),
                    DataCell(Text(owner.managementProvince.isEmpty ? '—' : owner.managementProvince)),
                    // Diện tích
                    DataCell(
                      owner.totalAreaHa > 0
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.landscape, size: 14, color: AppColors.primary.withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Text(
                                '${owner.totalAreaHa.toStringAsFixed(1)} ha',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          )
                        : Text('—', style: GoogleFonts.inter(color: Colors.grey.shade400)),
                    ),
                    // Số dự án
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: projectCount > 0
                              ? AppColors.tertiary.withValues(alpha: 0.12)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: projectCount > 0
                                ? AppColors.tertiary.withValues(alpha: 0.4)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          '$projectCount dự án',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: projectCount > 0 ? AppColors.tertiary : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(owner.phone)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                            onPressed: () {
                              context.push(AppRoutes.forestOwnerAdd, extra: owner);
                            },
                            tooltip: 'Sửa',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () => _confirmDelete(context, owner),
                            tooltip: 'Xóa',
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
