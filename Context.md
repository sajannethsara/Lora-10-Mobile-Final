### Overall Architecture Overview

Since you have ReactJS experience but not Flutter, I'll draw parallels where possible. In React, you might structure an app with components, hooks for state/effects, and context/providers for shared state. Flutter is widget-based (like components), uses `StatefulWidget` or hooks-like patterns with packages, and for shared state, we'll use Provider (similar to React Context + useReducer) because it's simple and effective for managing BLE connection and data buckets across screens.

Key principles for this architecture:
- **Modular and Scalable**: Separate concerns like React (e.g., services for BLE logic, models for data, screens for UI).
- **Minimal UI First**: Use basic Flutter widgets (e.g., `ListView`, `TextField`, `ElevatedButton`) without custom styling. We can add themes/material design later to "beautify" it.
- **State Management**: Centralize BLE connection and buckets in a Provider (like a global store). This avoids prop-drilling, similar to Redux or Context in React.
- **Data Flow**: BLE service handles connection, syncing buckets, and sending messages. Buckets are Lists<String> in a notifier class.
- **Navigation**: Use `MaterialApp` with `Navigator` and a bottom navigation bar (like React Router with tabs).
- **Dependencies**: You'll need packages: `flutter_blue_plus` for BLE (reliable for ESP32), `mapbox_gl` for maps (but fallback to `flutter_map` if needed for offline), `path_provider` for storage, `http` for downloading maps, `provider` for state. Install via `pubspec.yaml`.
- **Error Handling**: Basic try-catch and snackbars for feedback (like alerts in React).
- **Testing Focus**: Structure for easy unit tests (e.g., mock BLE service).

The app starts at Connect page, then switches to Home with navbar after connection.

### File Structure

Organize in `lib/` folder (Flutter's src equivalent). Keep it flat initially, group by feature like React.

```
lib/
├── main.dart                  # Entry point, like index.js in React. Sets up Provider and MaterialApp.
├── models/                    # Data classes, like interfaces/types in React.
│   └── bucket_model.dart      # Defines classes for Inbox, Sentbox, GPS buckets (simple wrappers around List<String>).
├── services/                  # Business logic, like utils or API services in React.
│   ├── ble_service.dart       # Handles BLE scan, connect, sync buckets, notifications, send messages. Singleton or injected.
│   └── map_service.dart       # Handles map downloads, storage, loading offline maps.
├── providers/                 # State management, like context providers in React.
│   └── app_provider.dart      # ChangeNotifier for buckets, connection status. Exposed via Provider.
├── screens/                   # Main pages, like pages/components in React. Each is a Stateless/Stateful widget.
│   ├── connect_screen.dart    # Scan + Connect button, redirects on success.
│   ├── home_screen.dart       # Bottom navbar + switches between sub-screens.
│   ├── saved_maps_screen.dart # List of maps with download/use buttons.
│   ├── map_screen.dart        # Mapbox widget showing GPS path.
│   └── chat_screen.dart       # Chat UI with ListView for messages, TextField + send button.
└── widgets/                   # Reusable UI pieces, like custom components in React. Keep minimal.
    ├── message_bubble.dart    # For chat: Simple Container with Text, aligned left/right.
    └── map_tile.dart          # For saved maps list: Row with Text + Icons for download/highlight.
```

This is ~10-15 files to start, expandable. Use `assets/` for any static files (e.g., predefined map URLs in a JSON).

### Code Architecture Breakdown

#### 1. State Management (providers/app_provider.dart)
- Like a React Context: `AppProvider` extends `ChangeNotifier`.
- Holds: `List<String> inboxBucket, sentboxBucket, gpsBucket; bool isConnected = false;`
- Methods: `updateBucketsFromBLE(List<String> newInbox, ...)` – notifies listeners (like setState or dispatch).
- Connection status: `connectToDevice()` calls BLE service, updates buckets on sync.
- Usage: Wrap `MaterialApp` in `ChangeNotifierProvider<AppProvider>`. Access via `Provider.of<AppProvider>(context)` in screens (like useContext).

Example skeleton:
```dart
import 'package:flutter/foundation.dart';

class AppProvider extends ChangeNotifier {
  List<String> inboxBucket = [];
  List<String> sentboxBucket = [];
  List<String> gpsBucket = [];
  bool isConnected = false;

  void updateInbox(List<String> data) {
    inboxBucket = data;
    notifyListeners();
  }

  // Similar for others

  Future<void> syncFromBLE() async {
    // Call ble_service.syncBuckets(), then update above
  }

  Future<void> sendMessage(String msg) async {
    // Call ble_service.sendMessage(msg)
    sentboxBucket.add(msg); // Optimistic update
    notifyListeners();
  }
}
```

#### 2. BLE Service (services/ble_service.dart)
- Core logic for ESP32 sync. Use `flutter_blue_plus`.
- Singleton pattern (like a global service in React).
- Key functions:
  - `scanDevices()`: Returns stream of devices.
  - `connect(String deviceId)`: Connect, discover service (UUID: 12345678-1234-5678-1234-56789abcdef0), read sizes (characteristics for uint32_t size), subscribe to notifications.
  - `syncBuckets()`: Read indices, fetch data in chunks (MTU 120), parse to lists.
  - `sendMessage(String msg)`: Write to special characteristic.
  - Handle notifications: On new index, fetch and update provider.
- Run in background if needed (but minimal for now).

Example:
```dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  BluetoothDevice? device;
  final serviceUuid = Guid('12345678-1234-5678-1234-56789abcdef0');
  // Define characteristic UUIDs for size, index, data, notify, write-msg

  Future<List<ScanResult>> scan() async {
    return FlutterBluePlus.scan().toList(); // Filter for 'ESP32_Sync_Device'
  }

  Future<void> connect(BluetoothDevice dev) async {
    await dev.connect();
    device = dev;
    // Discover services, subscribe to notifications
  }

  Future<List<String>> readBucket(Guid charSize, Guid charIndex, Guid charData) async {
    // Read size, loop over indices, read data, collect into list
  }

  // syncBuckets: Call readBucket for each, update provider
}
```

#### 3. Models (models/bucket_model.dart)
- Simple: `class Bucket { List<String> data; }` – But since just lists, maybe not needed. Use for parsing if data has prefixes (e.g., "1:Hello" -> id + msg).

#### 4. Screens
- **connect_screen.dart**: `StatefulWidget`. Button to scan (show ListView of devices), Connect button (enabled if 'ESP32_Sync_Device' found). On connect: Call provider.connect(), navigate to Home.
- **home_screen.dart**: `StatefulWidget` with `BottomNavigationBar` (items: Saved Maps, Map, Chat). `IndexedStack` or switch for sub-screens (keeps state like React tabs).
- **saved_maps_screen.dart**: Predefined list (hardcode array of map names/URLs). `ListView.builder` with rows: Text(name), IconButton(download), highlight if current. On download: Use `http` to fetch, save via `path_provider` to app docs dir. Set current map in provider.
- **map_screen.dart**: Use `mapbox_gl.MapboxMap` (accessToken needed). Parse gpsBucket (lat,lng strings) to `LatLng` list, draw polyline path. Fullscreen, listen to provider for updates.
- **chat_screen.dart**: `ListView.builder` merging inbox/sentbox (sort by id prefix?). Use `message_bubble.dart` for bubbles (right for sent, left for inbox). Bottom: `TextField` + send button (call provider.sendMessage).

Example for Chat:
```dart
class ChatScreen extends StatelessWidget {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    // Merge and sort messages by id
    List<String> messages = [...provider.inboxBucket, ...provider.sentboxBucket]..sort((a,b) => int.parse(a.split(':')[0]).compareTo(int.parse(b.split(':')[0])));
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: messages.length,
            itemBuilder: (ctx, i) => MessageBubble(message: messages[i], isSent: provider.sentboxBucket.contains(messages[i])),
          ),
        ),
        Row(
          children: [
            Expanded(child: TextField(controller: _controller)),
            ElevatedButton(onPressed: () => provider.sendMessage(_controller.text), child: Text('Send')),
          ],
        ),
      ],
    );
  }
}
```

#### 5. Main (main.dart)
- Like React root: 
```dart
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        home: ConnectScreen(), // Initial route
        routes: {'/home': (_) => HomeScreen()},
      ),
    ),
  );
}
```

#### Implementation Steps
1. Set up pubspec.yaml: Add dependencies (flutter_blue_plus, provider, mapbox_gl, etc.).
2. Implement BLE service first (test connection/sync in isolation).
3. Build providers and models.
4. Add screens one by one: Start with Connect -> Home -> Chat (easiest), then Map/Saved.
5. For offline maps: Store downloaded tiles in storage, load via Mapbox offline manager.
6. Handle disconnections: In provider, listen for BLE events, reconnect if needed.
7. Minimal UI: No colors/themes yet; add `ThemeData` later for beauty.

This gets the functional app done. Focus on requirements: BLE sync, buckets display, send msgs, maps. Test on physical device for BLE. If stuck, debug with print() like console.log. Later, refactor for beauty (e.g., add animations, styles).