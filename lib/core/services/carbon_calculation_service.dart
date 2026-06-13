import 'package:forest_carbon_platform/core/models/carbon_result_model.dart';
import 'package:forest_carbon_platform/core/models/plot_data_model.dart';

/// CarbonCalculationService — TV4
///
/// Công thức (README):
///   Biomass (kg) = 0.0509 × DBH² × Height × SpeciesFactor × Quantity
///   Carbon Stock (tC) = Biomass × 0.47 / 1000
///   CO₂e (tCO₂e) = CarbonStock × 3.67
///
/// Tất cả logic tính toán tập trung đây — KHÔNG để trong widget.
class CarbonCalculationService {
  CarbonCalculationService._();
  static final CarbonCalculationService instance = CarbonCalculationService._();

  // ── Single-tree calculation ─────────────────────────────────────────────────

  /// Tính Biomass (kg) cho một cây đơn lẻ.
  double calculateBiomass({
    required double dbhCm,
    required double heightM,
    required double speciesFactor,
    required int quantity,
  }) {
    _validateInputs(dbhCm, heightM);
    return 0.0509 * (dbhCm * dbhCm) * heightM * speciesFactor * quantity;
  }

  /// Tính Carbon Stock (tC) từ tổng Biomass (kg).
  double calculateCarbonStock(double totalBiomassKg) {
    return totalBiomassKg * 0.47 / 1000;
  }

  /// Tính CO₂e (tCO₂e) từ Carbon Stock (tC).
  double calculateCo2e(double carbonStockTon) {
    return carbonStockTon * 3.67;
  }

  // ── Plot-level calculation ──────────────────────────────────────────────────

  /// Tính carbon cho toàn bộ plot (danh sách cây).
  /// [speciesFactorMap] là map từ tên loài cây → hệ số (factor).
  /// Nếu một loài không có trong map, dùng defaultFactor (0.47).
  CarbonResultModel calculateForPlot({
    required String resultId,
    required String projectId,
    required String plotId,
    required List<TreeData> trees,
    required Map<String, double> speciesFactorMap,
    double defaultFactor = 0.47,
  }) {
    final breakdown = <CarbonBreakdownItem>[];

    for (final tree in trees) {
      _validateInputs(tree.dbh, tree.height);
      final factor = speciesFactorMap[tree.species] ?? defaultFactor;
      final biomassKg = calculateBiomass(
        dbhCm: tree.dbh,
        heightM: tree.height,
        speciesFactor: factor,
        quantity: tree.quantity,
      );
      final carbonTon = calculateCarbonStock(biomassKg);
      final co2eTon = calculateCo2e(carbonTon);

      breakdown.add(CarbonBreakdownItem(
        species: tree.species,
        dbh: tree.dbh,
        height: tree.height,
        quantity: tree.quantity,
        biomassFactor: factor,
        biomassKg: _round(biomassKg),
        carbonTon: _round(carbonTon),
        co2eTon: _round(co2eTon),
      ));
    }

    final totalBiomass = breakdown.fold(0.0, (s, b) => s + b.biomassKg);
    final totalCarbon = calculateCarbonStock(totalBiomass);
    final totalCo2e = calculateCo2e(totalCarbon);

    return CarbonResultModel(
      id: resultId,
      projectId: projectId,
      plotId: plotId,
      calculatedAt: DateTime.now(),
      totalBiomassKg: _round(totalBiomass),
      carbonStockTon: _round(totalCarbon),
      co2eTon: _round(totalCo2e),
      breakdown: breakdown,
    );
  }

  /// Tổng hợp kết quả từ nhiều plot thành một CarbonResultModel project-level.
  CarbonResultModel aggregatePlotResults({
    required String resultId,
    required String projectId,
    required List<CarbonResultModel> plotResults,
  }) {
    final allBreakdown = plotResults.expand((r) => r.breakdown).toList();
    final totalBiomass = plotResults.fold(0.0, (s, r) => s + r.totalBiomassKg);
    final totalCarbon = calculateCarbonStock(totalBiomass);
    final totalCo2e = calculateCo2e(totalCarbon);

    return CarbonResultModel(
      id: resultId,
      projectId: projectId,
      calculatedAt: DateTime.now(),
      totalBiomassKg: _round(totalBiomass),
      carbonStockTon: _round(totalCarbon),
      co2eTon: _round(totalCo2e),
      breakdown: allBreakdown,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _validateInputs(double dbh, double height) {
    if (dbh <= 0) throw ArgumentError('DBH phải lớn hơn 0, nhận được: $dbh');
    if (height <= 0) throw ArgumentError('Height phải lớn hơn 0, nhận được: $height');
  }

  double _round(double value, {int decimals = 4}) {
    final factor = _pow10(decimals);
    return (value * factor).roundToDouble() / factor;
  }

  double _pow10(int n) {
    double result = 1;
    for (int i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }
}
