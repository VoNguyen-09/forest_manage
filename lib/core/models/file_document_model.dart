import 'package:cloud_firestore/cloud_firestore.dart';

class FileDocumentModel {
  final String id;
  final String name;
  final String category;
  final String type;
  final String url;
  final String ownerId;
  final String projectId;
  final String uploadedBy;
  final String uploadedByName;
  final String source;
  final String? sourceLogId;
  final String status; // 'pending' or 'approved'
  final List<String> photoUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FileDocumentModel({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.url,
    this.ownerId = '',
    this.projectId = '',
    this.uploadedBy = '',
    this.uploadedByName = '',
    this.source = 'manual',
    this.sourceLogId,
    this.status = 'approved',
    this.photoUrls = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory FileDocumentModel.fromJson(Map<String, dynamic> json) {
    return FileDocumentModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      type: json['type'] as String? ?? 'file',
      url: json['url'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      uploadedBy: json['uploadedBy'] as String? ?? '',
      uploadedByName: json['uploadedByName'] as String? ?? '',
      source: json['source'] as String? ?? 'manual',
      sourceLogId: json['sourceLogId'] as String?,
      status: json['status'] as String? ?? 'approved',
      photoUrls: List<String>.from(json['photoUrls'] as List? ?? const []),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'type': type,
    'url': url,
    'ownerId': ownerId,
    'projectId': projectId,
    'uploadedBy': uploadedBy,
    'uploadedByName': uploadedByName,
    'source': source,
    if (sourceLogId != null) 'sourceLogId': sourceLogId,
    'status': status,
    'photoUrls': photoUrls,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  FileDocumentModel copyWith({
    String? id,
    String? name,
    String? category,
    String? type,
    String? url,
    String? ownerId,
    String? projectId,
    String? uploadedBy,
    String? uploadedByName,
    String? source,
    String? sourceLogId,
    String? status,
    List<String>? photoUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FileDocumentModel(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    type: type ?? this.type,
    url: url ?? this.url,
    ownerId: ownerId ?? this.ownerId,
    projectId: projectId ?? this.projectId,
    uploadedBy: uploadedBy ?? this.uploadedBy,
    uploadedByName: uploadedByName ?? this.uploadedByName,
    source: source ?? this.source,
    sourceLogId: sourceLogId ?? this.sourceLogId,
    status: status ?? this.status,
    photoUrls: photoUrls ?? this.photoUrls,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) return DateTime.parse(value);
    return DateTime.now();
  }
}
