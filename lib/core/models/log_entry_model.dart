import 'package:forest_carbon_platform/core/models/forest_project_model.dart'
    show GpsPoint;

enum WorkType {
  planting,
  care,
  fertilizing,
  growthCheck,
  patrol,
  firePrevention,
}

extension WorkTypeLabel on WorkType {
  String get label => switch (this) {
    WorkType.planting       => 'Trồng cây',
    WorkType.care           => 'Chăm sóc cây',
    WorkType.fertilizing    => 'Bón phân',
    WorkType.growthCheck    => 'Kiểm tra sinh trưởng',
    WorkType.patrol         => 'Tuần tra',
    WorkType.firePrevention => 'Phòng cháy chữa cháy',
  };
}

class LogEntryModel {
  final String id;
  final DateTime date;
  final String userId;
  final String projectId;
  final String? plotId;
  final GpsPoint gps;
  final WorkType workType;
  final String description;
  final List<String> photoUrls;
  final bool isSynced; // Hive offline flag
  final DateTime createdAt;
  final DateTime? syncedAt;

  const LogEntryModel({
    required this.id,
    required this.date,
    required this.userId,
    required this.projectId,
    this.plotId,
    required this.gps,
    required this.workType,
    required this.description,
    this.photoUrls = const [],
    this.isSynced = false,
    required this.createdAt,
    this.syncedAt,
  });

  factory LogEntryModel.fromJson(Map<String, dynamic> json) => LogEntryModel(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    userId: json['userId'] as String,
    projectId: json['projectId'] as String,
    plotId: json['plotId'] as String?,
    gps: GpsPoint.fromJson(Map<String, dynamic>.from(json['gps'] as Map)),
    workType: WorkType.values.firstWhere(
      (e) => e.name == json['workType'],
      orElse: () => WorkType.care,
    ),
    description: json['description'] as String? ?? '',
    photoUrls: List<String>.from(json['photos'] as List? ?? []),
    isSynced: json['isSynced'] as bool? ?? true,
    createdAt: DateTime.parse(json['createdAt'] as String),
    syncedAt: json['syncedAt'] != null
        ? DateTime.parse(json['syncedAt'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'userId': userId,
    'projectId': projectId,
    if (plotId != null) 'plotId': plotId,
    'gps': gps.toJson(),
    'workType': workType.name,
    'description': description,
    'photos': photoUrls,
    'isSynced': isSynced,
    'createdAt': createdAt.toIso8601String(),
    if (syncedAt != null) 'syncedAt': syncedAt!.toIso8601String(),
  };

  LogEntryModel copyWith({
    String? id, DateTime? date, String? userId, String? projectId,
    String? plotId, GpsPoint? gps, WorkType? workType,
    String? description, List<String>? photoUrls,
    bool? isSynced, DateTime? createdAt, DateTime? syncedAt,
  }) => LogEntryModel(
    id: id ?? this.id,
    date: date ?? this.date,
    userId: userId ?? this.userId,
    projectId: projectId ?? this.projectId,
    plotId: plotId ?? this.plotId,
    gps: gps ?? this.gps,
    workType: workType ?? this.workType,
    description: description ?? this.description,
    photoUrls: photoUrls ?? this.photoUrls,
    isSynced: isSynced ?? this.isSynced,
    createdAt: createdAt ?? this.createdAt,
    syncedAt: syncedAt ?? this.syncedAt,
  );
}
