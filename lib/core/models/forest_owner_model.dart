import 'package:forest_carbon_platform/core/models/gps_point.dart';

enum OwnerType { individual, company, cooperative }

class ForestOwnerModel {
  final String id;
  final String ownerCode;
  final String ownerName;
  final String forestName;
  final String managementProvince;
  final OwnerType type;
  final String cccd;         // CCCD / GPKD
  final String address;
  final String phone;
  final String email;
  final List<Map<String, String>> attachments; // [{url, type, name}]
  final List<GpsPoint> polygon;
  final double totalAreaHa;
  final double perimeter;
  final int totalTrees;
  final DateTime createdAt;

  const ForestOwnerModel({
    required this.id,
    required this.ownerCode,
    required this.ownerName,
    this.forestName = '',
    this.managementProvince = '',
    required this.type,
    required this.cccd,
    required this.address,
    required this.phone,
    required this.email,
    this.attachments = const [],
    this.polygon = const [],
    this.totalAreaHa = 0,
    this.perimeter = 0,
    this.totalTrees = 0,
    required this.createdAt,
  });

  factory ForestOwnerModel.fromJson(Map<String, dynamic> json) => ForestOwnerModel(
    id: json['id'] as String,
    ownerCode: json['ownerCode'] as String,
    ownerName: json['ownerName'] as String,
    forestName: json['forestName'] as String? ?? '',
    managementProvince: json['managementProvince'] as String? ?? '',
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
    polygon: (json['polygon'] as List<dynamic>?)
        ?.map((e) => GpsPoint.fromJson(e as Map<String, dynamic>))
        .toList() ??
        [],
    totalAreaHa: (json['totalAreaHa'] as num?)?.toDouble() ?? 0.0,
    perimeter: (json['perimeter'] as num?)?.toDouble() ?? 0.0,
    totalTrees: (json['totalTrees'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerCode': ownerCode,
    'ownerName': ownerName,
    'forestName': forestName,
    'managementProvince': managementProvince,
    'type': type.name,
    'cccd': cccd,
    'address': address,
    'phone': phone,
    'email': email,
    'attachments': attachments,
    'polygon': polygon.map((e) => e.toJson()).toList(),
    'totalAreaHa': totalAreaHa,
    'perimeter': perimeter,
    'totalTrees': totalTrees,
    'createdAt': createdAt.toIso8601String(),
  };

  ForestOwnerModel copyWith({
    String? id,
    String? ownerCode,
    String? ownerName,
    String? forestName,
    String? managementProvince,
    OwnerType? type,
    String? cccd,
    String? address,
    String? phone,
    String? email,
    List<Map<String, String>>? attachments,
    List<GpsPoint>? polygon,
    double? totalAreaHa,
    double? perimeter,
    int? totalTrees,
    DateTime? createdAt,
  }) {
    return ForestOwnerModel(
      id: id ?? this.id,
      ownerCode: ownerCode ?? this.ownerCode,
      ownerName: ownerName ?? this.ownerName,
      forestName: forestName ?? this.forestName,
      managementProvince: managementProvince ?? this.managementProvince,
      type: type ?? this.type,
      cccd: cccd ?? this.cccd,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      attachments: attachments ?? this.attachments,
      polygon: polygon ?? this.polygon,
      totalAreaHa: totalAreaHa ?? this.totalAreaHa,
      perimeter: perimeter ?? this.perimeter,
      totalTrees: totalTrees ?? this.totalTrees,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
