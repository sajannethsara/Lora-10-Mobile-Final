import 'package:flutter/foundation.dart';
import '../services/ble_service.dart';

class AppProvider extends ChangeNotifier {
  List<String> _inboxBucket = [];
  List<String> _sentboxBucket = [];
  List<String> _gpsBucket = [];
  bool _isConnected = false;

  // Getters
  List<String> get inboxBucket => _inboxBucket;
  List<String> get sentboxBucket => _sentboxBucket;
  List<String> get gpsBucket => _gpsBucket;
  bool get isConnected => _isConnected;

  // Update all buckets at once (e.g., after initial BLE sync)
  void updateBuckets({
    required List<String> inbox,
    required List<String> sentbox,
    required List<String> gps,
  }) {
    _inboxBucket = inbox;
    _sentboxBucket = sentbox;
    _gpsBucket = gps;
    notifyListeners();
  }

  void feedDummyData() {
    _inboxBucket = ['1:Hello', '2:World', '3:Test Inbox'];
    _sentboxBucket = ['1:Sent Message', '2:Another Sent', '3:Final Sent'];
    _gpsBucket = ['Lat:12.34,Lng:56.78', 'Lat:98.76,Lng:54.32', 'Lat:11.22,Lng:33.44'];
    notifyListeners();
  }
  // Update individual buckets (e.g., for BLE notifications)
  void updateInbox(List<String> inbox) {
    _inboxBucket = inbox;
    notifyListeners();
  }

  void updateSentbox(List<String> sentbox) {
    _sentboxBucket = sentbox;
    notifyListeners();
  }

  void updateGps(List<String> gps) {
    _gpsBucket = gps;
    notifyListeners();
  }

  // Set connection status
  void setConnected(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  // Send message to IoT device via BleService
  Future<bool> sendMessage(String message) async {
    final bleService = BleService();
    try {
      // Optimistically add message to sentbox with a generated index
      final newIndex = _sentboxBucket.isNotEmpty
          ? int.parse(_sentboxBucket.last.split(':')[0]) + 1
          : 1;
      _sentboxBucket.add('$newIndex:$message');
      notifyListeners();

      // Send message via BLE
      final success = await bleService.sendMessage(message);
      if (!success) {
        // Revert optimistic update on failure
        _sentboxBucket.removeLast();
        notifyListeners();
        print('Failed to send message: $message');
      }
      return success;
    } catch (e) {
      // Revert optimistic update on error
      _sentboxBucket.removeLast();
      notifyListeners();
      print('Error sending message: $e');
      return false;
    }
  }
}