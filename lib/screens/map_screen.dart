import '../services/map_service.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  mapbox.MapboxMap? _mapController;
  mapbox.CircleAnnotationManager? _circleAnnotationManager;
  mapbox.CircleAnnotation? _locationAnnotation;
  mapbox.PolylineAnnotationManager? _polylineAnnotationManager;
  mapbox.PolylineAnnotation? _pathAnnotation;
  List<mapbox.Point> _pathPoints = [];

  @override
  void initState() {
    super.initState();
    // Initialize path points from GPS bucket
    _updatePathFromProvider();
  }

  // Parse and update path from gpsBucket
  void _updatePathFromProvider() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    _pathPoints = provider.gpsBucket.map((coord) {
      try {
        final parts = coord.split(',');
        if (parts.length != 2) return null;
        final lat = double.tryParse(parts[0]);
        final lng = double.tryParse(parts[1]);
        if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
          return null;
        }
        return mapbox.Point(coordinates: mapbox.Position(lng, lat));
      } catch (e) {
        print('Invalid GPS data: $e');
        return null;
      }
    }).where((point) => point != null).cast<mapbox.Point>().toList();
  }

  // Update map annotations (marker and path)
  Future<void> _updateAnnotations() async {
    if (_mapController == null || _pathPoints.isEmpty) return;

    // Update marker for latest position
    final latestPoint = _pathPoints.last;
    if (_circleAnnotationManager != null && _locationAnnotation == null) {
      _locationAnnotation = await _circleAnnotationManager?.create(
        mapbox.CircleAnnotationOptions(
          geometry: latestPoint,
          circleColor: 0xFF0000FF, // Blue
          circleRadius: 12.0,
          circleStrokeColor: 0xFFFFFFFF, // White
          circleStrokeWidth: 2.0,
        ),
      );
    } else if (_circleAnnotationManager != null && _locationAnnotation != null) {
      _locationAnnotation?.geometry = latestPoint;
      await _circleAnnotationManager?.update(_locationAnnotation!);
    }

    // Update path
    if (_polylineAnnotationManager != null && _pathAnnotation == null) {
      _pathAnnotation = await _polylineAnnotationManager?.create(
        mapbox.PolylineAnnotationOptions(
          geometry: mapbox.LineString(coordinates: _pathPoints.map((p) => p.coordinates).toList()),
          lineColor: 0xFF0000FF, // Blue
          lineWidth: 4.0,
        ),
      );
    } else if (_polylineAnnotationManager != null && _pathAnnotation != null) {
      _pathAnnotation?.geometry = mapbox.LineString(coordinates: _pathPoints.map((p) => p.coordinates).toList());
      await _polylineAnnotationManager?.update(_pathAnnotation!);
    }
  }

  // Smoothly update camera to follow latest position
  Future<void> _smoothUpdateCamera(mapbox.Point point) async {
    if (_mapController == null) return;
    final currentCamera = await _mapController!.getCameraState();
    await _mapController!.easeTo(
      mapbox.CameraOptions(
        center: point,
        zoom: currentCamera.zoom,
        bearing: currentCamera.bearing,
        pitch: currentCamera.pitch,
      ),
      mapbox.MapAnimationOptions(duration: 500),
    );
  }

@override
Widget build(BuildContext context) {
  return Consumer2<AppProvider, MapService>(
    builder: (context, provider, mapService, child) {
      // Update path points from provider
      _updatePathFromProvider();

      // Only update annotations and camera if map is initialized and path is not empty
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_mapController != null && _pathPoints.isNotEmpty) {
          await _updateAnnotations();
          await _smoothUpdateCamera(_pathPoints.last);
        }
      });

  final mapCenter = mapService.getCurrentMapCenter();
  final currentAreaKey = mapService.currentAreaKey;
  print('MapScreen build: currentAreaKey=$currentAreaKey, mapCenter=${mapCenter?.coordinates}');

      return FutureBuilder<bool>(
        future: currentAreaKey != null
            ? mapService.isMapDownloaded(currentAreaKey)
            : Future.value(false),
        builder: (context, snapshot) {
          if (currentAreaKey == null || !(snapshot.data ?? false)) {
            print('MapScreen: No offline map selected or downloaded.');
            return Scaffold(
              body: Center(
                child: Text(
                  'No offline map selected or downloaded. Please select and download a map from Saved Maps.',
                ),
              ),
            );
          }
          print('MapScreen: Building MapWidget with center=${mapCenter?.coordinates}');
          return Scaffold(
            body: mapbox.MapWidget(
              key: const ValueKey('mapWidget'),
              styleUri: mapbox.MapboxStyles.LIGHT,
              cameraOptions: mapbox.CameraOptions(
                center: mapCenter!,
                zoom: 10.0,
              ),
              onMapCreated: (controller) async {
                print('MapScreen: MapWidget created');
                _mapController = controller;
                _circleAnnotationManager =
                    await controller.annotations.createCircleAnnotationManager();
                _polylineAnnotationManager =
                    await controller.annotations.createPolylineAnnotationManager();
                await _updateAnnotations();
              },
            ),
          );
        },
      );
    },
  );
}

  @override
  void dispose() {
    if (_locationAnnotation != null) {
      _circleAnnotationManager?.delete(_locationAnnotation!);
    }
    if (_pathAnnotation != null) {
      _polylineAnnotationManager?.delete(_pathAnnotation!);
    }
    _circleAnnotationManager?.deleteAll();
    _polylineAnnotationManager?.deleteAll();
    super.dispose();
  }
}