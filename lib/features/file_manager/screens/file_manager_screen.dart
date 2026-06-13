import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/features/file_manager/widgets/file_upload_dialog.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  String _selectedCategory = 'Tất cả';

  final List<String> _categories = [
    'Tất cả',
    'Hồ sơ pháp lý',
    'Hồ sơ dự án',
    'Hình ảnh hiện trường',
    'Báo cáo khảo sát',
  ];

  // Mock data cho danh sách file
  final List<Map<String, dynamic>> _mockFiles = [
    {'name': 'Giay_Phep_Khai_Thac_2026.pdf', 'category': 'Hồ sơ pháp lý', 'type': 'pdf', 'date': '12/06/2026'},
    {'name': 'Ban_Do_Du_An_DakLak.geojson', 'category': 'Hồ sơ dự án', 'type': 'json', 'date': '10/06/2026'},
    {'name': 'Hien_Truong_Tuan_1.jpg', 'category': 'Hình ảnh hiện trường', 'type': 'img', 'date': '08/06/2026'},
    {'name': 'Bao_Cao_Sinh_Khoi_Q1.docx', 'category': 'Báo cáo khảo sát', 'type': 'doc', 'date': '01/06/2026'},
  ];

  void _showUploadDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const FileUploadDialog(),
    );

    if (result == true) {
      // TODO: Reload data from Firestore
    }
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc': return Icons.description;
      case 'img': return Icons.image;
      default: return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String type) {
    switch (type) {
      case 'pdf': return AppColors.error;
      case 'doc': return AppColors.info;
      case 'img': return AppColors.success;
      default: return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= AppBreakpoints.web;
    
    // Lọc file theo danh mục
    final filteredFiles = _selectedCategory == 'Tất cả' 
        ? _mockFiles 
        : _mockFiles.where((f) => f['category'] == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: const Text(AppStrings.fileManager),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadDialog,
        backgroundColor: AppColors.tertiary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.upload),
        label: const Text(AppStrings.upload),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar danh mục (chỉ hiện trên Web)
          if (isWeb)
            Container(
              width: 250,
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return ListTile(
                    title: Text(
                      category,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.tertiary : AppColors.primary,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: AppColors.tertiary.withValues(alpha: 0.1),
                    onTap: () => setState(() => _selectedCategory = category),
                  );
                }).toList(),
              ),
            ),

          // Nội dung chính
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(isWeb ? AppSpacing.lg : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dropdown chọn danh mục (hiện trên Mobile)
                  if (!isWeb) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: AppColors.surface,
                        prefixIcon: Icon(Icons.filter_list),
                      ),
                      items: _categories.map((String category) {
                        return DropdownMenuItem(value: category, child: Text(category));
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedCategory = newValue);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Header danh sách
                  Text(
                    '$_selectedCategory (${filteredFiles.length} tài liệu)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Danh sách File
                  Expanded(
                    child: filteredFiles.isEmpty
                        ? Center(
                            child: Text(
                              AppStrings.errorEmpty,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        : isWeb
                            ? GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 3,
                                  crossAxisSpacing: AppSpacing.md,
                                  mainAxisSpacing: AppSpacing.md,
                                ),
                                itemCount: filteredFiles.length,
                                itemBuilder: (context, index) => _buildFileCard(filteredFiles[index]),
                              )
                            : ListView.separated(
                                itemCount: filteredFiles.length,
                                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) => _buildFileCard(filteredFiles[index]),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getFileColor(file['type']).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getFileIcon(file['type']),
            color: _getFileColor(file['type']),
          ),
        ),
        title: Text(
          file['name'],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${file['category']} • ${file['date']}'),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            // TODO: Hiện menu Preview/Download/Delete
          },
        ),
        onTap: () {
          // TODO: Mở Preview
        },
      ),
    );
  }
}
