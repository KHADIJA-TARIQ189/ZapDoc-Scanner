import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ZapDocApp());
}

class ZapDocApp extends StatelessWidget {
  const ZapDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZapDoc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2D6CDF),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2D6CDF),
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}
