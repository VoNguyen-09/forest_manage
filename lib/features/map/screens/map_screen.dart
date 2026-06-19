import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/utils/gis_utils.dart';
import 'package:forest_carbon_platform/core/services/forest_project_service.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/services/forest_owner_service.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/core/models/gps_point.dart';
import 'package:forest_carbon_platform/core/models/worker_location_model.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mảng màu phân biệt từng chủ rừng/dự án
const List<Color> _zoneColors = [
  Color(0xFF006241), // primary green
  Color(0xFF1565C0), // blue
  Color(0xFFF57C00), // orange
  Color(0xFF6A1B9A), // purple
  Color(0xFFAD1457), // pink
  Color(0xFF00695C), // teal
  Color(0xFF4E342E), // brown
];

Color _colorForOwner(String ownerId) {
  final hash = ownerId.hashCode.abs();
  return _zoneColors[hash % _zoneColors.length];
}

class MapScreen extends StatefulWidget {
  final bool isSelectingForForm;
  final List<GpsPoint>? initialPolygon;

  const MapScreen({
    super.key,
    this.isSelectingForForm = false,
    this.initialPolygon,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _isSatellite = false;
  bool _isDrawing = false;
  bool _isLegendVisible = false;
  List<LatLng> _polygonPoints = [];
  double _areaHa = 0.0;
  double _perimeterM = 0.0;
  double _currentZoom = 8.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialPolygon != null && widget.initialPolygon!.isNotEmpty) {
      _polygonPoints = widget.initialPolygon!
          .map((p) => LatLng(p.lat, p.lng))
          .toList();
      _areaHa = GisUtils.calculateAreaHa(_polygonPoints);
      _perimeterM = GisUtils.calculatePerimeter(_polygonPoints);
      if (_polygonPoints.isNotEmpty) {
        // Move to the polygon after map is initialized
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(_polygonPoints.first, 14.0);
        });
      }
    }
  }

  /// Dự án đang được chọn/highlight
  String? _selectedProjectId;

  // Tọa độ trung tâm mặc định (Đắk Lắk)
  final LatLng _center = const LatLng(12.6667, 108.0383);

  void _recalculate() {
    setState(() {
      _areaHa = GisUtils.calculateAreaHa(_polygonPoints);
      _perimeterM = GisUtils.calculatePerimeter(_polygonPoints);
    });
  }

  void _handleTap(TapPosition tapPosition, LatLng point) {
    if (_isDrawing) {
      setState(() {
        _polygonPoints.add(point);
        _recalculate();
      });
    }
  }

  void _setZoom(double zoom) {
    setState(() {
      _currentZoom = zoom.clamp(3.0, 18.0).toDouble();
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  Future<void> _uploadShapefile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['geojson', 'json', 'kml'],
    );
    if (result != null && result.files.single.path != null) {
      try {
        final file = File(result.files.single.path!);
        final points = await GisUtils.parseShapefile(file);
        setState(() {
          _polygonPoints = points;
          _recalculate();
          if (points.isNotEmpty) {
            _mapController.move(points.first, 14.0);
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã tải Shapefile thành công!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Lỗi: $e',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _savePolygonToProject() async {
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần vẽ ít nhất 3 điểm để tạo đa giác!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (widget.isSelectingForForm) {
      final gpsPoints = _polygonPoints
          .map((p) => GpsPoint(lat: p.latitude, lng: p.longitude))
          .toList();
      context.pop({
        'polygon': gpsPoints,
        'area': _areaHa,
        'perimeter': _perimeterM,
      });
      return;
    }

    ForestProjectModel? selectedProject;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Gán ranh giới vào Dự án',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: StreamBuilder<List<ForestProjectModel>>(
              stream: ForestProjectService.instance.getProjectsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final projects = snapshot.data ?? [];
                if (projects.isEmpty) {
                  return const Center(child: Text('Chưa có dự án nào.'));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final proj = projects[index];
                    final color = _colorForOwner(proj.ownerId);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.2),
                        child: Icon(Icons.park, color: color, size: 18),
                      ),
                      title: Text(
                        proj.projectName,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${proj.treeSpecies} · ${proj.province}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.secondary,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.secondary,
                      ),
                      onTap: () {
                        selectedProject = proj;
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppColors.secondary),
              ),
            ),
          ],
        );
      },
    );

    if (selectedProject != null) {
      try {
        final gpsPoints = _polygonPoints
            .map((p) => GpsPoint(lat: p.latitude, lng: p.longitude))
            .toList();
        final updatedProj = selectedProject!.copyWith(
          polygon: gpsPoints,
          totalAreaHa: _areaHa,
          perimeter: _perimeterM,
          updatedAt: DateTime.now(),
        );
        await ForestProjectService.instance.updateProject(updatedProj);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã gán ranh giới cho dự án ${selectedProject!.projectName}!',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi lưu: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: const Text(AppStrings.map),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // ── 1. BẢN ĐỒ CHÍNH ─────────────────────────────────────────────
          StreamBuilder<List<ForestOwnerModel>>(
            stream: ForestOwnerService.instance.getOwnersStream(),
            builder: (context, ownerSnapshot) {
              final owners = ownerSnapshot.data ?? [];
              final ownersWithPolygon = owners
                  .where((o) => o.polygon.length >= 3)
                  .toList();

              return StreamBuilder<List<ForestProjectModel>>(
                stream: ForestProjectService.instance.getProjectsStream(),
                builder: (context, snapshot) {
                  final projects = snapshot.data ?? [];

                  // Tách danh sách polygon có dữ liệu
                  final projectsWithPolygon = projects
                      .where((p) => p.polygon.length >= 3)
                      .toList();

                  return StreamBuilder<List<WorkerLocationModel>>(
                    stream: FirestoreService.instance.streamWorkerLocations(),
                    builder: (context, locationSnapshot) {
                      final workerLocations = (locationSnapshot.data ?? [])
                          .where((loc) => loc.isOnline)
                          .toList();

                      return FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _center,
                          initialZoom: _currentZoom,
                          maxZoom: 18.0,
                          minZoom: 3.0,
                          onTap: _handleTap,
                          onMapEvent: (event) {
                            if (event is MapEventMove) {
                              // sync zoom
                              setState(() {
                                _currentZoom = event.camera.zoom;
                              });
                            }
                          },
                        ),
                        children: [
                          // Tile layer
                          TileLayer(
                            urlTemplate: _isSatellite
                                ? 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'
                                : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.forestcarbon.app',
                          ),

                          // Vùng quản lý của chủ rừng (viền ngoài)
                          if (ownersWithPolygon.isNotEmpty)
                            PolygonLayer(
                              polygons: ownersWithPolygon.map((owner) {
                                final latLngs = owner.polygon
                                    .map((p) => LatLng(p.lat, p.lng))
                                    .toList();
                                final color = _colorForOwner(owner.id);
                                return Polygon(
                                  points: latLngs,
                                  color: color.withValues(alpha: 0.1),
                                  borderColor: color,
                                  borderStrokeWidth: 3.0,
                                );
                              }).toList(),
                            ),

                          // Vùng rừng từ Firestore — từng dự án có màu khác nhau theo chủ rừng
                          if (projectsWithPolygon.isNotEmpty)
                            PolygonLayer(
                              polygons: projectsWithPolygon.map((proj) {
                                final latLngs = proj.polygon
                                    .map((p) => LatLng(p.lat, p.lng))
                                    .toList();
                                final color = _colorForOwner(proj.ownerId);
                                final isSelected =
                                    proj.id == _selectedProjectId;
                                return Polygon(
                                  points: latLngs,
                                  color: color.withValues(
                                    alpha: isSelected ? 0.45 : 0.25,
                                  ),
                                  borderColor: color,
                                  borderStrokeWidth: isSelected ? 3 : 1.5,
                                );
                              }).toList(),
                            ),

                          // Marker label cho từng vùng rừng quản lý của Chủ Rừng
                          if (ownersWithPolygon.isNotEmpty)
                            MarkerLayer(
                              markers: ownersWithPolygon.map((owner) {
                                final lats = owner.polygon
                                    .map((p) => p.lat)
                                    .toList();
                                final lngs = owner.polygon
                                    .map((p) => p.lng)
                                    .toList();
                                final centerLat =
                                    lats.reduce((a, b) => a + b) / lats.length;
                                final centerLng =
                                    lngs.reduce((a, b) => a + b) / lngs.length;
                                final color = _colorForOwner(owner.id);

                                return Marker(
                                  point: LatLng(centerLat, centerLng),
                                  width: 150,
                                  height: 60,
                                  alignment: Alignment.topCenter,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: color,
                                        size: 28,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: color,
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          owner.ownerName,
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: color,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),

                          // Marker label cho từng vùng rừng (Dự án)
                          if (projectsWithPolygon.isNotEmpty)
                            MarkerLayer(
                              markers: projectsWithPolygon.map((proj) {
                                final lats = proj.polygon
                                    .map((p) => p.lat)
                                    .toList();
                                final lngs = proj.polygon
                                    .map((p) => p.lng)
                                    .toList();
                                final centerLat =
                                    lats.reduce((a, b) => a + b) / lats.length;
                                final centerLng =
                                    lngs.reduce((a, b) => a + b) / lngs.length;
                                final color = _colorForOwner(proj.ownerId);
                                return Marker(
                                  point: LatLng(centerLat, centerLng),
                                  width: 120,
                                  height: 36,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedProjectId =
                                          proj.id == _selectedProjectId
                                          ? null
                                          : proj.id,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.park,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              proj.projectName,
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                          // Polygon đang vẽ tay
                          if (_polygonPoints.isNotEmpty)
                            PolygonLayer(
                              polygons: [
                                Polygon(
                                  points: _polygonPoints,
                                  color: AppColors.tertiary.withValues(
                                    alpha: 0.3,
                                  ),
                                  borderColor: AppColors.tertiary,
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),

                          // Điểm của polygon đang vẽ
                          if (_polygonPoints.isNotEmpty)
                            MarkerLayer(
                              markers: _polygonPoints
                                  .map(
                                    (p) => Marker(
                                      point: p,
                                      width: 14,
                                      height: 14,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.tertiary,
                                            width: 2.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),

                          // Vị trí realtime của forest worker
                          if (workerLocations.isNotEmpty)
                            MarkerLayer(
                              markers: workerLocations.map((worker) {
                                return Marker(
                                  point: LatLng(worker.lat, worker.lng),
                                  width: 160,
                                  height: 64,
                                  alignment: Alignment.topCenter,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: AppColors.tertiary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.surface,
                                            width: 3,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person_pin_circle,
                                          color: AppColors.onPrimary,
                                          size: 22,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface.withValues(
                                            alpha: 0.94,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: AppColors.tertiary,
                                          ),
                                        ),
                                        child: Text(
                                          worker.workerName,
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),

                          // Marker trung tâm
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _center,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_on,
                                  color: AppColors.error,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),

          // ── 2. LEFT MAP TOOLS (Diện tích | thao tác | chú giải) ────────
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: _MapToolRail(
              areaHa: _areaHa,
              perimeterM: _perimeterM,
              isDrawing: _isDrawing,
              isLegendVisible: _isLegendVisible,
              isSelectingForForm: widget.isSelectingForForm,
              onToggleDraw: () => setState(() => _isDrawing = !_isDrawing),
              onUploadShapefile: _uploadShapefile,
              onClear: () => setState(() {
                _polygonPoints.clear();
                _recalculate();
              }),
              onSave: _savePolygonToProject,
              onToggleLegend: _showLegend,
            ),
          ),

          // ── 3. ZOOM SLIDER (bên phải) ───────────────────────────────────
          Positioned(
            right: AppSpacing.sm,
            top: MediaQuery.of(context).size.height * 0.28,
            child: _ZoomSlider(zoom: _currentZoom, onChanged: _setZoom),
          ),

          // ── 4. FAB góc dưới phải (Lớp bản đồ | My Location) ─────────────
          Positioned(
            bottom: 24,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapFab(
                  heroTag: 'layerToggle',
                  icon: Icons.layers_outlined,
                  tooltip: _isSatellite ? 'Bản đồ thường' : 'Vệ tinh',
                  bgColor: AppColors.surface,
                  fgColor: AppColors.primary,
                  onPressed: () => setState(() => _isSatellite = !_isSatellite),
                ),
                const SizedBox(height: 10),
                _MapFab(
                  heroTag: 'myLocation',
                  icon: Icons.my_location,
                  tooltip: 'Về trung tâm',
                  bgColor: AppColors.primary,
                  fgColor: AppColors.onPrimary,
                  onPressed: () => _mapController.move(_center, 8.0),
                ),
              ],
            ),
          ),

          // ── 5. DRAWING MODE badge ─────────────────────────────────────────
          if (_isDrawing)
            Positioned(
              bottom: 24,
              left: 126,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tertiary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.draw, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Đang vẽ vùng rừng...',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── 6. LEGEND PANEL (Vùng dự án) ────────────────────────────────
          if (_isLegendVisible)
            Positioned(
              top: AppSpacing.lg,
              right: 80,
              bottom: AppSpacing.lg,
              child: _LegendPanel(
                onClose: () => setState(() => _isLegendVisible = false),
                onFocusOwner: (owner) {
                  final lats = owner.polygon.map((p) => p.lat).toList();
                  final lngs = owner.polygon.map((p) => p.lng).toList();
                  final centerLat = lats.reduce((a, b) => a + b) / lats.length;
                  final centerLng = lngs.reduce((a, b) => a + b) / lngs.length;
                  _mapController.move(LatLng(centerLat, centerLng), 14.0);
                },
              ),
            ),

          // ── 7. PROJECT INFO POPUP khi chọn vùng rừng ─────────────────────
          if (_selectedProjectId != null)
            Positioned(
              bottom: 24,
              left: 126,
              right: 70,
              child: _ProjectInfoCard(
                projectId: _selectedProjectId!,
                onClose: () => setState(() => _selectedProjectId = null),
              ),
            ),
        ],
      ),
    );
  }

  void _showLegend() {
    setState(() => _isLegendVisible = !_isLegendVisible);
  }
}

// ────────────────────────────────────────────────────────────────────────────
// WIDGET: Left map tool rail
// ────────────────────────────────────────────────────────────────────────────
class _MapToolRail extends StatelessWidget {
  final double areaHa;
  final double perimeterM;
  final bool isDrawing;
  final bool isLegendVisible;
  final bool isSelectingForForm;
  final VoidCallback onToggleDraw;
  final VoidCallback onUploadShapefile;
  final VoidCallback onClear;
  final VoidCallback onSave;
  final VoidCallback onToggleLegend;

  const _MapToolRail({
    required this.areaHa,
    required this.perimeterM,
    required this.isDrawing,
    required this.isLegendVisible,
    this.isSelectingForForm = false,
    required this.onToggleDraw,
    required this.onUploadShapefile,
    required this.onClear,
    required this.onSave,
    required this.onToggleLegend,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RailMetricBox(
                icon: Icons.square_foot,
                label: 'Diện tích',
                value: '${areaHa.toStringAsFixed(2)} ha',
              ),
              const SizedBox(height: AppSpacing.xs),
              _RailMetricBox(
                icon: Icons.rounded_corner,
                label: 'Chu vi',
                value: '${perimeterM.toStringAsFixed(0)} m',
              ),
              const SizedBox(height: AppSpacing.sm),
              const _RailDivider(),
              _RailActionButton(
                icon: isDrawing
                    ? Icons.stop_circle_outlined
                    : Icons.draw_outlined,
                label: isDrawing ? 'Dừng vẽ' : 'Vẽ tay',
                color: isDrawing ? AppColors.error : AppColors.primary,
                isActive: isDrawing,
                onTap: onToggleDraw,
              ),
              _RailActionButton(
                icon: Icons.upload_file_outlined,
                label: 'Shapefile',
                color: AppColors.info,
                onTap: onUploadShapefile,
              ),
              _RailActionButton(
                icon: Icons.delete_outline,
                label: 'Xóa',
                color: AppColors.error,
                onTap: onClear,
              ),
              _RailActionButton(
                icon: isSelectingForForm
                    ? Icons.check_circle_outline
                    : Icons.save_outlined,
                label: isSelectingForForm ? 'Xong' : 'Lưu vào Dự án',
                color: AppColors.tertiary,
                onTap: onSave,
              ),
              const _RailDivider(),
              _RailActionButton(
                icon: Icons.legend_toggle,
                label: 'Chú giải',
                color: AppColors.primary,
                isActive: isLegendVisible,
                onTap: onToggleLegend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailMetricBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RailMetricBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.neutral,
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.tertiary),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _RailActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive
        ? color.withValues(alpha: 0.12)
        : Colors.transparent;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pill,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppRadius.pill,
            border: isActive
                ? Border.all(color: color.withValues(alpha: 0.35))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailDivider extends StatelessWidget {
  const _RailDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: AppColors.primary.withValues(alpha: 0.1),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// WIDGET: Zoom slider
// ────────────────────────────────────────────────────────────────────────────
class _ZoomSlider extends StatelessWidget {
  final double zoom;
  final ValueChanged<double> onChanged;

  const _ZoomSlider({required this.zoom, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sliderValue = zoom.clamp(3.0, 18.0).toDouble();

    return Tooltip(
      message: 'Thu phóng bản đồ',
      child: Container(
        width: 48,
        height: 190,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.add, size: 17, color: AppColors.primary),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: AppColors.tertiary,
                    inactiveTrackColor: AppColors.primary.withValues(
                      alpha: 0.16,
                    ),
                    thumbColor: AppColors.tertiary,
                    overlayColor: AppColors.tertiary.withValues(alpha: 0.12),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                  ),
                  child: Slider(
                    min: 3,
                    max: 18,
                    divisions: 15,
                    value: sliderValue,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ),
            const Icon(Icons.remove, size: 17, color: AppColors.primary),
            Text(
              sliderValue.toStringAsFixed(0),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// WIDGET: FAB button
// ────────────────────────────────────────────────────────────────────────────
class _MapFab extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final String tooltip;
  final Color bgColor;
  final Color fgColor;
  final VoidCallback onPressed;

  const _MapFab({
    required this.heroTag,
    required this.icon,
    required this.tooltip,
    required this.bgColor,
    required this.fgColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      mini: true,
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      tooltip: tooltip,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: onPressed,
      child: Icon(icon, size: 20),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// WIDGET: Legend panel
// ────────────────────────────────────────────────────────────────────────────
class _LegendPanel extends StatelessWidget {
  final VoidCallback onClose;
  final ValueChanged<ForestOwnerModel> onFocusOwner;

  const _LegendPanel({required this.onClose, required this.onFocusOwner});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = (screenWidth - 206).clamp(280.0, 420.0).toDouble();

    return SizedBox(
      width: panelWidth,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: StreamBuilder<List<ForestOwnerModel>>(
          stream: ForestOwnerService.instance.getOwnersStream(),
          builder: (context, ownerSnap) {
            return StreamBuilder<List<ForestProjectModel>>(
              stream: ForestProjectService.instance.getProjectsStream(),
              builder: (context, projectSnap) {
                final owners = ownerSnap.data ?? [];
                final allProjects = projectSnap.data ?? [];
                final withPolygon = owners
                    .where((o) => o.polygon.length >= 3)
                    .toList();
                final totalArea = withPolygon.fold(
                  0.0,
                  (sum, o) => sum + o.totalAreaHa,
                );
                final totalProjects = allProjects.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Vùng dự án',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Đóng chú giải',
                          child: InkWell(
                            onTap: onClose,
                            borderRadius: AppRadius.pill,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: AppRadius.card,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _LegendStat(
                              icon: Icons.people_outline,
                              label: 'Chủ rừng',
                              value: '${withPolygon.length}',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: AppColors.primary.withValues(alpha: 0.15),
                          ),
                          Expanded(
                            child: _LegendStat(
                              icon: Icons.forest_outlined,
                              label: 'Dự án',
                              value: '$totalProjects',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: AppColors.primary.withValues(alpha: 0.15),
                          ),
                          Expanded(
                            child: _LegendStat(
                              icon: Icons.landscape_outlined,
                              label: 'Diện tích',
                              value: '${totalArea.toStringAsFixed(1)} ha',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Divider(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      height: 1,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (ownerSnap.connectionState == ConnectionState.waiting)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (withPolygon.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          child: Text(
                            'Chưa có vùng rừng nào được vẽ trên bản đồ.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: withPolygon.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: AppColors.primary.withValues(alpha: 0.08),
                          ),
                          itemBuilder: (context, index) {
                            final owner = withPolygon[index];
                            final color = _colorForOwner(owner.id);
                            final projectCount = allProjects
                                .where((p) => p.ownerId == owner.id)
                                .length;

                            return InkWell(
                              onTap: () => onFocusOwner(owner),
                              borderRadius: AppRadius.card,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: color,
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            owner.ownerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 3,
                                            children: [
                                              _LegendMeta(
                                                icon: Icons.landscape,
                                                text:
                                                    '${owner.totalAreaHa.toStringAsFixed(1)} ha',
                                                color: color,
                                              ),
                                              _LegendMeta(
                                                icon: Icons.forest,
                                                text: '$projectCount dự án',
                                                color: color,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right,
                                      color: AppColors.secondary,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LegendMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _LegendMeta({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: AppColors.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// WIDGET: Project Info Card (popup khi click vùng rừng)
// ────────────────────────────────────────────────────────────────────────────
class _ProjectInfoCard extends StatelessWidget {
  final String projectId;
  final VoidCallback onClose;

  const _ProjectInfoCard({required this.projectId, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ForestProjectModel>>(
      stream: ForestProjectService.instance.getProjectsStream(),
      builder: (context, snapshot) {
        final proj = snapshot.data?.where((p) => p.id == projectId).firstOrNull;
        if (proj == null) return const SizedBox.shrink();
        final color = _colorForOwner(proj.ownerId);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Icon(Icons.park, color: color, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      proj.projectName,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _InfoRow(icon: Icons.map_outlined, text: proj.province),
                  _InfoRow(icon: Icons.park_outlined, text: proj.treeSpecies),
                  _InfoRow(
                    icon: Icons.square_foot,
                    text: '${proj.totalAreaHa.toStringAsFixed(1)} ha',
                  ),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: 'Trồng ${proj.yearPlanted}',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.secondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// WIDGET: Legend Stat (dùng trong bảng tổng quan Vùng dự án)
// ────────────────────────────────────────────────────────────────────────────
class _LegendStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LegendStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.secondary),
        ),
      ],
    );
  }
}
