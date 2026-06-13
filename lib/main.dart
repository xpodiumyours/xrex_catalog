import 'package:flutter/material.dart';

import 'screens/xrex_home_screen.dart';

void main() {
  runApp(const XRexCatalogApp());
}

class XRexCatalogApp extends StatelessWidget {
  const XRexCatalogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'X-rex Catalog',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D18),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF06B6D4),
          brightness: Brightness.dark,
          primary: const Color(0xFF06B6D4),
          secondary: const Color(0xFFFF6A00),
          surface: const Color(0xFF111827),
        ),
        fontFamily: 'Arial',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0B1220),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF243044)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF243044)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF06B6D4), width: 1.4),
          ),
        ),
      ),
      home: const XRexHomeScreen(),
    );
  }
}
