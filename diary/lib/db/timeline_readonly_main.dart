// lib/db/timeline_readonly_main.dart
import 'dart:io';
import 'package:flutter/material.dart';

import 'timeline_readonly_page.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqflite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const _TimelineReadonlyApp());
}

class _TimelineReadonlyApp extends StatelessWidget {
  const _TimelineReadonlyApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TimelineReadonlyPage(),
    );
  }
}
