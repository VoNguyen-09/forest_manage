import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerLocationModel {
  final String workerId;
  final String workerName;
  final String ownerId;
  final String projectId;
  final double lat;
  final double lng;
  final double accuracy;
  final bool isOnline;
  final DateTime updatedAt;

  const WorkerLocationModel({
    required this.workerId,
    required this.workerName,
    required this.ownerId,
    required this.projectId,
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.isOnline,
    required this.updatedAt,
  });

  factory WorkerLocationModel.fromJson(Map<String, dynamic> json) =>
      WorkerLocationModel(
        workerId: json['workerId'] as String? ?? '',
        workerName: json['workerName'] as String? ?? '',
        ownerId: json['ownerId'] as String? ?? '',
        projectId: json['projectId'] as String? ?? '',
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
        accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
        isOnline: json['isOnline'] as bool? ?? false,
        updatedAt: _parseDateTime(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
    'workerId': workerId,
    'workerName': workerName,
    'ownerId': ownerId,
    'projectId': projectId,
    'lat': lat,
    'lng': lng,
    'accuracy': accuracy,
    'isOnline': isOnline,
    'updatedAt': updatedAt.toIso8601String(),
  };

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) return DateTime.parse(value);
    return DateTime.now();
  }
}
