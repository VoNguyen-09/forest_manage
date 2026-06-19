import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/file_document_model.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/core/services/auth_service.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/features/file_manager/widgets/file_upload_dialog.dart';
import 'package:forest_carbon_platform/features/file_manager/widgets/image_viewer_widget.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:forest_carbon_platform/core/utils/download_helper.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  final _db = FirestoreService.instance;
  String _selectedCategory = 'Tất cả';

  final _auth = AuthService.instance;
  UserRole _userRole = UserRole.platformAdmin;
  UserModel? _currentUserModel;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await _auth.getUserRole();
    final user = await _auth.getCurrentUserModel();
    setState(() {
      _userRole = role;
      _currentUserModel = user;
    });
  }

  Future<void> _showUploadDialog() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const FileUploadDialog(),
    );
  }

  void _showFilePreview(FileDocumentModel file) {
    if (file.url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có URL tài liệu.')),
      );
      return;
    }

    // For images, show full-screen image viewer
    if (file.type.contains('image')) {
      showDialog(
        context: context,
        builder: (context) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text(file.name),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (file.url.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () {
                      _downloadFile(file);
                      Navigator.pop(context);
                    },
                    tooltip: 'Tải xuống',
                  ),
                if (file.url.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () {
                      _launchExternalViewer(file.url);
                    },
                    tooltip: 'Mở ngoài ứng dụng',
                  ),
              ],
            ),
            body: ImageViewerWidget(
              imageUrl: file.url,
              imageName: file.name,
            ),
          ),
        ),
      );
    } else {
      // For PDFs and other files, show information dialog
      _showFileInfoDialog(file);
    }
  }

  void _showFileInfoDialog(FileDocumentModel file) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(_getFileIcon(file.type), color: _getFileColor(file.type)),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(child: Text('Xem tài liệu')),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FileDetailRow(label: 'Tên tài liệu', value: file.name),
                  const SizedBox(height: AppSpacing.sm),
                  _FileDetailRow(label: 'Nhóm tài liệu', value: file.category),
                  const SizedBox(height: AppSpacing.sm),
                  _FileDetailRow(
                    label: 'Ngày cập nhật',
                    value: _formatDate(file.updatedAt),
                  ),
                  if (file.uploadedByName.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _FileDetailRow(
                      label: 'Người tải',
                      value: file.uploadedByName,
                    ),
                  ],
                  if (file.source == 'workerLogbook') ...[
                    const SizedBox(height: AppSpacing.sm),
                    _FileDetailRow(
                      label: 'Nguồn',
                      value: 'Nhật ký forest worker',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.neutral,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getFileIcon(file.type),
                          color: _getFileColor(file.type),
                          size: 48,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SelectableText(
                          file.url.isEmpty ? 'Chưa có URL tài liệu.' : file.url,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if ((file.type == 'pdf' || file.type == 'application/pdf') && file.url.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openPdf(file);
                },
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Mở PDF'),
              ),
            if (file.url.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: file.url));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép URL tài liệu.')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy URL'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Đóng',
                style: TextStyle(color: AppColors.secondary),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPdf(FileDocumentModel file) async {
    try {
      final response = await http.get(Uri.parse(file.url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('HTTP ${response.statusCode}');
      }
      await Printing.layoutPdf(
        name: file.name,
        onLayout: (_) async => response.bodyBytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không mở được PDF: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _launchExternalViewer(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw StateError('Không thể mở URL.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi mở tài liệu: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _confirmDeleteFile(FileDocumentModel file) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Xóa tài liệu'),
          content: Text('Bạn có chắc chắn muốn xóa "${file.name}" không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppColors.secondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _db.deleteFileDocument(file.id);
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa tài liệu.')),
                );
              },
              child: const Text(
                'Xóa',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approveFile(FileDocumentModel file) async {
    await _db.updateFileStatus(file.id, 'approved');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã duyệt và gửi tài liệu cho Admin.')),
    );
  }

  Future<void> _downloadFile(FileDocumentModel file) async {
    if (file.url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có URL để tải xuống.')),
      );
      return;
    }

    // Hiện loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang chuẩn bị tải xuống...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      if (kIsWeb) {
        // Web: fetch bytes → Blob URL → anchor[download] — cách duy nhất hoạt động với cross-origin
        final filename = file.name.isNotEmpty
            ? file.name.endsWith('.${file.type}') ? file.name : '${file.name}.${file.type}'
            : '${file.type}.${file.type}';
        await triggerDownload(file.url, filename);
      } else {
        // Mobile / Desktop: mở URL bằng ứng dụng bên ngoài
        final uri = Uri.parse(file.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw StateError('Không thể mở URL.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải xuống: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
        return Icons.description;
      case 'img':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String type) {
    switch (type) {
      case 'pdf':
        return AppColors.error;
      case 'doc':
        return AppColors.info;
      case 'img':
        return AppColors.success;
      default:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= AppBreakpoints.web;
    final isAdmin = _userRole == UserRole.platformAdmin;
    final isOwner = _userRole == UserRole.forestOwner;

    final List<String> visibleCategories = [
      'Tất cả',
      if (isAdmin || isOwner) 'Hồ sơ pháp lý',
      if (isAdmin || isOwner) 'Hồ sơ dự án',
      if (isAdmin || isOwner) 'Hình ảnh hiện trường',
      if (isAdmin || isOwner) 'Báo cáo khảo sát',
    ];

    bool canUpload = false;
    if (isAdmin && (_selectedCategory == 'Tất cả' || _selectedCategory == 'Hồ sơ pháp lý' || _selectedCategory == 'Hồ sơ dự án')) {
      canUpload = true;
    } else if (isOwner && (_selectedCategory == 'Tất cả' || _selectedCategory == 'Hình ảnh hiện trường' || _selectedCategory == 'Báo cáo khảo sát')) {
      canUpload = true;
    }

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: const Text(AppStrings.fileManager),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})],
      ),
      floatingActionButton: canUpload ? FloatingActionButton.extended(
        onPressed: _showUploadDialog,
        backgroundColor: AppColors.tertiary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.upload),
        label: const Text(AppStrings.upload),
      ) : null,
      body: StreamBuilder<List<FileDocumentModel>>(
        stream: _db.streamFileDocuments(
          ownerId: isOwner && _currentUserModel?.ownerId.isNotEmpty == true 
              ? _currentUserModel?.ownerId 
              : null,
          excludePending: isAdmin,
        ),
        builder: (context, snapshot) {
          final files = snapshot.data ?? const <FileDocumentModel>[];
          final filteredFiles = _selectedCategory == 'Tất cả'
              ? files
              : files.where((f) => f.category == _selectedCategory).toList();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isWeb)
                Container(
                  width: 250,
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: visibleCategories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return ListTile(
                        title: Text(
                          category,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.tertiary
                                : AppColors.primary,
                          ),
                        ),
                        selected: isSelected,
                        selectedTileColor: AppColors.tertiary.withValues(
                          alpha: 0.1,
                        ),
                        onTap: () =>
                            setState(() => _selectedCategory = category),
                      );
                    }).toList(),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(
                    isWeb ? AppSpacing.lg : AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isWeb) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            prefixIcon: Icon(Icons.filter_list),
                          ),
                          items: visibleCategories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedCategory = value);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Text(
                        '$_selectedCategory (${filteredFiles.length} tài liệu)',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child:
                            snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                files.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : filteredFiles.isEmpty
                            ? Center(
                                child: Text(
                                  AppStrings.errorEmpty,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              )
                            : isWeb
                            ? GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      childAspectRatio: 3,
                                      crossAxisSpacing: AppSpacing.md,
                                      mainAxisSpacing: AppSpacing.md,
                                    ),
                                itemCount: filteredFiles.length,
                                itemBuilder: (context, index) =>
                                    _buildFileCard(filteredFiles[index]),
                              )
                            : ListView.separated(
                                itemCount: filteredFiles.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) =>
                                    _buildFileCard(filteredFiles[index]),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFileCard(FileDocumentModel file) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getFileColor(file.type).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getFileIcon(file.type), color: _getFileColor(file.type)),
        ),
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${file.category} • ${_formatDate(file.createdAt)}'),
            if (file.status == 'pending')
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.warning),
                ),
                child: const Text('Chờ duyệt', style: TextStyle(color: AppColors.warning, fontSize: 12)),
              ),
            if (file.status == 'approved' && (file.category == 'Hình ảnh hiện trường' || file.category == 'Báo cáo khảo sát'))
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.success),
                ),
                child: const Text('Đã gửi Admin', style: TextStyle(color: AppColors.success, fontSize: 12)),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'view') {
              _showFilePreview(file);
            } else if (value == 'download') {
              _downloadFile(file);
            } else if (value == 'delete') {
              _confirmDeleteFile(file);
            } else if (value == 'approve') {
              _approveFile(file);
            }
          },
          itemBuilder: (context) {
            final isAdmin = _userRole == UserRole.platformAdmin;
            final isOwner = _userRole == UserRole.forestOwner;
            final canDelete = (isAdmin && (file.category == 'Hồ sơ pháp lý' || file.category == 'Hồ sơ dự án')) ||
                              (isOwner && (file.category == 'Hình ảnh hiện trường' || file.category == 'Báo cáo khảo sát'));
            final canApprove = isOwner && file.status == 'pending' && (file.category == 'Hình ảnh hiện trường' || file.category == 'Báo cáo khảo sát');
            
            return [
              const PopupMenuItem(
                value: 'view',
                child: ListTile(
                  leading: Icon(Icons.visibility_outlined),
                  title: Text('Xem'),
                ),
              ),
              const PopupMenuItem(
                value: 'download',
                child: ListTile(
                  leading: Icon(Icons.download_outlined),
                  title: Text('Tải xuống'),
                ),
              ),
              if (canApprove)
                const PopupMenuItem(
                  value: 'approve',
                  child: ListTile(
                    leading: Icon(Icons.send_outlined, color: AppColors.success),
                    title: Text('Gửi Admin', style: TextStyle(color: AppColors.success)),
                  ),
                ),
              if (canDelete)
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: AppColors.error),
                    title: Text('Xóa', style: TextStyle(color: AppColors.error)),
                  ),
                ),
            ];
          },
        ),
        onTap: () => _showFilePreview(file),
      ),
    );
  }
}

class _FileDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _FileDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
