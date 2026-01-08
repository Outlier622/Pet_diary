class DbSchema {
  static const String dbName = 'pet_growth_diary.db';
  static const int dbVersion = 1;

  // ---- table: pets ----
  static const String tPets = 'pets';
  static const String pId = 'id';
  static const String pName = 'name';
  static const String pBreed = 'breed'; 
  static const String pAvatarPath = 'avatarPath';
  static const String pCreatedAt = 'createdAt';
  static const String pUpdatedAt = 'updatedAt';

  // ---- table: timeline_events ----
  static const String tEvents = 'timeline_events';
  static const String eId = 'id';
  static const String ePetId = 'petId';
  static const String eType = 'type';
  static const String eOccurredAt = 'occurredAt';
  static const String ePayloadJson = 'payloadJson';
  static const String eSyncStatus = 'syncStatus'; 
  static const String eUpdatedAt = 'updatedAt';

  // ---- sync status values ----
  static const int syncPending = 0;
  static const int syncSynced = 1;
  static const int syncFailed = 2;

  // ---- SQL: create tables ----
  static const String createPetsTable = '''
CREATE TABLE $tPets (
  $pId TEXT PRIMARY KEY,
  $pName TEXT NOT NULL,
  $pBreed TEXT,
  $pAvatarPath TEXT,
  $pCreatedAt TEXT NOT NULL,
  $pUpdatedAt TEXT NOT NULL
)
''';

  static const String createEventsTable = '''
CREATE TABLE $tEvents (
  $eId TEXT PRIMARY KEY,
  $ePetId TEXT NOT NULL,
  $eType TEXT NOT NULL,
  $eOccurredAt TEXT NOT NULL,
  $ePayloadJson TEXT NOT NULL,
  $eSyncStatus INTEGER NOT NULL,
  $eUpdatedAt TEXT NOT NULL
)
''';

  // ---- SQL: indexes ----
  static const String idxEventsPetTime = '''
CREATE INDEX idx_events_pet_time
ON $tEvents($ePetId, $eOccurredAt DESC)
''';

  static const String idxEventsSyncStatus = '''
CREATE INDEX idx_events_sync_status
ON $tEvents($eSyncStatus)
''';
}
