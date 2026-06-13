import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/shared/widgets/app_button.dart';

class FileUploadDialog extends StatefulWidget {
  const FileUploadDialog({super.key});

  @override
  State<FileUploadDialog> createState() => _FileUploadDialogState();
}

class _FileUploadDialogState extends State<FileUploadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fileNameController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;
  bool _hasSelectedFile = false; // Mock cho việc chọn file
  
  final List<String> _categories = [
    'Hồ sơ pháp lý',
    'Hồ sơ dự án',
    'Hình ảnh hiện trường',
    'Báo cáo khảo sát',
  ];

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _onPickFile() async {
    // TODO: Sử dụng file_picker do TV3 implement
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _hasSelectedFile = true;
      if (_fileNameController.text.isEmpty) {
        _fileNameController.text = 'tai_lieu_moi.pdf';
      }
    });
  }

  Future<void> _onUpload() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasSelectedFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn một file đính kèm!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // TODO: Sử dụng CloudinaryService.uploadFile()
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tải lên thành công!')),
    );
    context.pop(true); // Trả về true để màn hình chính reload
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tải lên tài liệu mới',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                
                // Chọn file
                InkWell(
                  onTap: _onPickFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _hasSelectedFile ? AppColors.tertiary : AppColors.secondary,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.neutral,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _hasSelectedFile ? Icons.file_present : Icons.upload_file,
                          size: 40,
                          color: _hasSelectedFile ? AppColors.tertiary : AppColors.secondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hasSelectedFile ? 'Đã chọn 1 file' : 'Nhấn để chọn file (PDF, DOCX, JPG, PNG)',
                          style: TextStyle(
                            color: _hasSelectedFile ? AppColors.tertiary : AppColors.secondary,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Tên file
                TextFormField(
                  controller: _fileNameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên hiển thị',
                    prefixIcon: Icon(Icons.edit_document),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // Chọn danh mục
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Nhóm tài liệu',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _categories.map((String category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  },
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng chọn nhóm tài liệu';
                    return null;
                  },
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Hủy', style: TextStyle(color: AppColors.secondary)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppPrimaryButton(
                      label: AppStrings.upload,
                      onPressed: _onUpload,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
