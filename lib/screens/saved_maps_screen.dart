import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/map_service.dart';

class SavedMapsScreen extends StatefulWidget {
  const SavedMapsScreen({super.key});

  @override
  State<SavedMapsScreen> createState() => _SavedMapsScreenState();
}

class _SavedMapsScreenState extends State<SavedMapsScreen> {
  List<Map<String, dynamic>> _hikingAreas = [];
  Map<String, bool> _downloadStatus = {};

  @override
  void initState() {
    super.initState();
    _loadHikingAreas();
  }

  // Load hiking areas and check download status
  Future<void> _loadHikingAreas() async {
    final mapService = Provider.of<MapService>(context, listen: false);
    final areas = mapService.getHikingAreas();
    setState(() {
      _hikingAreas = areas;
    });

    // Check download status for each area
    for (var area in areas) {
      final isDownloaded = await mapService.isMapDownloaded(area['key']);
      setState(() {
        _downloadStatus[area['key']] = isDownloaded;
      });
    }
  }

  // Handle map download
  Future<void> _downloadMap(String areaKey) async {
    final mapService = Provider.of<MapService>(context, listen: false);
    final success = await mapService.downloadMapArea(areaKey);
    if (success) {
      setState(() {
        _downloadStatus[areaKey] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Map for ${mapService.getHikingAreas().firstWhere((a) => a['key'] == areaKey)['name']} downloaded successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download map for $areaKey')),
      );
    }
  }

  // Select a map as current
  void _selectMap(String areaKey) {
    final mapService = Provider.of<MapService>(context, listen: false);
    mapService.setCurrentArea(areaKey);
    final selectedArea = mapService.getHikingAreas().firstWhere(
      (a) => a['key'] == areaKey,
      orElse: () => {},
    );
    debugPrint('Selected area: ${selectedArea['name'] ?? ''} (${selectedArea['key'] ?? ''})');
    setState(() {}); // Refresh UI to show selection
  }

  @override
  Widget build(BuildContext context) {
    final mapService = Provider.of<MapService>(context);
    final currentAreaKey = mapService.getCurrentMapCenter() != null
        ? _hikingAreas.firstWhere((a) => a['center'] == mapService.getCurrentMapCenter(), orElse: () => {'key': ''})['key']
        : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Maps'),
      ),
      body: _hikingAreas.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _hikingAreas.length,
              itemBuilder: (context, index) {
                final area = _hikingAreas[index];
                final areaKey = area['key'] as String;
                final isDownloaded = _downloadStatus[areaKey] ?? false;
                final isSelected = areaKey == currentAreaKey;

                return ListTile(
                  title: Text(area['name'] as String),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDownloaded)
                        const Icon(Icons.check_circle, color: Colors.green)
                      else
                        ElevatedButton(
                          onPressed: () => _downloadMap(areaKey),
                          child: const Text('Download'),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isDownloaded ? () => _selectMap(areaKey) : null,
                        child: Text(isSelected ? 'Selected' : 'Use'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? Colors.blue[100] : null,
                        ),
                      ),
                    ],
                  ),
                  tileColor: isSelected ? Colors.blue[50] : null,
                );
              },
            ),
    );
  }
}