import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:latlong2/latlong.dart';

class GisUtils {
  static const double earthRadiusMeters = 6378137.0; // WGS84

  /// Calculate Haversine distance in meters between two points
  static double calculateDistance(LatLng p1, LatLng p2) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, p1, p2);
  }

  /// Calculate Perimeter in meters
  static double calculatePerimeter(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    double perimeter = 0.0;
    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      perimeter += calculateDistance(p1, p2);
    }
    return perimeter;
  }

  /// Calculate Area using Shoelace formula (Gauss)
  /// Covert LatLng to meters using Equirectangular projection around the mean latitude
  static double calculateAreaHa(List<LatLng> points) {
    if (points.length < 3) return 0.0;

    // Calculate mean latitude
    double sumLat = 0.0;
    for (var p in points) {
      sumLat += p.latitude;
    }
    double meanLat = sumLat / points.length;
    double meanLatRad = meanLat * pi / 180.0;

    // Convert all points to approximate x, y in meters
    List<Point<double>> projected = [];
    for (var p in points) {
      double x = earthRadiusMeters * (p.longitude * pi / 180.0) * cos(meanLatRad);
      double y = earthRadiusMeters * (p.latitude * pi / 180.0);
      projected.add(Point(x, y));
    }

    // Shoelace algorithm
    double area = 0.0;
    for (int i = 0; i < projected.length; i++) {
      final p1 = projected[i];
      final p2 = projected[(i + 1) % projected.length];
      area += (p1.x * p2.y) - (p2.x * p1.y);
    }

    area = (area.abs() / 2.0); // Area in square meters

    // Convert sq meters to Hectares (1 ha = 10,000 m2)
    return area / 10000.0;
  }

  /// Parse GeoJSON or KML file and extract the first Polygon
  static Future<List<LatLng>> parseShapefile(File file) async {
    final String content = await file.readAsString();
    final String ext = file.path.split('.').last.toLowerCase();

    if (ext == 'geojson' || ext == 'json') {
      return _parseGeoJson(content);
    } else if (ext == 'kml') {
      return _parseKml(content);
    } else {
      throw Exception('Định dạng file không hỗ trợ (.geojson, .kml)');
    }
  }

  static List<LatLng> _parseGeoJson(String content) {
    try {
      final decoded = jsonDecode(content);
      // Try to find a Polygon feature
      if (decoded['type'] == 'FeatureCollection') {
        final features = decoded['features'] as List;
        for (var feature in features) {
          final geom = feature['geometry'];
          if (geom != null && geom['type'] == 'Polygon') {
            return _extractPolygonCoordinates(geom['coordinates']);
          }
        }
      } else if (decoded['type'] == 'Feature') {
        final geom = decoded['geometry'];
        if (geom != null && geom['type'] == 'Polygon') {
          return _extractPolygonCoordinates(geom['coordinates']);
        }
      } else if (decoded['type'] == 'Polygon') {
        return _extractPolygonCoordinates(decoded['coordinates']);
      }
      throw Exception('Không tìm thấy Polygon trong file GeoJSON');
    } catch (e) {
      throw Exception('Lỗi đọc GeoJSON: $e');
    }
  }

  static List<LatLng> _extractPolygonCoordinates(List<dynamic> coords) {
    // GeoJSON Polygon coordinates is an array of linear rings (first is exterior)
    final exteriorRing = coords[0] as List;
    List<LatLng> points = [];
    for (var point in exteriorRing) {
      // GeoJSON is [longitude, latitude]
      double lng = (point[0] as num).toDouble();
      double lat = (point[1] as num).toDouble();
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  static List<LatLng> _parseKml(String content) {
    try {
      final regExp = RegExp(r'<coordinates>\s*(.*?)\s*</coordinates>', dotAll: true);
      final match = regExp.firstMatch(content);
      if (match != null) {
        final coordString = match.group(1);
        if (coordString != null) {
          List<LatLng> points = [];
          final tuples = coordString.trim().split(RegExp(r'\s+'));
          for (var tuple in tuples) {
            final parts = tuple.split(',');
            if (parts.length >= 2) {
              double lng = double.parse(parts[0]);
              double lat = double.parse(parts[1]);
              points.add(LatLng(lat, lng));
            }
          }
          return points;
        }
      }
      throw Exception('Không tìm thấy thẻ <coordinates> trong KML');
    } catch (e) {
      throw Exception('Lỗi đọc KML: $e');
    }
  }
}
