import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Mock data cho thông báo
  final List<Map<String, dynamic>> _mockNotifications = [
    {
      'title': 'Dự án mới cần duyệt',
      'body': 'Dự án "Rồng Keo Lai Đắk Lắk" vừa được gửi yêu cầu phê duyệt.',
      'type': 'project',
      'isRead': false,
      'time': '10 phút trước'
    },
    {
      'title': 'Nhật ký hiện trường cập nhật',
      'body': 'Nguyễn Văn A đã thêm hình ảnh hiện trường mới.',
      'type': 'logbook',
      'isRead': false,
      'time': '2 giờ trước'
    },
    {
      'title': 'Báo cáo sinh khối hoàn tất',
      'body': 'Hệ thống đã tính toán xong sinh khối quý 2/2026.',
      'type': 'carbon',
      'isRead': true,
      'time': '1 ngày trước'
    },
    {
      'title': 'Cảnh báo đồng bộ',
      'body': 'Phát hiện 3 ô mẫu bị lỗi tọa độ khi đồng bộ từ app.',
      'type': 'warning',
      'isRead': true,
      'time': '2 ngày trước'
    },
  ];

  IconData _getIconForType(String type) {
    switch (type) {
      case 'project': return Icons.folder_special;
      case 'logbook': return Icons.assignment;
      case 'carbon': return Icons.eco;
      case 'warning': return Icons.warning_amber_rounded;
      default: return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'project': return AppColors.primary;
      case 'logbook': return AppColors.info;
      case 'carbon': return AppColors.success;
      case 'warning': return AppColors.error;
      default: return AppColors.secondary;
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (var notif in _mockNotifications) {
        notif['isRead'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= AppBreakpoints.web;
    final unreadCount = _mockNotifications.where((n) => n['isRead'] == false).length;

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: const Text('Trung tâm thông báo'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Đánh dấu đã đọc tất cả', style: TextStyle(color: AppColors.primary)),
            ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800), // Max width on web
          child: ListView.separated(
            padding: EdgeInsets.all(isWeb ? AppSpacing.lg : AppSpacing.md),
            itemCount: _mockNotifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final notif = _mockNotifications[index];
              return AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: ListTile(
                  leading: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getColorForType(notif['type']).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIconForType(notif['type']),
                          color: _getColorForType(notif['type']),
                        ),
                      ),
                      if (!notif['isRead'])
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    notif['title'],
                    style: TextStyle(
                      fontWeight: notif['isRead'] ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(notif['body']),
                      const SizedBox(height: 8),
                      Text(
                        notif['time'],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondary),
                      ),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      notif['isRead'] = true;
                    });
                    // TODO: Gọi API chuyển trạng thái đã đọc
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
