enum NotificationType { fieldLog, carbon, project, document, survey, warning }

extension NotificationTypeLabel on NotificationType {
  String get label => switch (this) {
    NotificationType.fieldLog => 'Nhật ký hiện trường',
    NotificationType.carbon => 'Tính toán Carbon',
    NotificationType.project => 'Dự án',
    NotificationType.document => 'Tài liệu',
    NotificationType.survey => 'Báo cáo khảo sát',
    NotificationType.warning => 'Cảnh báo',
  };
}

class NotificationModel {
  final String id;
  final String userId; // ID of forest owner receiving notification
  final String title;
  final String body;
  final NotificationType type;
  final String?
  relatedId; // ID of related resource (logEntry, carbonResult, project, etc)
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.relatedId,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        userId: json['userId'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        type: NotificationType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => NotificationType.warning,
        ),
        relatedId: json['relatedId'] as String?,
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'body': body,
    'type': type.name,
    if (relatedId != null) 'relatedId': relatedId,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
  };

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    String? relatedId,
    bool? isRead,
    DateTime? createdAt,
  }) => NotificationModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    body: body ?? this.body,
    type: type ?? this.type,
    relatedId: relatedId ?? this.relatedId,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt ?? this.createdAt,
  );
}
