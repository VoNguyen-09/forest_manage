import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/carbon_result_model.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/models/plot_data_model.dart';
import 'package:forest_carbon_platform/core/services/carbon_calculation_service.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/shared/widgets/app_card.dart';
import 'package:forest_carbon_platform/shared/widgets/empty_state.dart';
import 'package:forest_carbon_platform/shared/widgets/loading_overlay.dart';
import 'package:forest_carbon_platform/features/carbon/widgets/carbon_result_card.dart';

class CarbonCalculationScreen extends StatefulWidget {
  const CarbonCalculationScreen({super.key});

  @override
  State<CarbonCalculationScreen> createState() => _CarbonCalculationScreenState();
}

class _CarbonCalculationScreenState extends State<CarbonCalculationScreen> {
  final _db = FirestoreService.instance;
  final _carbonSvc = CarbonCalculationService.instance;

  List<ForestProjectModel> _projects = [];
  List<PlotDataModel> _plots = [];
  List<SpeciesFactor> _factors = [];

  ForestProjectModel? _selectedProject;
  PlotDataModel? _selectedPlot;
  CarbonResultModel? _result;

  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      final projects = await _db.listForestProjects();
      final factors = await _db.listSpeciesFactors();
      setState(() {
        _projects = projects;
        _factors = factors;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = AppStrings.errorGeneral;
        _loading = false;
      });
    }
  }

  Future<void> _onProjectChanged(ForestProjectModel? project) async {
    setState(() {
      _selectedProject = project;
      _selectedPlot = null;
      _plots = [];
      _result = null;
    });
    if (project == null) return;

    setState(() => _loading = true);
    try {
      final plots = await _db.listPlots(projectId: project.id);
      setState(() {
        _plots = plots;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = AppStrings.errorGeneral;
        _loading = false;
      });
    }
  }

  void _calculate() {
    final plot = _selectedPlot;
    final project = _selectedProject;
    if (plot == null || project == null) return;
    if (plot.trees.isEmpty) {
      setState(() => _error = 'Plot chưa có dữ liệu cây. Vui lòng nhập từ module Điều tra rừng.');
      return;
    }

    setState(() => _error = null);
    try {
      final factorMap = {for (final f in _factors) f.speciesName: f.factor};
      final result = _carbonSvc.calculateForPlot(
        resultId: '',
        projectId: project.id,
        plotId: plot.id,
        trees: plot.trees,
        speciesFactorMap: factorMap,
      );
      setState(() => _result = result);
    } on ArgumentError catch (e) {
      setState(() => _error = e.message.toString());
    }
  }

  Future<void> _saveResult() async {
    final result = _result;
    if (result == null) return;
    setState(() => _saving = true);
    try {
      await _db.saveCarbonResult(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã lưu kết quả carbon'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.errorGeneral),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.carbon),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSelectionCard(),
              const SizedBox(height: AppSpacing.md),
              if (_error != null) _buildError(),
              if (_result != null) ...[
                CarbonResultCard(result: _result!),
                const SizedBox(height: AppSpacing.md),
                _buildSaveButton(),
              ],
              if (_result == null && _selectedPlot != null && !_loading)
                _buildCalculateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chọn dự án & ô mẫu',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<ForestProjectModel>(
            value: _selectedProject,
            decoration: const InputDecoration(labelText: 'Dự án rừng'),
            items: _projects
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.projectName, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: _onProjectChanged,
          ),
          if (_plots.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<PlotDataModel>(
              value: _selectedPlot,
              decoration: const InputDecoration(labelText: 'Ô mẫu (plot)'),
              items: _plots
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text('${p.plotCode} — ${p.trees.length} loài cây'),
                      ))
                  .toList(),
              onChanged: (val) => setState(() {
                _selectedPlot = val;
                _result = null;
              }),
            ),
          ],
          if (_selectedProject != null && _plots.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: AppEmptyState(
                title: 'Dự án chưa có ô mẫu',
                subtitle: 'Thêm ô mẫu từ module Điều tra rừng',
                icon: Icons.nature_outlined,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalculateButton() {
    return FilledButton.icon(
      onPressed: _selectedPlot != null ? _calculate : null,
      icon: const Icon(Icons.calculate_outlined),
      label: Text(AppStrings.calculate),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.tertiary,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildSaveButton() {
    return OutlinedButton.icon(
      onPressed: _saving ? null : _saveResult,
      icon: _saving
          ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined),
      label: Text(AppStrings.save),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
