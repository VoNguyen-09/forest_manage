import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/core/services/notification_service.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/core/models/notification_model.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/shared/widgets/empty_state.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late String _currentUserId;
  String? _notificationRecipientId;
  List<String> _notificationRecipientIds = const [];

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadNotificationRecipientId();
  }

  Future<void> _loadNotificationRecipientId() async {
    if (_currentUserId.isEmpty) return;

    try {
      final user = await FirestoreService.instance.getUser(_currentUserId);
      if (mounted) {
        setState(() {
          if (user?.role == UserRole.platformAdmin) {
            _notificationRecipientId =
                FirestoreService.platformAdminNotificationUserId;
            _notificationRecipientIds = [
              FirestoreService.platformAdminNotificationUserId,
              _currentUserId,
            ];
          } else if (user?.role == UserRole.forestOwner &&
              user?.ownerId.isNotEmpty == true) {
            _notificationRecipientId = user!.ownerId;
            _notificationRecipientIds = [user.ownerId];
          } else {
            _notificationRecipientId = _currentUserId;
            _notificationRecipientIds = [_currentUserId];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading notification recipient ID: $e');
    }
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.project:
        return Icons.folder_special;
      case NotificationType.fieldLog:
        return Icons.assignment;
      case NotificationType.carbon:
        return Icons.eco;
      case NotificationType.document:
        return Icons.description_outlined;
      case NotificationType.survey:
        return Icons.fact_check_outlined;
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.project:
        return AppColors.primary;
      case NotificationType.fieldLog:
        return AppColors.info;
      case NotificationType.carbon:
        return AppColors.success;
      case NotificationType.document:
        return AppColors.tertiary;
      case NotificationType.survey:
        return AppColors.warning;
      case NotificationType.warning:
        return AppColors.error;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'Vừa xong';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  Future<void> _markAllAsRead(List<NotificationModel> notifications) async {
    try {
      final unreadNotifications = notifications
          .where((n) => !n.isRead)
          .toList();
      for (final notif in unreadNotifications) {
        await NotificationService.instance.markAsRead(notif.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= AppBreakpoints.web;

    if (_currentUserId.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.neutral,
        appBar: AppBar(
          title: const Text('Trung tâm thông báo'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
        ),
        body: Center(
          child: AppEmptyState(
            title: 'Vui lòng đăng nhập',
            subtitle: 'Không thể tải thông báo mà không đăng nhập',
            icon: Icons.lock_outlined,
          ),
        ),
      );
    }

    if (_notificationRecipientId == null) {
      return Scaffold(
        backgroundColor: AppColors.neutral,
        appBar: AppBar(
          title: const Text('Trung tâm thông báo'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: const Text('Trung tâm thông báo'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: NotificationService.instance.getNotificationsForUserIdsStream(
          _notificationRecipientIds.isNotEmpty
              ? _notificationRecipientIds
              : [_notificationRecipientId!],
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: AppEmptyState(
                title: 'Lỗi tải thông báo',
                subtitle: 'Có lỗi xảy ra: ${snapshot.error}',
                icon: Icons.error_outline,
              ),
            );
          }

          final notifications = snapshot.data ?? [];
          final unreadCount = notifications.where((n) => !n.isRead).length;

          if (notifications.isEmpty) {
            return Center(
              child: AppEmptyState(
                title: 'Chưa có thông báo',
                subtitle: 'Bạn sẽ nhận thông báo khi có sự kiện mới',
                icon: Icons.notifications_none_outlined,
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  if (unreadCount > 0)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Chưa đọc ($unreadCount)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          TextButton(
                            onPressed: () => _markAllAsRead(notifications),
                            child: const Text(
                              'Đánh dấu đã đọc tất cả',
                              style: TextStyle(color: AppColors.tertiary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.all(
                        isWeb ? AppSpacing.lg : AppSpacing.md,
                      ),
                      itemCount: notifications.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final notif = notifications[index];
                        return AppCard(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: ListTile(
                            leading: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _getColorForType(
                                      notif.type,
                                    ).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getIconForType(notif.type),
                                    color: _getColorForType(notif.type),
                                  ),
                                ),
                                if (!notif.isRead)
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
                              notif.title,
                              style: TextStyle(
                                fontWeight: notif.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(notif.body),
                                const SizedBox(height: 8),
                                Text(
                                  _getTimeAgo(notif.createdAt),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: AppColors.secondary),
                                ),
                              ],
                            ),
                            onTap: () async {
                              if (!notif.isRead) {
                                try {
                                  await NotificationService.instance.markAsRead(
                                    notif.id,
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Lỗi: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
