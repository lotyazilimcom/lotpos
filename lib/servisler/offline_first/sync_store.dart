import 'sync_models.dart';

abstract class SyncStore {
  Future<int> getSchemaVersion();

  Future<List<SyncOperation>> readPendingOperations({required int limit});

  Future<void> markOperationsAcked(Iterable<String> opIds);

  Future<int> bumpAttemptCount(String opId);

  Future<void> moveToDeadLetter({
    required SyncOperation operation,
    required String errorCode,
    required String errorMessage,
  });

  Future<SyncCursor> getCursor(String tableName);

  Future<void> setCursor(String tableName, SyncCursor cursor);

  Future<void> upsertPulledRows(
    String tableName,
    List<Map<String, dynamic>> rows,
  );

  Future<void> purgeSyncedData({required DateTime syncedBefore});
}

