enum UserRole { platformAdmin, forestOwner, forestWorker }

enum UserStatus { active, inactive, locked }

class UserModel {
  final String uid;
  final String fullName;
  final String phone;
  final String email;
  final UserRole role;
  final UserStatus status;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    uid: json['uid'] as String,
    fullName: json['fullName'] as String,
    phone: json['phone'] as String,
    email: json['email'] as String,
    role: UserRole.values.firstWhere(
      (e) => e.name == json['role'],
      orElse: () => UserRole.forestWorker,
    ),
    status: UserStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => UserStatus.active,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'fullName': fullName,
    'phone': phone,
    'email': email,
    'role': role.name,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
  };

  UserModel copyWith({
    String? uid,
    String? fullName,
    String? phone,
    String? email,
    UserRole? role,
    UserStatus? status,
    DateTime? createdAt,
  }) => UserModel(
    uid: uid ?? this.uid,
    fullName: fullName ?? this.fullName,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    role: role ?? this.role,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
}
