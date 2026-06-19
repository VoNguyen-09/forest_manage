enum CarbonApprovalStatus {
  pending,              // Forest Worker submitted, awaiting Forest Owner approval
  approvedByOwner,      // Approved by Forest Owner, can be sent to Admin
  rejectedByOwner,      // Rejected by Forest Owner
  approvedByAdmin,      // Approved by Admin
  rejectedByAdmin,      // Rejected by Admin
}

class SpeciesFactor {
  final String speciesId;
  final String speciesName;
  final double factor;
  final int totalTreesCount;
  final String updatedBy;
  final DateTime updatedAt;

  const SpeciesFactor({
    required this.speciesId,
    required this.speciesName,
    required this.factor,
    this.totalTreesCount = 0,
    required this.updatedBy,
    required this.updatedAt,
  });

  factory SpeciesFactor.fromJson(Map<String, dynamic> json) => SpeciesFactor(
    speciesId: json['speciesId'] as String,
    speciesName: json['speciesName'] as String,
    factor: (json['factor'] as num).toDouble(),
    totalTreesCount: (json['totalTreesCount'] as num?)?.toInt() ?? 0,
    updatedBy: json['updatedBy'] as String,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'speciesId': speciesId,
    'speciesName': speciesName,
    'factor': factor,
    'totalTreesCount': totalTreesCount,
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
  final String ownerId;
  final String workerId;
  final String? plotId;
  final DateTime calculatedAt;
  final double totalBiomassKg;
  final double carbonStockTon;
  final double co2eTon;
  final List<CarbonBreakdownItem> breakdown;
  
  // Approval workflow fields
  final CarbonApprovalStatus status;
  final DateTime? approvedByOwnerAt;
  final String? ownerRejectionReason;
  final DateTime? rejectedByOwnerAt;
  final DateTime? approvedByAdminAt;
  final DateTime? rejectedByAdminAt;
  final String? adminRejectionReason;

  const CarbonResultModel({
    required this.id,
    required this.projectId,
    this.ownerId = '',
    this.workerId = '',
    this.plotId,
    required this.calculatedAt,
    required this.totalBiomassKg,
    required this.carbonStockTon,
    required this.co2eTon,
    this.breakdown = const [],
    this.status = CarbonApprovalStatus.pending,
    this.approvedByOwnerAt,
    this.ownerRejectionReason,
    this.rejectedByOwnerAt,
    this.approvedByAdminAt,
    this.rejectedByAdminAt,
    this.adminRejectionReason,
  });

  factory CarbonResultModel.fromJson(Map<String, dynamic> json) =>
      CarbonResultModel(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        ownerId: json['ownerId'] as String? ?? '',
        workerId: json['workerId'] as String? ?? '',
        plotId: json['plotId'] as String?,
        calculatedAt: DateTime.parse(json['calculatedAt'] as String),
        totalBiomassKg: (json['totalBiomassKg'] as num).toDouble(),
        carbonStockTon: (json['carbonStockTon'] as num).toDouble(),
        co2eTon: (json['co2eTon'] as num).toDouble(),
        breakdown:
            (json['breakdown'] as List<dynamic>?)
                ?.map(
                  (e) => CarbonBreakdownItem.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList() ??
            [],
        status: CarbonApprovalStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String?),
          orElse: () => CarbonApprovalStatus.pending,
        ),
        approvedByOwnerAt: json['approvedByOwnerAt'] != null
            ? DateTime.parse(json['approvedByOwnerAt'] as String)
            : null,
        ownerRejectionReason: json['ownerRejectionReason'] as String?,
        rejectedByOwnerAt: json['rejectedByOwnerAt'] != null
            ? DateTime.parse(json['rejectedByOwnerAt'] as String)
            : null,
        approvedByAdminAt: json['approvedByAdminAt'] != null
            ? DateTime.parse(json['approvedByAdminAt'] as String)
            : null,
        rejectedByAdminAt: json['rejectedByAdminAt'] != null
            ? DateTime.parse(json['rejectedByAdminAt'] as String)
            : null,
        adminRejectionReason: json['adminRejectionReason'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'ownerId': ownerId,
    'workerId': workerId,
    if (plotId != null) 'plotId': plotId,
    'calculatedAt': calculatedAt.toIso8601String(),
    'totalBiomassKg': totalBiomassKg,
    'carbonStockTon': carbonStockTon,
    'co2eTon': co2eTon,
    'breakdown': breakdown.map((b) => b.toJson()).toList(),
    'status': status.name,
    if (approvedByOwnerAt != null) 'approvedByOwnerAt': approvedByOwnerAt!.toIso8601String(),
    if (ownerRejectionReason != null) 'ownerRejectionReason': ownerRejectionReason,
    if (rejectedByOwnerAt != null) 'rejectedByOwnerAt': rejectedByOwnerAt!.toIso8601String(),
    if (approvedByAdminAt != null) 'approvedByAdminAt': approvedByAdminAt!.toIso8601String(),
    if (rejectedByAdminAt != null) 'rejectedByAdminAt': rejectedByAdminAt!.toIso8601String(),
    if (adminRejectionReason != null) 'adminRejectionReason': adminRejectionReason,
  };

  CarbonResultModel copyWith({
    String? id,
    String? projectId,
    String? ownerId,
    String? workerId,
    String? plotId,
    DateTime? calculatedAt,
    double? totalBiomassKg,
    double? carbonStockTon,
    double? co2eTon,
    List<CarbonBreakdownItem>? breakdown,
    CarbonApprovalStatus? status,
    DateTime? approvedByOwnerAt,
    String? ownerRejectionReason,
    DateTime? rejectedByOwnerAt,
    DateTime? approvedByAdminAt,
    DateTime? rejectedByAdminAt,
    String? adminRejectionReason,
  }) => CarbonResultModel(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    ownerId: ownerId ?? this.ownerId,
    workerId: workerId ?? this.workerId,
    plotId: plotId ?? this.plotId,
    calculatedAt: calculatedAt ?? this.calculatedAt,
    totalBiomassKg: totalBiomassKg ?? this.totalBiomassKg,
    carbonStockTon: carbonStockTon ?? this.carbonStockTon,
    co2eTon: co2eTon ?? this.co2eTon,
    breakdown: breakdown ?? this.breakdown,
    status: status ?? this.status,
    approvedByOwnerAt: approvedByOwnerAt ?? this.approvedByOwnerAt,
    ownerRejectionReason: ownerRejectionReason ?? this.ownerRejectionReason,
    rejectedByOwnerAt: rejectedByOwnerAt ?? this.rejectedByOwnerAt,
    approvedByAdminAt: approvedByAdminAt ?? this.approvedByAdminAt,
    rejectedByAdminAt: rejectedByAdminAt ?? this.rejectedByAdminAt,
    adminRejectionReason: adminRejectionReason ?? this.adminRejectionReason,
  );
}
