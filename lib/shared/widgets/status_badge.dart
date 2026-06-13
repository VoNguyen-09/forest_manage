import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/theme.dart';

enum BadgeStatus { active, inactive, locked, draft, surveying, suspended, synced, pending }

extension BadgeStatusStyle on BadgeStatus {
  String get label => switch (this) {
    BadgeStatus.active    => 'Hoạt động',
    BadgeStatus.inactive  => 'Không hoạt động',
    BadgeStatus.locked    => 'Đã khóa',
    BadgeStatus.draft     => 'Nháp',
    BadgeStatus.surveying => 'Đang khảo sát',
    BadgeStatus.suspended => 'Tạm dừng',
    BadgeStatus.synced    => 'Đã đồng bộ',
    BadgeStatus.pending   => 'Chưa đồng bộ',
  };

  Color get color => switch (this) {
    BadgeStatus.active    => AppColors.success,
    BadgeStatus.inactive  => AppColors.secondary,
    BadgeStatus.locked    => AppColors.error,
    BadgeStatus.draft     => AppColors.info,
    BadgeStatus.surveying => AppColors.warning,
    BadgeStatus.suspended => AppColors.error,
    BadgeStatus.synced    => AppColors.success,
    BadgeStatus.pending   => AppColors.warning,
  };
}

/// Pill-shaped status badge — dùng cho tất cả trạng thái trong app
class AppStatusBadge extends StatelessWidget {
  final BadgeStatus status;
  final String? customLabel;

  const AppStatusBadge({
    super.key,
    required this.status,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        customLabel ?? status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
