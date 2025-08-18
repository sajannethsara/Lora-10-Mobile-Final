import 'package:flutter/material.dart';

class MapTile extends StatelessWidget {
  final String mapName;
  final VoidCallback? onDownload;
  final VoidCallback? onHighlight;

  const MapTile({required this.mapName, this.onDownload, this.onHighlight, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(mapName)),
        IconButton(icon: Icon(Icons.download), onPressed: onDownload),
        IconButton(icon: Icon(Icons.star), onPressed: onHighlight),
      ],
    );
  }
}
