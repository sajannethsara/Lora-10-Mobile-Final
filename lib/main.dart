// import 'package:flutter/material.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:provider/provider.dart';
// import 'screens/connect_screen.dart';
// import 'screens/home_screen.dart';
// import 'providers/app_provider.dart';
// import 'services/ble_service.dart';
// import 'services/map_service.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await dotenv.load(fileName: ".env");
//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => AppProvider()),
//         Provider(create: (_) => BleService()),
//         Provider(create: (_) => MapService()..init()),
//       ],
//       child: MaterialApp(
//         color: Colors.green[200],
//         debugShowCheckedModeBanner: false,
//         home: const ConnectScreen(),
//         routes: {
//           '/home': (_) => HomeScreen(), // Define HomeScreen
//         },
//       ),
//     ),
//   );
// }



import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'screens/connect_screen.dart';
import 'screens/home_screen.dart';
import 'providers/app_provider.dart';
import 'services/ble_service.dart';
import 'services/map_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  // Initialize MapService
  final mapService = MapService();
  await mapService.init();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        Provider(create: (_) => BleService()),
        ChangeNotifierProvider.value(value: mapService), // Changed to ChangeNotifierProvider
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const ConnectScreen(),
        routes: {
          '/home': (_) => HomeScreen(),
        },
      ),
    ),
  );
}