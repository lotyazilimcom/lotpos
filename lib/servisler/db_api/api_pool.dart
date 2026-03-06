import 'dart:async';

import 'package:postgres/postgres.dart';

import 'api_connection.dart';
import 'veritabani_api_client.dart';

final class ApiPool implements Pool<void> {
  final VeritabaniApiClient _client;
  final String _database;

  bool _open = true;
  final Completer<void> _closed = Completer<void>();

  ApiPool({
    required VeritabaniApiClient client,
    required String database,
  }) : _client = client,
       _database = database.trim();

  @override
  bool get isOpen => _open;

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<void> close({bool force = false}) async {
    if (!_open) return;
    _open = false;
    try {
      await _client.close();
    } finally {
      if (!_closed.isCompleted) _closed.complete();
    }
  }

  void _ensureOpen() {
    if (!_open) throw StateError('Pool kapalı');
  }

  @override
  Future<Statement> prepare(Object query) async {
    _ensureOpen();
    return _ApiStatement(_client, _database, query);
  }

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) {
    _ensureOpen();
    return _client.execute(
      _database,
      query,
      parameters: parameters,
      ignoreRows: ignoreRows,
      timeout: timeout,
    );
  }

  @override
  Future<R> run<R>(
    Future<R> Function(Session session) fn, {
    SessionSettings? settings,
    Object? locality,
  }) async {
    _ensureOpen();
    final session = _ApiSession(_client, _database);
    return fn(session);
  }

  @override
  Future<R> runTx<R>(
    Future<R> Function(TxSession session) fn, {
    TransactionSettings? settings,
    Object? locality,
  }) async {
    _ensureOpen();
    final txId = await _client.txBegin(_database, settings: settings);
    final tx = _ApiTxSession(_client, _database, txId);
    try {
      final result = await fn(tx);
      if (!tx._rolledBack) {
        await _client.txCommit(txId);
        tx._closed = true;
      }
      return result;
    } catch (_) {
      if (!tx._closed && !tx._rolledBack) {
        try {
          await _client.txRollback(txId);
        } catch (_) {}
      }
      tx._closed = true;
      rethrow;
    }
  }

  @override
  Future<R> withConnection<R>(
    Future<R> Function(Connection connection) fn, {
    ConnectionSettings? settings,
    Object? locality,
  }) async {
    _ensureOpen();
    // HTTP proxy: A real socket connection cannot be provided.
    return fn(
      ApiConnection(
        client: _client,
        database: _database,
        closeClientOnClose: false,
      ),
    );
  }
}

final class _ApiSession implements Session {
  final VeritabaniApiClient _client;
  final String _database;
  _ApiSession(this._client, this._database);

  @override
  bool get isOpen => !_client.isClosed;

  @override
  Future<void> get closed => Future<void>.value();

  @override
  Future<Statement> prepare(Object query) async {
    return _ApiStatement(_client, _database, query);
  }

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) {
    return _client.execute(
      _database,
      query,
      parameters: parameters,
      ignoreRows: ignoreRows,
      timeout: timeout,
    );
  }
}

final class _ApiTxSession extends _ApiSession implements TxSession {
  final String _txId;
  bool _closed = false;
  bool _rolledBack = false;

  _ApiTxSession(super.client, super.database, this._txId);

  @override
  bool get isOpen => !_closed && super.isOpen;

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) {
    if (_closed) throw StateError('Transaction kapalı');
    if (_rolledBack) throw StateError('Transaction rollback yapıldı');
    return _client.txExecute(
      _txId,
      query,
      parameters: parameters,
      ignoreRows: ignoreRows,
      timeout: timeout,
    );
  }

  @override
  Future<void> rollback() async {
    if (_closed) return;
    if (_rolledBack) return;
    _rolledBack = true;
    try {
      await _client.txRollback(_txId);
    } finally {
      _closed = true;
    }
  }
}

final class _ApiStatement implements Statement {
  final VeritabaniApiClient _client;
  final String _database;
  final Object _query;
  _ApiStatement(this._client, this._database, this._query);

  @override
  ResultStream bind(Object? parameters) {
    final controller = StreamController<ResultRow>();
    unawaited(() async {
      try {
        final res = await _client.execute(
          _database,
          _query,
          parameters: parameters,
        );
        for (final row in res) {
          controller.add(row);
        }
        await controller.close();
      } catch (e, st) {
        controller.addError(e, st);
        await controller.close();
      }
    }());
    return _ApiResultStream(controller.stream);
  }

  @override
  Future<Result> run(Object? parameters, {Duration? timeout}) {
    return _client.execute(
      _database,
      _query,
      parameters: parameters,
      timeout: timeout,
    );
  }

  @override
  Future<void> dispose() async {}
}

final class _ApiResultStream extends Stream<ResultRow> implements ResultStream {
  final Stream<ResultRow> _inner;
  _ApiResultStream(this._inner);

  @override
  ResultStreamSubscription listen(
    void Function(ResultRow event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final sub = _inner.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    return _ApiResultStreamSub(sub);
  }
}

final class _ApiResultStreamSub implements ResultStreamSubscription {
  final StreamSubscription<ResultRow> _inner;
  _ApiResultStreamSub(this._inner);

  @override
  Future<int> get affectedRows => Future<int>.value(0);

  @override
  Future<ResultSchema> get schema => Future<ResultSchema>.value(ResultSchema(const []));

  @override
  Future<void> cancel() => _inner.cancel();

  @override
  void onData(void Function(ResultRow data)? handleData) => _inner.onData(handleData);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture<E>(futureValue);

  @override
  bool get isPaused => _inner.isPaused;
}
