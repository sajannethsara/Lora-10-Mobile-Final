// import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:path_provider/path_provider.dart';

class MapService {
  // Public getters for offline map usage
  String? get currentAreaKey => _currentAreaKey;
  mapbox.TileStore? get tileStore => _tileStore;
  static final MapService _instance = MapService._internal();
  factory MapService() => _instance;
  MapService._internal();

  mapbox.TileStore? _tileStore;
  mapbox.OfflineManager? _offlineManager;
  String? _currentAreaKey;

  // Predefined hiking areas (adapted from your original code)
  final Map<String, Map<String, dynamic>> _hikingAreas = {
    'colombo': {
      'name': 'Colombo',
      'center': mapbox.Point(coordinates: mapbox.Position(79.8612, 6.9271)),
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [79.80, 6.85],
            [79.92, 6.85],
            [79.92, 7.00],
            [79.80, 7.00],
            [79.80, 6.85]
          ]
        ]
      },
    },
    'sinhartop': {
      'name': 'Sinharaja Forest',
      'center': mapbox.Point(coordinates: mapbox.Position(80.5000, 6.4167)),
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [80.45, 6.38],
            [80.55, 6.38],
            [80.55, 6.45],
            [80.45, 6.45],
            [80.45, 6.38]
          ]
        ]
      },
    },
  };

  // Initialize Mapbox and TileStore
  Future<void> init() async {
    try {
      await dotenv.load(fileName: ".env");
      final accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Mapbox access token is missing or invalid in .env file');
      }
      mapbox.MapboxOptions.setAccessToken(accessToken);
      _offlineManager = await mapbox.OfflineManager.create();
      final directory = await getApplicationDocumentsDirectory();
      _tileStore = await mapbox.TileStore.createAt(Uri.file('${directory.path}/mapbox_tiles'));
      print('MapService initialized');
    } catch (e) {
      print('MapService init error: $e');
      throw e;
    }
  }

  // Get list of available hiking areas
  List<Map<String, dynamic>> getHikingAreas() {
    return _hikingAreas.entries.map((e) => {'key': e.key, ...e.value}).toList();
  }

  // Download map tiles for an area
  Future<bool> downloadMapArea(String areaKey) async {
    if (!_hikingAreas.containsKey(areaKey)) return false;

    final area = _hikingAreas[areaKey]!;
    final tileRegionId = '$areaKey-tile-region';

    try {
      final tileRegionLoadOptions = mapbox.TileRegionLoadOptions(
        geometry: area['geometry'],
        descriptorsOptions: [
          mapbox.TilesetDescriptorOptions(
            styleURI: mapbox.MapboxStyles.LIGHT,
            minZoom: 4,
            maxZoom: 10,
          ),
        ],
        acceptExpired: true,
        networkRestriction: mapbox.NetworkRestriction.NONE,
      );

      final stylePackLoadOptions = mapbox.StylePackLoadOptions(
        glyphsRasterizationMode: mapbox.GlyphsRasterizationMode.IDEOGRAPHS_RASTERIZED_LOCALLY,
        metadata: {"tag": areaKey},
        acceptExpired: false,
      );

      await _offlineManager?.loadStylePack(
        mapbox.MapboxStyles.LIGHT,
        stylePackLoadOptions,
        (progress) {
          print('Style pack progress: ${progress.completedResourceCount}/${progress.requiredResourceCount}');
        },
      );

      await _tileStore?.loadTileRegion(
        tileRegionId,
        tileRegionLoadOptions,
        (progress) {
          print('Tile region progress: ${progress.completedResourceCount}/${progress.requiredResourceCount}');
        },
      );

      print('Map for ${area['name']} downloaded successfully');
      return true;
    } catch (e) {
      print('Map download error: $e');
      return false;
    }
  }

  // Check if map is downloaded
  Future<bool> isMapDownloaded(String areaKey) async {
    if (_tileStore == null) return false;
    try {
      final regions = await _tileStore?.allTileRegions();
      return regions?.any((region) => region.id == '$areaKey-tile-region') ?? false;
    } catch (e) {
      print('Check map downloaded error: $e');
      return false;
    }
  }

  // Set current map area
  void setCurrentArea(String areaKey) {
    _currentAreaKey = areaKey;
  }

  // Get current map center
  mapbox.Point? getCurrentMapCenter() {
    if (_currentAreaKey != null && _hikingAreas.containsKey(_currentAreaKey)) {
      print('Current area: $_currentAreaKey, Center: ${_hikingAreas[_currentAreaKey]!['center']}');
      return _hikingAreas[_currentAreaKey]!['center'] as mapbox.Point;
    }
    return null;
  }
}