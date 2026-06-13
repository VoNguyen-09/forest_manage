class SpeciesFactor {
  final String speciesId;
  final String speciesName;
  final double factor;
  final String updatedBy;
  final DateTime updatedAt;

  const SpeciesFactor({
    required this.speciesId,
    required this.speciesName,
    required this.factor,
    required this.updatedBy,
    required this.updatedAt,
  });

  factory SpeciesFactor.fromJson(Map<String, dynamic> json) => SpeciesFactor(
    speciesId: json['speciesId'] as String,
    speciesName: json['speciesName'] as String,
    factor: (json['factor'] as num).toDouble(),
    updatedBy: json['updatedBy'] as String,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'speciesId': speciesId,
    'speciesName': speciesName,
    'factor': factor,
    'updatedBy': updatedBy,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class CarbonBreakdownItem {
  final String species;
  final double dbh;
  final double height;
  final int quantity;
  final double biomassFactor;
  final double biomassKg;
  final double carbonTon;
  final double co2eTon;

  const CarbonBreakdownItem({
    required this.species,
    required this.dbh,
    required this.height,
    required this.quantity,
    required this.biomassFactor,
    required this.biomassKg,
    required this.carbonTon,
    required this.co2eTon,
  });

  factory CarbonBreakdownItem.fromJson(Map<String, dynamic> json) =>
      CarbonBreakdownItem(
        species: json['species'] as String,
        dbh: (json['dbh'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        quantity: (json['quantity'] as num).toInt(),
        biomassFactor: (json['biomassFactor'] as num).toDouble(),
        biomassKg: (json['biomassKg'] as num).toDouble(),
        carbonTon: (json['carbonTon'] as num).toDouble(),
        co2eTon: (json['co2eTon'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
    'species': species,
    'dbh': dbh,
    'height': height,
    'quantity': quantity,
    'biomassFactor': biomassFactor,
    'biomassKg': biomassKg,
    'carbonTon': carbonTon,
    'co2eTon': co2eTon,
  };
}

class CarbonResultModel {
  final String id;
  final String projectId;
  final String? plotId;
  final DateTime calculatedAt;
  final double totalBiomassKg;
  final double carbonStockTon;
  final double co2eTon;
  final List<CarbonBreakdownItem> breakdown;

  const CarbonResultModel({
    required this.id,
    required this.projectId,
    this.plotId,
    required this.calculatedAt,
    required this.totalBiomassKg,
    required this.carbonStockTon,
    required this.co2eTon,
    this.breakdown = const [],
  });

  factory CarbonResultModel.fromJson(Map<String, dynamic> json) =>
      CarbonResultModel(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        plotId: json['plotId'] as String?,
        calculatedAt: DateTime.parse(json['calculatedAt'] as String),
        totalBiomassKg: (json['totalBiomassKg'] as num).toDouble(),
        carbonStockTon: (json['carbonStockTon'] as num).toDouble(),
        co2eTon: (json['co2eTon'] as num).toDouble(),
        breakdown: (json['breakdown'] as List<dynamic>?)
            ?.map((e) =>
                CarbonBreakdownItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    if (plotId != null) 'plotId': plotId,
    'calculatedAt': calculatedAt.toIso8601String(),
    'totalBiomassKg': totalBiomassKg,
    'carbonStockTon': carbonStockTon,
    'co2eTon': co2eTon,
    'breakdown': breakdown.map((b) => b.toJson()).toList(),
  };

  CarbonResultModel copyWith({
    String? id, String? projectId, String? plotId,
    DateTime? calculatedAt, double? totalBiomassKg,
    double? carbonStockTon, double? co2eTon,
    List<CarbonBreakdownItem>? breakdown,
  }) => CarbonResultModel(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    plotId: plotId ?? this.plotId,
    calculatedAt: calculatedAt ?? this.calculatedAt,
    totalBiomassKg: totalBiomassKg ?? this.totalBiomassKg,
    carbonStockTon: carbonStockTon ?? this.carbonStockTon,
    co2eTon: co2eTon ?? this.co2eTon,
    breakdown: breakdown ?? this.breakdown,
  );
}
