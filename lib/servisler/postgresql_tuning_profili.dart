import 'dart:io';

class PostgresTuningSetting {
  final String key;
  final String value;
  final String reason;

  const PostgresTuningSetting({
    required this.key,
    required this.value,
    required this.reason,
  });

  String get confLine => '$key = $value';
}

class PostgresTuningProfile {
  final int totalMemoryMb;
  final int cpuCount;
  final int maxConnections;
  final List<PostgresTuningSetting> settings;

  const PostgresTuningProfile({
    required this.totalMemoryMb,
    required this.cpuCount,
    required this.maxConnections,
    required this.settings,
  });

  Map<String, String> toConfMap() {
    return <String, String>{
      for (final setting in settings) setting.key: setting.value,
    };
  }

  static Future<PostgresTuningProfile> detect({
    required int maxConnections,
  }) async {
    final detectedMemoryBytes = await _detectTotalMemoryBytes();
    final memoryMb = _clampInt(
      ((detectedMemoryBytes ?? (8 * 1024 * 1024 * 1024)) / (1024 * 1024))
          .floor(),
      min: 2048,
      max: 262144,
    );
    final cpuCount = _clampInt(Platform.numberOfProcessors, min: 2, max: 64);
    final safeConnections = _clampInt(maxConnections, min: 8, max: 200);

    final sharedBuffersMb = _clampInt(
      (memoryMb * 0.25).floor(),
      min: 256,
      max: 8192,
    );
    final effectiveCacheSizeMb = _clampInt(
      (memoryMb * 0.50).floor(),
      min: 512,
      max: 32768,
    );
    final maintenanceWorkMemMb = _clampInt(
      (memoryMb * 0.05).floor(),
      min: 64,
      max: 2048,
    );
    final workMemMb = _clampInt(
      (memoryMb * 0.10 / (safeConnections * 4)).floor(),
      min: 8,
      max: 64,
    );
    final walBuffersMb = _clampInt(
      (sharedBuffersMb / 32).floor(),
      min: 16,
      max: 256,
    );
    final maxParallelWorkersPerGather = _clampInt(
      (cpuCount / 2).floor(),
      min: 2,
      max: 4,
    );
    final maxParallelWorkers = _clampInt(cpuCount, min: 4, max: 16);
    final maxWorkerProcesses = _clampInt(cpuCount * 2, min: 8, max: 32);
    final autovacuumMaxWorkers = _clampInt(
      (cpuCount / 2).ceil(),
      min: 3,
      max: 6,
    );

    return PostgresTuningProfile(
      totalMemoryMb: memoryMb,
      cpuCount: cpuCount,
      maxConnections: safeConnections,
      settings: <PostgresTuningSetting>[
        PostgresTuningSetting(
          key: 'shared_buffers',
          value: _formatMb(sharedBuffersMb),
          reason: 'RAM\'in yaklasik %25\'i cache icin ayrilir.',
        ),
        PostgresTuningSetting(
          key: 'effective_cache_size',
          value: _formatMb(effectiveCacheSizeMb),
          reason: 'Planner OS cache dahil etkili RAM alanini bilir.',
        ),
        PostgresTuningSetting(
          key: 'maintenance_work_mem',
          value: _formatMb(maintenanceWorkMemMb),
          reason: 'VACUUM ve index bakimi daha az disk turu ile calisir.',
        ),
        PostgresTuningSetting(
          key: 'work_mem',
          value: _formatMb(workMemMb),
          reason: 'Arama/siralama icin connection bazli kontrollu RAM ayrilir.',
        ),
        PostgresTuningSetting(
          key: 'wal_buffers',
          value: _formatMb(walBuffersMb),
          reason: 'Yazma patlamalarinda WAL flush baskisi dusurulur.',
        ),
        const PostgresTuningSetting(
          key: 'checkpoint_completion_target',
          value: '0.9',
          reason: 'Checkpoint yazimlarini zamana yayar.',
        ),
        const PostgresTuningSetting(
          key: 'random_page_cost',
          value: '1.1',
          reason: 'SSD odakli planner secimi icin dusuk tutulur.',
        ),
        const PostgresTuningSetting(
          key: 'effective_io_concurrency',
          value: '200',
          reason: 'SSD/NVMe tarafinda paralel I/O tahmini guclenir.',
        ),
        PostgresTuningSetting(
          key: 'max_worker_processes',
          value: '$maxWorkerProcesses',
          reason: 'Arka plan iscileri CPU cekirdegiyle dengelenir.',
        ),
        PostgresTuningSetting(
          key: 'max_parallel_workers',
          value: '$maxParallelWorkers',
          reason: 'Parallel query ust limiti cekirdek sayisina gore ayarlanir.',
        ),
        PostgresTuningSetting(
          key: 'max_parallel_workers_per_gather',
          value: '$maxParallelWorkersPerGather',
          reason:
              'Tek sorgunun tuketecegi parallel worker sayisi kontrol edilir.',
        ),
        PostgresTuningSetting(
          key: 'autovacuum_max_workers',
          value: '$autovacuumMaxWorkers',
          reason: 'Buyuk tablolarda vacuum kuyrugu birikmez.',
        ),
        const PostgresTuningSetting(
          key: 'autovacuum_vacuum_scale_factor',
          value: '0.01',
          reason: 'Buyuk tablolarda vacuum gec kalmaz.',
        ),
        const PostgresTuningSetting(
          key: 'autovacuum_analyze_scale_factor',
          value: '0.005',
          reason: 'Planner istatistikleri daha cabuk yenilenir.',
        ),
        const PostgresTuningSetting(
          key: 'default_statistics_target',
          value: '250',
          reason: 'Karmasik filtrelerde planner daha isabetli davranir.',
        ),
      ],
    );
  }
}

Future<int?> _detectTotalMemoryBytes() async {
  try {
    if (Platform.isLinux) {
      final file = File('/proc/meminfo');
      if (await file.exists()) {
        final content = await file.readAsString();
        final match = RegExp(
          r'^MemTotal:\s+(\d+)\s+kB$',
          multiLine: true,
        ).firstMatch(content);
        if (match != null) {
          final kb = int.tryParse(match.group(1)!);
          if (kb != null && kb > 0) return kb * 1024;
        }
      }
    }

    if (Platform.isMacOS) {
      final result = await Process.run('sysctl', <String>['-n', 'hw.memsize']);
      if (result.exitCode == 0) {
        final bytes = int.tryParse(result.stdout.toString().trim());
        if (bytes != null && bytes > 0) return bytes;
      }
    }

    if (Platform.isWindows) {
      final powerShell = await Process.run('powershell', <String>[
        '-NoProfile',
        '-Command',
        r'[Console]::WriteLine((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory)',
      ]);
      if (powerShell.exitCode == 0) {
        final bytes = int.tryParse(powerShell.stdout.toString().trim());
        if (bytes != null && bytes > 0) return bytes;
      }
    }
  } catch (_) {}
  return null;
}

int _clampInt(int value, {required int min, required int max}) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

String _formatMb(int value) => '${value}MB';
