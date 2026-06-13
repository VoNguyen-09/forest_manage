enum OwnerType { individual, company, cooperative }

class ForestOwnerModel {
  final String id;
  final String ownerCode;
  final String ownerName;
  final OwnerType type;
  final String cccd;         // CCCD / GPKD
  final String address;
  final String phone;
  final String email;
  final List<Map<String, String>> attachments; // [{url, type, name}]
  final DateTime createdAt;

  const ForestOwnerModel({
    required this.id,
    required this.ownerCode,
    required this.ownerName,
    required this.type,
    required this.cccd,
    required this.address,
    required this.phone,
    required this.email,
    this.attachments = const [],
    required this.createdAt,
  });

  factory ForestOwnerModel.fromJson(Map<String, dynamic> json) => ForestOwnerModel(
    id: json['id'] as String,
    ownerCode: json['ownerCode'] as String,
    ownerName: json['ownerName'] as String,
    type: OwnerType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => OwnerType.individual,
    ),
    cccd: json['cccd'] as String? ?? '',
    address: json['address'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    attachments: (json['attachments'] as List<dynamic>?)
        ?.map((e) => Map<String, String>.from(e as Map))
        .toList() ??
        [],
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerCode': ownerCode,
    'ownerName': ownerName,
    'type': type.name,
    'cccd': cccd,
    'address': address,
    'phone': phone,
    'email': email,
    'attachments': attachments,
    'createdAt': createdAt.toIso8601String(),
  };

  ForestOwnerModel copyWith({
    String? id,
    String? ownerCode,
    String? ownerName,
    OwnerType? type,
    String? cccd,
    String? address,
    String? phone,
    String? email,
    List<Map<String, String>>? attachments,
    DateTime? createdAt,
  }) => ForestOwnerModel(
    id: id ?? this.id,
    ownerCode: ownerCode ?? this.ownerCode,
    ownerName: ownerName ?? this.ownerName,
    type: type ?? this.type,
    cccd: cccd ?? this.cccd,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    attachments: attachments ?? this.attachments,
    createdAt: createdAt ?? this.createdAt,
  );
}
