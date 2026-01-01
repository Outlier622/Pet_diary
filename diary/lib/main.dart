import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() => runApp(const DiaryApp());

class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}
