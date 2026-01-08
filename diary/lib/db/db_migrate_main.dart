import 'dart:io';
import 'package:flutter/material.dart';

import 'db_migrate_page.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqflite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const _DbMigrateApp());
}

class _DbMigrateApp extends StatelessWidget {
  const _DbMigrateApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DbMigratePage(),
    );
  }
}
