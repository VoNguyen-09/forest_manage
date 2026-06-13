import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/carbon_result_model.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:intl/intl.dart';

/// Widget hiển thị kết quả tính toán carbon:
/// - Tổng Biomass, Carbon Stock, CO₂e
/// - Bảng breakdown theo loài
class CarbonResultCard extends StatelessWidget {
  final CarbonResultModel result;

  const CarbonResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryRow(result: result),
        const SizedBox(height: AppSpacing.md),
        if (result.breakdown.isNotEmpty) _BreakdownTable(breakdown: result.breakdown),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final CarbonResultModel result;
  const _SummaryRow({required this.result});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: AppStrings.biomass,
            value: _fmt(result.totalBiomassKg),
            unit: 'kg',
            icon: Icons.grass_outlined,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MetricCard(
            label: AppStrings.carbonStock,
            value: _fmt(result.carbonStockTon),
            unit: 'tC',
            icon: Icons.co2_outlined,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MetricCard(
            label: AppStrings.co2Equivalent,
            value: _fmt(result.co2eTon),
            unit: 'tCO₂e',
            icon: Icons.cloud_outlined,
            color: AppColors.tertiary,
          ),
        ),
      ],
    );
  }

  String _fmt(double v) => NumberFormat('#,##0.####').format(v);
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
          Text(unit, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _BreakdownTable extends StatelessWidget {
  final List<CarbonBreakdownItem> breakdown;
  const _BreakdownTable({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chi tiết theo loài cây',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              headingRowColor: WidgetStateProperty.all(AppColors.neutral),
              columns: const [
                DataColumn(label: Text('Loài')),
                DataColumn(label: Text('DBH (cm)'), numeric: true),
                DataColumn(label: Text('H (m)'), numeric: true),
                DataColumn(label: Text('SL'), numeric: true),
                DataColumn(label: Text('Biomass (kg)'), numeric: true),
                DataColumn(label: Text('Carbon (tC)'), numeric: true),
                DataColumn(label: Text('CO₂e (tCO₂e)'), numeric: true),
              ],
              rows: breakdown.map((b) => DataRow(cells: [
                    DataCell(Text(b.species)),
                    DataCell(Text(b.dbh.toString())),
                    DataCell(Text(b.height.toString())),
                    DataCell(Text(b.quantity.toString())),
                    DataCell(Text(_fmt(b.biomassKg))),
                    DataCell(Text(_fmt(b.carbonTon))),
                    DataCell(Text(_fmt(b.co2eTon))),
                  ])).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => NumberFormat('#,##0.####').format(v);
}
