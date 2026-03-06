import 'package:postgres/postgres.dart';

class LisansYazmaEngelliHatasi implements Exception {
  final String message;
  const LisansYazmaEngelliHatasi(this.message);

  @override
  String toString() => message;
}

class LisansKorumaliPool<L> implements Pool<L> {
  final Pool<L> _inner;
  LisansKorumaliPool(this._inner);

  @override
  bool get isOpen => _inner.isOpen;

  @override
  Future<void> get closed => _inner.closed;

  @override
  Future<void> close({bool force = false}) => _inner.close(force: force);

  @override
  Future<Statement> prepare(Object query) => _inner.prepare(query);

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) {
    _guardQuery(query);
    return _inner.execute(
      query,
      parameters: parameters,
      ignoreRows: ignoreRows,
      queryMode: queryMode,
      timeout: timeout,
    );
  }

  @override
  Future<R> run<R>(
    Future<R> Function(Session session) fn, {
    SessionSettings? settings,
    L? locality,
  }) {
    return _inner.run(
      (session) => fn(_LisansKorumaliSession(session)),
      settings: settings,
      locality: locality,
    );
  }

  @override
  Future<R> runTx<R>(
    Future<R> Function(TxSession session) fn, {
    TransactionSettings? settings,
    L? locality,
  }) {
    return _inner.runTx(
      (session) => fn(_LisansKorumaliTxSession(session)),
      settings: settings,
      locality: locality,
    );
  }

  @override
  Future<R> withConnection<R>(
    Future<R> Function(Connection connection) fn, {
    ConnectionSettings? settings,
    L? locality,
  }) {
    return _inner.withConnection(
      (connection) => fn(_LisansKorumaliConnection(connection)),
      settings: settings,
      locality: locality,
    );
  }

  void _guardQuery(Object query) {
    // [2026 LITE/PRO] Global read-only modu kaldırıldı.
    // Lite kısıtlamaları modül bazında (limitler) uygulanır.
    return;
  }
}

class _LisansKorumaliSession implements Session {
  final Session _inner;
  _LisansKorumaliSession(this._inner);

  @override
  bool get isOpen => _inner.isOpen;

  @override
  Future<void> get closed => _inner.closed;

  @override
  Future<Statement> prepare(Object query) => _inner.prepare(query);

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) {
    return _inner.execute(
      query,
      parameters: parameters,
      ignoreRows: ignoreRows,
      queryMode: queryMode,
      timeout: timeout,
    );
  }
}

class _LisansKorumaliTxSession extends _LisansKorumaliSession
    implements TxSession {
  final TxSession _tx;
  _LisansKorumaliTxSession(this._tx) : super(_tx);

  @override
  Future<void> rollback() => _tx.rollback();
}

class _LisansKorumaliConnection extends _LisansKorumaliSession
    implements Connection {
  final Connection _conn;
  _LisansKorumaliConnection(this._conn) : super(_conn);

  @override
  ConnectionInfo get info => _conn.info;

  @override
  Channels get channels => _conn.channels;

  @override
  Future<R> run<R>(
    Future<R> Function(Session session) fn, {
    SessionSettings? settings,
  }) {
    return _conn.run((s) => fn(_LisansKorumaliSession(s)), settings: settings);
  }

  @override
  Future<R> runTx<R>(
    Future<R> Function(TxSession session) fn, {
    TransactionSettings? settings,
  }) {
    return _conn.runTx(
      (tx) => fn(_LisansKorumaliTxSession(tx)),
      settings: settings,
    );
  }

  @override
  Future<void> close({bool force = false}) => _conn.close(force: force);
}
