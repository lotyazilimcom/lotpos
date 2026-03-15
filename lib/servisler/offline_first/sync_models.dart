import 'dart:math';

enum SyncAction {
  upsert,
  softDelete;

  String get wireValue {
    return switch (this) {
      SyncAction.upsert => 'upsert',
      SyncAction.softDelete => 'soft_delete',
    };
  }
}

class SyncOperation {
  final String opId;
  final int clientSeq;
  final String table;
  final SyncAction action;
  final String rowId;
  final Map<String, dynamic> data;

  const SyncOperation({
    required this.opId,
    required this.clientSeq,
    required this.table,
    required this.action,
    required this.rowId,
    required this.data,
  });

  Map<String, dynamic> toRpcMap() {
    return <String, dynamic>{
      'op_id': opId,
      'client_seq': clientSeq,
      'table': table,
      'action': action.wireValue,
      'row_id': rowId,
      'data': data,
    };
  }
}

class SyncCursor {
  final DateTime lastPulledAt;
  final String? lastPulledId;

  const SyncCursor({required this.lastPulledAt, required this.lastPulledId});

  static SyncCursor initial() {
    return SyncCursor(
      lastPulledAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastPulledId: null,
    );
  }
}

class OfflineSyncFieldScope {
  final List<String> fields;
  final Set<String> allowedValues;

  OfflineSyncFieldScope({
    required this.fields,
    required Iterable<Object?> allowedValues,
  }) : allowedValues = _normalizeValues(allowedValues);

  bool matchesRow(Map<String, dynamic> row) {
    if (allowedValues.isEmpty) return true;
    for (final field in fields) {
      final value = _normalizeValue(row[field]);
      if (value.isNotEmpty && allowedValues.contains(value)) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fields': fields,
      'allowed_values': allowedValues.toList(growable: false),
    };
  }

  static Set<String> _normalizeValues(Iterable<Object?> values) {
    return values
        .map(_normalizeValue)
        .where((value) => value.isNotEmpty)
        .toSet();
  }
}

class OfflineSyncTableScope {
  final String? label;
  final Set<String> allowedRowIds;
  final List<OfflineSyncFieldScope> fieldScopes;
  final Map<String, Object?> rpcParams;
  final bool attachScopeToRpc;
  final String scopeParamName;

  OfflineSyncTableScope({
    this.label,
    Iterable<Object?> allowedRowIds = const <Object?>[],
    this.fieldScopes = const <OfflineSyncFieldScope>[],
    this.rpcParams = const <String, Object?>{},
    this.attachScopeToRpc = false,
    this.scopeParamName = 'p_scope',
  }) : allowedRowIds = allowedRowIds
           .map(_normalizeValue)
           .where((value) => value.isNotEmpty)
           .toSet();

  bool get hasLocalFilter => allowedRowIds.isNotEmpty || fieldScopes.isNotEmpty;

  bool matchesRow(Map<String, dynamic> row) {
    if (allowedRowIds.isNotEmpty) {
      final rowId = _normalizeValue(row['id']);
      if (rowId.isEmpty || !allowedRowIds.contains(rowId)) {
        return false;
      }
    }
    for (final scope in fieldScopes) {
      if (!scope.matchesRow(row)) return false;
    }
    return true;
  }

  List<Map<String, dynamic>> filterRows(List<Map<String, dynamic>> rows) {
    if (!hasLocalFilter) return rows;
    return rows.where(matchesRow).toList(growable: false);
  }

  Map<String, dynamic> toRpcScopePayload() {
    return <String, dynamic>{
      if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
      if (allowedRowIds.isNotEmpty)
        'allowed_row_ids': allowedRowIds.toList(growable: false),
      if (fieldScopes.isNotEmpty)
        'field_scopes': fieldScopes
            .map((scope) => scope.toJson())
            .toList(growable: false),
    };
  }
}

class SchemaGateResult {
  final bool ok;
  final String action;
  final int? currentVersion;
  final int? minSupportedVersion;
  final String? message;

  const SchemaGateResult({
    required this.ok,
    required this.action,
    required this.currentVersion,
    required this.minSupportedVersion,
    required this.message,
  });

  factory SchemaGateResult.fromJson(Map<String, dynamic> json) {
    return SchemaGateResult(
      ok: json['ok'] == true,
      action: (json['action'] as String?)?.trim() ?? '',
      currentVersion: (json['current_version'] as num?)?.toInt(),
      minSupportedVersion: (json['min_supported_version'] as num?)?.toInt(),
      message: (json['message'] as String?)?.trim(),
    );
  }
}

class ApplyBatchResult {
  final bool ok;
  final int applied;
  final int skipped;

  const ApplyBatchResult({
    required this.ok,
    required this.applied,
    required this.skipped,
  });

  factory ApplyBatchResult.fromJson(Map<String, dynamic> json) {
    return ApplyBatchResult(
      ok: json['ok'] == true,
      applied: (json['applied'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
    );
  }
}

class SyncReport {
  final int pushed;
  final int pulled;
  final Duration elapsed;

  const SyncReport({
    required this.pushed,
    required this.pulled,
    required this.elapsed,
  });
}

String _normalizeValue(Object? value) {
  if (value == null) return '';
  return value.toString().trim().toLowerCase();
}

class UuidV4 {
  static final Random _rng = Random.secure();

  static String generate() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
