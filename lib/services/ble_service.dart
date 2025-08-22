import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../providers/app_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  BluetoothDevice? device;
  BluetoothService? _service;
  static const String targetDeviceName = 'LORA10_Device';

  static final Guid serviceUuid = Guid('12345678-1234-5678-1234-56789abcdef0');
  static final String targetServiceUuid = serviceUuid.toString();

  // Define characteristic UUIDs based on LORA10 BLE interface
  static final Guid inboxSizeUuid = Guid(
    '12345678-1234-5678-1234-56789abcdef1',
  );
  static final Guid inboxIndexUuid = Guid(
    '12345678-1234-5678-1234-56789abcdef2',
  );
  static final Guid inboxDataUuid = Guid(
    '12345678-1234-5678-1234-56789abcdef3',
  );
  static final Guid inboxNotifyUuid = Guid(
    '12345678-1234-5678-1234-56789abcdef4',
  );

  static final Guid sentboxSizeUuid = Guid(
    '12345678-1234 -5678-1234-56789abcdef5',
  );
  static final Guid sentboxIndexUuid = Guid(
    '12345678-1234-5678-1234-56789abcdef6',
  );
  static final Guid sentboxDataUuid = Guid(
    '12345678-1234-5678-1234-56789abcdef7',
  );
  static final Guid sentboxNotifyUuid = Guid(
    '12345678-1234-5678-1234-56789abcdef8',
  );

  static final Guid gpsSizeUuid = Guid('12345678-1234-5678-1234-56789abcdef9');
  static final Guid gpsIndexUuid = Guid('12345678-1234-5678-1234-56789abcdefa');
  static final Guid gpsDataUuid = Guid('12345678-1234-5678-1234-56789abcdefb');
  static final Guid gpsNotifyUuid = Guid(
    '12345678-1234-5678-1234-56789abcdefc',
  );

  static final Guid writeMessageUuid = Guid(
    '12345678-1234-5678-1234-56789abcdefd',
  );

  StreamSubscription? _notificationSubscription;

Future<List<ScanResult>> scan() async {
  // Check permissions
  Map<Permission, PermissionStatus> statuses = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();
  if (!statuses.values.every((status) => status.isGranted)) {
    print('Permissions denied');
    return [];
  }

  // Check Bluetooth state
  if (!await FlutterBluePlus.isOn) {
    print('Bluetooth is off');
    return [];
  }

  try {
    print('Devices : scanning ------------- ');
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10), withServices: [serviceUuid]);

    // Just wait for scan to finish
    await Future.delayed(const Duration(seconds: 5));

    // Get results
    List<ScanResult> results = FlutterBluePlus.lastScanResults;
    List<ScanResult> targetResults = [];
    for (final r in results) {
      if (r.advertisementData.serviceUuids.isNotEmpty &&
        r.advertisementData.serviceUuids.toString().contains('12345678-1234-5678-1234-56789abcdef0')) {
        print('Found target service UUID on device: ${r.device.name} (${r.device.id})');
        targetResults.add(r);
      }
    }

    print('Devices : scanning ------------- Done ');
    return targetResults;
  } catch (e) {
    print('Scan error: $e');
    return [];
  } finally {
    print('Stopping scan...');
    await FlutterBluePlus.stopScan();
    print('Scan stopped');
  }
}
  // Connect to a device
  Future<bool> connect(
    BluetoothDevice targetDevice,
    BuildContext context,
  ) async {
    try {
      // Request MTU of 120 bytes
      // await targetDevice.requestMtu(120);
      await targetDevice.connect(timeout: Duration(seconds: 15));
      device = targetDevice;

      // Discover services
      List<BluetoothService> services = await targetDevice.discoverServices();
      _service = services.firstWhere((s) => s.uuid == serviceUuid);

      // Subscribe to notifications for all buckets
      await _subscribeToNotifications(context);
      return true;
    } catch (e) {
      print('Connection error: $e');
      return false;
    }
  }

  // Subscribe to notification characteristics
  Future<void> _subscribeToNotifications(BuildContext context) async {
    if (_service == null) return;

    try {
      // Find notification characteristics
      final notifyChars = [
        _service!.characteristics.firstWhere((c) => c.uuid == inboxNotifyUuid),
        _service!.characteristics.firstWhere(
          (c) => c.uuid == sentboxNotifyUuid,
        ),
        _service!.characteristics.firstWhere((c) => c.uuid == gpsNotifyUuid),
      ];

      // Subscribe to each
      for (var char in notifyChars) {
        await char.setNotifyValue(true);
      }

      // Listen for notifications
      _notificationSubscription = device!.state.listen((state) async { 
        if (state == BluetoothConnectionState.connected) {
          for (var char in notifyChars) {
            char.onValueReceived.listen((value) async {
              // New index received, fetch updated data
              int newIndex = _bytesToInt(value);
              await _handleNotification(context, char.uuid, newIndex);
            });
          }
        } else if (state == BluetoothConnectionState.disconnected) {
          // 🚨 Redirect to connect page
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }
      });
    } catch (e) {
      print('Notification subscription error: $e');
    }
  }

  // In ble_service.dart, update _handleNotification
  Future<void> _handleNotification(
    BuildContext context,
    Guid charUuid,
    int index,
  ) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    if (charUuid == inboxNotifyUuid) {
      List<String> data = await readBucket(
        inboxSizeUuid,
        inboxIndexUuid,
        inboxDataUuid,
      );
      appProvider.updateInbox(data);
    } else if (charUuid == sentboxNotifyUuid) {
      List<String> data = await readBucket(
        sentboxSizeUuid,
        sentboxIndexUuid,
        sentboxDataUuid,
      );
      appProvider.updateSentbox(data);
    } else if (charUuid == gpsNotifyUuid) {
      List<String> data = await readBucket(
        gpsSizeUuid,
        gpsIndexUuid,
        gpsDataUuid,
      );
      appProvider.updateGps(data);
    }
  }

  // Read a bucket's data
  Future<List<String>> readBucket(
    Guid sizeUuid,
    Guid indexUuid,
    Guid dataUuid,
  ) async {
    if (_service == null) return [];

    try {
      final sizeChar = _service!.characteristics.firstWhere(
        (c) => c.uuid == sizeUuid,
      );
      final indexChar = _service!.characteristics.firstWhere(
        (c) => c.uuid == indexUuid,
      );
      final dataChar = _service!.characteristics.firstWhere(
        (c) => c.uuid == dataUuid,
      );

      // Read size (uint32_t)
      List<int> sizeBytes = await sizeChar.read();
      int size = _bytesToInt(sizeBytes);

      List<String> bucket = [];
      // Read each index
      for (int i = 0; i < size; i++) {
        // Write index to read
        await indexChar.write(_intToBytes(i));
        // Read data (string)
        List<int> dataBytes = await dataChar.read();
        String data = utf8.decode(dataBytes);
        bucket.add(data);
      }
      return bucket;
    } catch (e) {
      print('Read bucket error: $e');
      return [];
    }
  }

  // Sync all buckets
  Future<Map<String, List<String>>> syncBuckets() async {
    try {
      final inbox = await readBucket(
        inboxSizeUuid,
        inboxIndexUuid,
        inboxDataUuid,
      );
      final sentbox = await readBucket(
        sentboxSizeUuid,
        sentboxIndexUuid,
        sentboxDataUuid,
      );
      final gps = await readBucket(gpsSizeUuid, gpsIndexUuid, gpsDataUuid);
      return {'inbox': inbox, 'sentbox': sentbox, 'gps': gps};
    } catch (e) {
      print('Sync error: $e');
      return {'inbox': [], 'sentbox': [], 'gps': []};
    }
  }

  // Send a message to the IoT device
  Future<bool> sendMessage(String message) async {
    if (_service == null || device == null) return false;

    try {
      final writeChar = _service!.characteristics.firstWhere(
        (c) => c.uuid == writeMessageUuid,
      );
      await writeChar.write(utf8.encode(message));
      return true;
    } catch (e) {
      print('Send message error: $e');
      return false;
    }
  }

  // Disconnect from device
  Future<void> disconnect() async {
    try {
      await _notificationSubscription?.cancel();
      await device?.disconnect();
      device = null;
      _service = null;
    } catch (e) {
      print('Disconnect error: $e');
    }
  }

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    return statuses.values.every((status) => status.isGranted);
  }

  // Helper: Convert bytes to uint32_t
  int _bytesToInt(List<int> bytes) {
    if (bytes.length < 4) return 0;
    return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
  }

  // Helper: Convert uint32_t to bytes
  List<int> _intToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }
}
