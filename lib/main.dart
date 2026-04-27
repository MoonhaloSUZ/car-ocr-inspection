import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/template_provider.dart';
import 'providers/inspection_provider.dart';
import 'screens/home_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko', null);
  runApp(const FieldInspectionApp());
}

class FieldInspectionApp extends StatelessWidget {
  const FieldInspectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TemplateProvider()..init()),
        ChangeNotifierProvider(create: (_) => InspectionProvider()..init()),
      ],
      child: MaterialApp(
        title: '현장 점검표',
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
        locale: const Locale('ko', 'KR'),
      ),
    );
  }
}
