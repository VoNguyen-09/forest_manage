import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/utils/gis_utils.dart';
import 'package:forest_carbon_platform/core/services/forest_project_service.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _isSatellite = false;
  bool _isDrawing = false;
  List<LatLng> _polygonPoints = [];
  double _areaHa = 0.0;
  double _perimeterM = 0.0;

  // Tọa độ trung tâm mặc định (VD: Đắk Lắk)
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
          // Move map to the first point of the polygon
          if (points.isNotEmpty) {
            _mapController.move(points.first, 14.0);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tải Shapefile thành công!')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e', style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _savePolygonToProject() async {
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cần vẽ ít nhất 3 điểm để tạo đa giác!'), backgroundColor: AppColors.error));
      return;
    }
    
    // Show dialog to pick a project
    ForestProjectModel? selectedProject;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Gán ranh giới vào Dự án'),
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
                    return ListTile(
                      title: Text(proj.projectName),
                      subtitle: Text('${proj.treeSpecies} - ${proj.province}'),
                      trailing: const Icon(Icons.check_circle_outline),
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
              child: const Text('Hủy', style: TextStyle(color: AppColors.secondary)),
            ),
          ],
        );
      }
    );

    if (selectedProject != null) {
      try {
        final gpsPoints = _polygonPoints.map((p) => GpsPoint(lat: p.latitude, lng: p.longitude)).toList();
        final updatedProj = selectedProject!.copyWith(
          polygon: gpsPoints,
          totalAreaHa: _areaHa,
          perimeter: _perimeterM,
          updatedAt: DateTime.now(),
        );
        await ForestProjectService.instance.updateProject(updatedProj);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã gán ranh giới cho dự án ${selectedProject!.projectName}!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi lưu: $e'), backgroundColor: AppColors.error));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.map),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Mở bộ lọc dự án/bản đồ
            },
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 8.0,
              maxZoom: 18.0,
              onTap: _handleTap,
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite 
                    ? 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.forestcarbon.app',
              ),
              if (_polygonPoints.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _polygonPoints,
                      color: AppColors.primary.withOpacity(0.3),
                      borderColor: AppColors.primary,
                      borderStrokeWidth: 2,
                      isFilled: true,
                    ),
                  ],
                ),
              if (_polygonPoints.isNotEmpty)
                MarkerLayer(
                  markers: _polygonPoints.map((p) => Marker(
                    point: p,
                    width: 12,
                    height: 12,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(BorderSide(color: AppColors.primary, width: 2)),
                      ),
                    ),
                  )).toList(),
                ),
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
          ),
          // GIS Floating Control Panel
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Diện tích: ${_areaHa.toStringAsFixed(2)} ha', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Chu vi: ${_perimeterM.toStringAsFixed(0)} m', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            icon: Icon(_isDrawing ? Icons.stop : Icons.draw),
                            label: Text(_isDrawing ? 'Dừng vẽ' : 'Vẽ tay'),
                            onPressed: () {
                              setState(() {
                                _isDrawing = !_isDrawing;
                              });
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Shapefile'),
                            onPressed: _uploadShapefile,
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.clear, color: AppColors.error),
                            label: const Text('Xóa', style: TextStyle(color: AppColors.error)),
                            onPressed: () {
                              setState(() {
                                _polygonPoints.clear();
                                _recalculate();
                              });
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.save, color: AppColors.primary),
                            label: const Text('Lưu vào Dự án'),
                            onPressed: _savePolygonToProject,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'layerToggle',
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                  onPressed: () {
                    setState(() {
                      _isSatellite = !_isSatellite;
                    });
                  },
                  child: const Icon(Icons.layers),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'myLocation',
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  onPressed: () {
                    _mapController.move(_center, 8.0);
                  },
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
