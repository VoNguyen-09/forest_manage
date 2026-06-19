import 'package:forest_carbon_platform/core/models/gps_point.dart';

class TreeData {
  final String species;
  final double dbh;       // Diameter at Breast Height (cm)
  final double height;    // Height (m)
  final int quantity;

  const TreeData({
    required this.species,
    required this.dbh,
    required this.height,
    required this.quantity,
  });

  factory TreeData.fromJson(Map<String, dynamic> json) => TreeData(
    species: json['species'] as String,
    dbh: (json['dbh'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    quantity: (json['quantity'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'species': species,
    'dbh': dbh,
    'height': height,
    'quantity': quantity,
  };

  TreeData copyWith({
    String? species, double? dbh, double? height, int? quantity,
  }) => TreeData(
    species: species ?? this.species,
    dbh: dbh ?? this.dbh,
    height: height ?? this.height,
    quantity: quantity ?? this.quantity,
  );
}

class PlotDataModel {
  final String id;
  final String plotCode;
  final String projectId;
  final GpsPoint gps;
  final double areaSqm;
  final List<TreeData> trees;
  final bool isSynced;
  final DateTime createdAt;

  const PlotDataModel({
    required this.id,
    required this.plotCode,
    required this.projectId,
    required this.gps,
    required this.areaSqm,
    this.trees = const [],
    this.isSynced = false,
    required this.createdAt,
  });

  factory PlotDataModel.fromJson(Map<String, dynamic> json) => PlotDataModel(
    id: json['id'] as String,
    plotCode: json['plotCode'] as String,
    projectId: json['projectId'] as String,
    gps: GpsPoint.fromJson(Map<String, dynamic>.from(json['gps'] as Map)),
    areaSqm: (json['areaSqm'] as num).toDouble(),
    trees: (json['trees'] as List<dynamic>?)
        ?.map((e) => TreeData.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList() ??
        [],
    isSynced: json['isSynced'] as bool? ?? true,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'plotCode': plotCode,
    'projectId': projectId,
    'gps': gps.toJson(),
    'areaSqm': areaSqm,
    'trees': trees.map((t) => t.toJson()).toList(),
    'isSynced': isSynced,
    'createdAt': createdAt.toIso8601String(),
  };

  PlotDataModel copyWith({
    String? id, String? plotCode, String? projectId,
    GpsPoint? gps, double? areaSqm, List<TreeData>? trees,
    bool? isSynced, DateTime? createdAt,
  }) => PlotDataModel(
    id: id ?? this.id,
    plotCode: plotCode ?? this.plotCode,
    projectId: projectId ?? this.projectId,
    gps: gps ?? this.gps,
    areaSqm: areaSqm ?? this.areaSqm,
    trees: trees ?? this.trees,
    isSynced: isSynced ?? this.isSynced,
    createdAt: createdAt ?? this.createdAt,
  );
}
