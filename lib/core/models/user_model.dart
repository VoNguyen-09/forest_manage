import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { platformAdmin, forestOwner, forestWorker }

enum UserStatus { active, inactive, locked }

class UserModel {
  final String uid;
  final String fullName;
  final String phone;
  final String email;
  final UserRole role;
  final UserStatus status;
  final String ownerId;
  final String ownerName;
  final String forestName;
  final String managementProvince;
  final double totalAreaHa;
  final String workerCode;
  final String workerAssignment;
  final List<String> assignedProjectIds;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.role,
    required this.status,
    this.ownerId = '',
    this.ownerName = '',
    this.forestName = '',
    this.managementProvince = '',
    this.totalAreaHa = 0,
    this.workerCode = '',
    this.workerAssignment = '',
    this.assignedProjectIds = const [],
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    uid: json['uid'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: UserRole.values.firstWhere(
      (e) => e.name == json['role'],
      orElse: () => UserRole.forestWorker,
    ),
    status: UserStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => UserStatus.active,
    ),
    ownerId: json['ownerId'] as String? ?? '',
    ownerName: json['ownerName'] as String? ?? '',
    forestName: json['forestName'] as String? ?? '',
    managementProvince: json['managementProvince'] as String? ?? '',
    totalAreaHa: (json['totalAreaHa'] as num?)?.toDouble() ?? 0,
    workerCode: json['workerCode'] as String? ?? '',
    workerAssignment: json['workerAssignment'] as String? ?? '',
    assignedProjectIds: (json['assignedProjectIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    createdAt: _parseDateTime(json['createdAt']),
  );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'fullName': fullName,
    'phone': phone,
    'email': email,
    'role': role.name,
    'status': status.name,
    'ownerId': ownerId,
    'ownerName': ownerName,
    'forestName': forestName,
    'managementProvince': managementProvince,
    'totalAreaHa': totalAreaHa,
    'workerCode': workerCode,
    'workerAssignment': workerAssignment,
    'assignedProjectIds': assignedProjectIds,
    'createdAt': createdAt.toIso8601String(),
  };

  UserModel copyWith({
    String? uid,
    String? fullName,
    String? phone,
    String? email,
    UserRole? role,
    UserStatus? status,
    String? ownerId,
    String? ownerName,
    String? forestName,
    String? managementProvince,
    double? totalAreaHa,
    String? workerCode,
    String? workerAssignment,
    List<String>? assignedProjectIds,
    DateTime? createdAt,
  }) => UserModel(
    uid: uid ?? this.uid,
    fullName: fullName ?? this.fullName,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    role: role ?? this.role,
    status: status ?? this.status,
    ownerId: ownerId ?? this.ownerId,
    ownerName: ownerName ?? this.ownerName,
    forestName: forestName ?? this.forestName,
    managementProvince: managementProvince ?? this.managementProvince,
    totalAreaHa: totalAreaHa ?? this.totalAreaHa,
    workerCode: workerCode ?? this.workerCode,
    workerAssignment: workerAssignment ?? this.workerAssignment,
    assignedProjectIds: assignedProjectIds ?? this.assignedProjectIds,
    createdAt: createdAt ?? this.createdAt,
  );

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) return DateTime.parse(value);
    return DateTime.now();
  }
}
