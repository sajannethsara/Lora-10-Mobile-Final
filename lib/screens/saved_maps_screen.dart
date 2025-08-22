// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../services/map_service.dart';

// class SavedMapsScreen extends StatefulWidget {
//   const SavedMapsScreen({super.key});

//   @override
//   State<SavedMapsScreen> createState() => _SavedMapsScreenState();
// }

// class _SavedMapsScreenState extends State<SavedMapsScreen> {
//   List<Map<String, dynamic>> _hikingAreas = [];
//   Map<String, bool> _downloadStatus = {};

//   @override
//   void initState() {
//     super.initState();
//     _loadHikingAreas();
//   }

//   // Load hiking areas and check download status
//   Future<void> _loadHikingAreas() async {
//     final mapService = Provider.of<MapService>(context, listen: false);
//     final areas = mapService.getHikingAreas();
//     setState(() {
//       _hikingAreas = areas;
//     });

//     // Check download status for each area
//     for (var area in areas) {
//       final isDownloaded = await mapService.isMapDownloaded(area['key']);
//       setState(() {
//         _downloadStatus[area['key']] = isDownloaded;
//       });
//     }
//   }

//   // Handle map download
//   Future<void> _downloadMap(String areaKey) async {
//     final mapService = Provider.of<MapService>(context, listen: false);
//     final success = await mapService.downloadMapArea(areaKey);
//     if (success) {
//       setState(() {
//         _downloadStatus[areaKey] = true;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Map for ${mapService.getHikingAreas().firstWhere((a) => a['key'] == areaKey)['name']} downloaded successfully')),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to download map for $areaKey')),
//       );
//     }
//   }

//   // Select a map as current
//   void _selectMap(String areaKey) {
//     final mapService = Provider.of<MapService>(context, listen: false);
//     mapService.setCurrentArea(areaKey);
//     final selectedArea = mapService.getHikingAreas().firstWhere(
//       (a) => a['key'] == areaKey,
//       orElse: () => {},
//     );
//     print('Selected area: ${selectedArea['name'] ?? ''} (${selectedArea['key'] ?? ''})');
//     setState(() {}); // Refresh UI to show selection
//   }

//   @override
//   Widget build(BuildContext context) {
//     final mapService = Provider.of<MapService>(context);
//     final currentAreaKey = mapService.getCurrentMapCenter() != null
//         ? _hikingAreas.firstWhere((a) => a['center'] == mapService.getCurrentMapCenter(), orElse: () => {'key': ''})['key']
//         : '';

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Saved Maps'),
//       ),
//       body: _hikingAreas.isEmpty
//           ? const Center(child: CircularProgressIndicator())
//           : ListView.builder(
//               itemCount: _hikingAreas.length,
//               itemBuilder: (context, index) {
//                 final area = _hikingAreas[index];
//                 final areaKey = area['key'] as String;
//                 final isDownloaded = _downloadStatus[areaKey] ?? false;
//                 final isSelected = areaKey == currentAreaKey;

//                 return ListTile(
//                   title: Text(area['name'] as String),
//                   trailing: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       if (isDownloaded)
//                         const Icon(Icons.check_circle, color: Colors.green)
//                       else
//                         ElevatedButton(
//                           onPressed: () => _downloadMap(areaKey),
//                           child: const Text('Download'),
//                         ),
//                       const SizedBox(width: 8),
//                       ElevatedButton(
//                         onPressed: isDownloaded ? () => _selectMap(areaKey) : null,
//                         child: Text(isSelected ? 'Selected' : 'Use'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: isSelected ? Colors.green[100] : null,
//                         ),
//                       ),
//                     ],
//                   ),
//                   tileColor: isSelected ? Colors.green[50] : null,
//                 );
//               },
//             ),
//     );
//   }
// }


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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHikingAreas();
  }

  // Load hiking areas and check download status
  Future<void> _loadHikingAreas() async {
    setState(() {
      _isLoading = true;
    });

    final mapService = Provider.of<MapService>(context, listen: false);
    final areas = mapService.getHikingAreas();
    
    setState(() {
      _hikingAreas = areas;
    });

    // Check download status for each area
    for (var area in areas) {
      final isDownloaded = await mapService.isMapDownloaded(area['key']);
      if (mounted) {
        setState(() {
          _downloadStatus[area['key']] = isDownloaded;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Handle map download
  Future<void> _downloadMap(String areaKey) async {
    final mapService = Provider.of<MapService>(context, listen: false);
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Downloading map...'),
          ],
        ),
      ),
    );

    final success = await mapService.downloadMapArea(areaKey);
    
    // Close loading dialog
    if (mounted) Navigator.of(context).pop();

    if (success) {
      setState(() {
        _downloadStatus[areaKey] = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Map for ${_hikingAreas.firstWhere((a) => a['key'] == areaKey)['name']} downloaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download map for $areaKey'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Select a map as current
  void _selectMap(String areaKey) {
    final mapService = Provider.of<MapService>(context, listen: false);
    mapService.setCurrentArea(areaKey);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected ${_hikingAreas.firstWhere((a) => a['key'] == areaKey)['name']}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapService>(
      builder: (context, mapService, child) {
        final currentAreaKey = mapService.currentAreaKey;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Saved Maps'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadHikingAreas,
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hikingAreas.isEmpty
                  ? const Center(
                      child: Text(
                        'No hiking areas available',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _hikingAreas.length,
                      itemBuilder: (context, index) {
                        final area = _hikingAreas[index];
                        final areaKey = area['key'] as String;
                        final isDownloaded = _downloadStatus[areaKey] ?? false;
                        final isSelected = areaKey == currentAreaKey;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: isSelected ? 4 : 1,
                          color: isSelected ? Colors.blue[50] : null,
                          child: ListTile(
                            leading: Icon(
                              Icons.map,
                              color: isSelected ? Colors.blue : Colors.grey,
                            ),
                            title: Text(
                              area['name'] as String,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              isDownloaded ? 'Downloaded' : 'Not downloaded',
                              style: TextStyle(
                                color: isDownloaded ? Colors.green : Colors.orange,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isDownloaded)
                                  ElevatedButton.icon(
                                    onPressed: () => _downloadMap(areaKey),
                                    icon: const Icon(Icons.download, size: 16),
                                    label: const Text('Download'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  )
                                else
                                  const Icon(Icons.check_circle, color: Colors.green),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: isDownloaded ? () => _selectMap(areaKey) : null,
                                  child: Text(isSelected ? 'Selected' : 'Use'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected ? Colors.blue : null,
                                    foregroundColor: isSelected ? Colors.white : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }
}