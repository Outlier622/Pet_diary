import 'package:flutter/material.dart';

import 'db_migrate_from_legacy.dart';

class DbMigratePage extends StatefulWidget {
  const DbMigratePage({super.key});

  @override
  State<DbMigratePage> createState() => _DbMigratePageState();
}

class _DbMigratePageState extends State<DbMigratePage> {
  bool _running = false;
  String _log = 'Ready.\n';

  void _append(String s) => setState(() => _log += '$s\n');

  Future<void> _showCounts() async {
    try {
      final album = await DbMigrateFromLegacy.countEventsByType('album');
      final weight = await DbMigrateFromLegacy.countEventsByType('weight');
      final med = await DbMigrateFromLegacy.countEventsByType('med');
      _append('SQLite counts: album=$album, weight=$weight, med=$med');
    } catch (e) {
      _append('ERROR(counts): $e');
    }
  }

  Future<void> _runMigration() async {
    if (_running) return;
    setState(() => _running = true);

    try {
      final path = await DbMigrateFromLegacy.dbPath();
      _append('DB: $path');
      _append('Running migration...');

      final res = await DbMigrateFromLegacy.migrateAll(log: _append);
      _append('DONE: $res');

      await _showCounts();
    } catch (e) {
      _append('ERROR(migrate): $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DB Migration Tool (No impact on app)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: _running ? null : _runMigration,
                  child: Text(_running ? 'Migrating…' : 'Run Migration'),
                ),
                OutlinedButton(
                  onPressed: _running ? null : _showCounts,
                  child: const Text('Show SQLite Counts'),
                ),
                TextButton(
                  onPressed: () => setState(() => _log = 'Ready.\n'),
                  child: const Text('Clear Log'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Log:', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _log,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
