enum ProjectStatus { draft, surveying, active, suspended }

class GpsPoint {
  final double lat;
  final double lng;

  const GpsPoint({required this.lat, required this.lng});

  factory GpsPoint.fromJson(Map<String, dynamic> json) => GpsPoint(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class ForestProjectModel {
  final String id;
  final String projectName;
  final String ownerId;
  final String province;
  final String district;
  final String commune;
  final String forestType;
  final String treeSpecies;
  final int yearPlanted;
  final ProjectStatus status;
  final List<GpsPoint> polygon;
  final double totalAreaHa;
  final double perimeter;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ForestProjectModel({
    required this.id,
    required this.projectName,
    required this.ownerId,
    required this.province,
    required this.district,
    required this.commune,
    required this.forestType,
    required this.treeSpecies,
    required this.yearPlanted,
    required this.status,
    this.polygon = const [],
    this.totalAreaHa = 0,
    this.perimeter = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ForestProjectModel.fromJson(Map<String, dynamic> json) => ForestProjectModel(
    id: json['id'] as String,
    projectName: json['projectName'] as String,
    ownerId: json['ownerId'] as String,
    province: json['province'] as String? ?? '',
    district: json['district'] as String? ?? '',
    commune: json['commune'] as String? ?? '',
    forestType: json['forestType'] as String? ?? '',
    treeSpecies: json['treeSpecies'] as String? ?? '',
    yearPlanted: (json['yearPlanted'] as num?)?.toInt() ?? DateTime.now().year,
    status: ProjectStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => ProjectStatus.draft,
    ),
    polygon: (json['polygon'] as List<dynamic>?)
        ?.map((e) => GpsPoint.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList() ??
        [],
    totalAreaHa: (json['totalAreaHa'] as num?)?.toDouble() ?? 0,
    perimeter: (json['perimeter'] as num?)?.toDouble() ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectName': projectName,
    'ownerId': ownerId,
    'province': province,
    'district': district,
    'commune': commune,
    'forestType': forestType,
    'treeSpecies': treeSpecies,
    'yearPlanted': yearPlanted,
    'status': status.name,
    'polygon': polygon.map((p) => p.toJson()).toList(),
    'totalAreaHa': totalAreaHa,
    'perimeter': perimeter,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  ForestProjectModel copyWith({
    String? id, String? projectName, String? ownerId,
    String? province, String? district, String? commune,
    String? forestType, String? treeSpecies, int? yearPlanted,
    ProjectStatus? status, List<GpsPoint>? polygon,
    double? totalAreaHa, double? perimeter,
    DateTime? createdAt, DateTime? updatedAt,
  }) => ForestProjectModel(
    id: id ?? this.id,
    projectName: projectName ?? this.projectName,
    ownerId: ownerId ?? this.ownerId,
    province: province ?? this.province,
    district: district ?? this.district,
    commune: commune ?? this.commune,
    forestType: forestType ?? this.forestType,
    treeSpecies: treeSpecies ?? this.treeSpecies,
    yearPlanted: yearPlanted ?? this.yearPlanted,
    status: status ?? this.status,
    polygon: polygon ?? this.polygon,
    totalAreaHa: totalAreaHa ?? this.totalAreaHa,
    perimeter: perimeter ?? this.perimeter,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
