import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/vehicle_provider.dart';
import 'providers/inspection_provider.dart';
import 'screens/home_screen.dart';
import 'screens/vehicle_list_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko', null);
  runApp(const LivestockInspectionApp());
}

class LivestockInspectionApp extends StatelessWidget {
  const LivestockInspectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VehicleProvider()..init()),
        ChangeNotifierProvider(create: (_) => InspectionProvider()..init()),
      ],
      child: MaterialApp(
        title: '가축분뇨 검증장비 정기점검표',
        theme: AppTheme.lightTheme,
        home: const _RootScreen(),
        debugShowCheckedModeBanner: false,
        locale: const Locale('ko', 'KR'),
      ),
    );
  }
}

class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  int _currentIndex = 0;

  static const _screens = [
    HomeScreen(),
    VehicleListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: '점검 목록',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            activeIcon: Icon(Icons.directions_car),
            label: '차량 목록',
          ),
        ],
      ),
    );
  }
}
