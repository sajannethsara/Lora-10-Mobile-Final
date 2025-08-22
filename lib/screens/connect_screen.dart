import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/ble_service.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  List<ScanResult> _devices = [];
  bool _isScanning = false;

  // Start scanning for BLE devices
  Future<void> _scanForDevices() async {
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    final bleService = Provider.of<BleService>(context, listen: false);
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    // appProvider.setConnected(true);
    // appProvider.feedDummyData(); // For testing purposes
    // Navigator.pushReplacementNamed(context, '/home');
    try {
      final results = await bleService.scan();
      print(results);
      setState(() {
        _devices = results;
      });
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No devices found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  // Connect to a device and sync buckets
  Future<void> _connectToDevice(BluetoothDevice device) async {
    final bleService = Provider.of<BleService>(context, listen: false);
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    try {
      final success = await bleService.connect(device, context);
      if (success) {
        // Sync buckets after connection
        final buckets = await bleService.syncBuckets();
        appProvider.updateBuckets(
          inbox: buckets['inbox'] ?? [],
          sentbox: buckets['sentbox'] ?? [],
          gps: buckets['gps'] ?? [],
        );
        appProvider.setConnected(true);
        // Navigate to HomeScreen
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Device'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isScanning ? null : _scanForDevices,
              child: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
            ),
          ),
          Expanded(
            child: _devices.isEmpty && !_isScanning
                ? const Center(child: Text('No devices found. Press Scan to start.'))
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index].device;
                      // final isTargetDevice = device.name == BleService.targetDeviceName;

                      return ListTile(
                        title: Text(device.name.isEmpty ? 'Lora10 UserDevice' : device.name),
                        subtitle: Text(device.id.toString()),
                        trailing: ElevatedButton(
                          onPressed: () => _connectToDevice(device),
                          child: const Text('Connect'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}