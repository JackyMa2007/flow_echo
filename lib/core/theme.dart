import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF356B5B);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
    scaffoldBackgroundColor: const Color(0xFFF7F8F6),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Color(0xFFF7F8F6),
      surfaceTintColor: Colors.transparent,
    ),
  );
}
