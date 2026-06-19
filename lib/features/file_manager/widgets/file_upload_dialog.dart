import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/core/models/file_document_model.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/core/services/auth_service.dart';
import 'package:forest_carbon_platform/core/services/cloudinary_service.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/shared/widgets/app_button.dart';

class FileUploadDialog extends StatefulWidget {
  const FileUploadDialog({super.key});

  @override
  State<FileUploadDialog> createState() => _FileUploadDialogState();
}

class _FileUploadDialogState extends State<FileUploadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fileNameController = TextEditingController();
  final _auth = AuthService.instance;
  final _cloudinary = CloudinaryService.instance;
  final _db = FirestoreService.instance;

  String? _selectedCategory;
  PlatformFile? _selectedFile;
  bool _isLoading = false;

  List<String> _categories = [];
  UserRole _userRole = UserRole.platformAdmin;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await _auth.getUserRole();
    setState(() {
      _userRole = role;
      if (role == UserRole.platformAdmin) {
        _categories = ['Hồ sơ pháp lý', 'Hồ sơ dự án'];
      } else if (role == UserRole.forestOwner) {
        _categories = ['Hình ảnh hiện trường', 'Báo cáo khảo sát'];
      }
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
    });
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _onPickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'jpg',
        'jpeg',
        'png',
        'geojson',
        'json',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    setState(() {
      _selectedFile = file;
      if (_fileNameController.text.isEmpty) {
        _fileNameController.text = file.name;
      }
    });
  }

  Future<void> _onUpload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn một file đính kèm!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final selected = _selectedFile!;
      final extension = '.${selected.extension ?? ''}';
      final selectedBytes = selected.bytes;
      
      String? filePath;
      if (!kIsWeb) {
        try {
          filePath = selected.path;
        } catch (_) {}
      }

      if (filePath == null && selectedBytes == null) {
        throw StateError('Không đọc được dữ liệu file đã chọn.');
      }
      
      final url = filePath != null
          ? await _cloudinary.uploadFile(
              File(filePath),
              folder: 'documents/${_selectedCategory!.replaceAll(' ', '_')}',
            )
          : await _cloudinary.uploadBytes(
              selectedBytes!,
              identifier: selected.name,
              folder: 'documents/${_selectedCategory!.replaceAll(' ', '_')}',
              extension: extension,
            );
      final currentUser = await _auth.getCurrentUserModel();
      final now = DateTime.now();
      await _db.saveFileDocument(
        FileDocumentModel(
          id: '',
          name: _fileNameController.text.trim(),
          category: _selectedCategory!,
          type: _inferFileType(selected.extension),
          url: url,
          ownerId: _userRole == UserRole.forestOwner ? currentUser?.ownerId ?? '' : '',
          uploadedBy: currentUser?.uid ?? '',
          uploadedByName: currentUser?.fullName.isNotEmpty == true
              ? currentUser!.fullName
              : currentUser?.email ?? '',
          source: 'manual',
          status: _userRole == UserRole.platformAdmin ? 'approved' : 'pending',
          createdAt: now,
          updatedAt: now,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tải lên thành công!')));
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không tải lên được tài liệu: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _inferFileType(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
        return 'doc';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return 'img';
      default:
        return 'json';
    }
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
                        color: _selectedFile != null
                            ? AppColors.tertiary
                            : AppColors.secondary,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.neutral,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _selectedFile != null
                              ? Icons.file_present
                              : Icons.upload_file,
                          size: 40,
                          color: _selectedFile != null
                              ? AppColors.tertiary
                              : AppColors.secondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFile?.name ??
                              'Nhấn để chọn file (PDF, DOCX, JPG, PNG)',
                          style: TextStyle(
                            color: _selectedFile != null
                                ? AppColors.tertiary
                                : AppColors.secondary,
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
                    if (v == null || v.isEmpty) {
                      return 'Vui lòng chọn nhóm tài liệu';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(color: AppColors.secondary),
                      ),
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
