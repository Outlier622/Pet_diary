import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'schema.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, DbSchema.dbName);

    final db = await openDatabase(
      fullPath,
      version: DbSchema.dbVersion,
      onCreate: (db, version) async {
        await _onCreate(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _onUpgrade(db, oldVersion, newVersion);
      },
    );

    _db = db;
    return db;
  }

  Future<void> _onCreate(Database db) async {
    
    await db.execute(DbSchema.createPetsTable);
    await db.execute(DbSchema.createEventsTable);
    await db.execute(DbSchema.idxEventsPetTime);
    await db.execute(DbSchema.idxEventsSyncStatus);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
