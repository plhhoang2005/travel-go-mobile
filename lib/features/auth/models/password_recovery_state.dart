enum RecoveryPhase {
  requesting,
  sent,
  ready,
  updating,
  cleanup,
}

enum RecoveryState {
  idle,
  sending,
  emailRequested,
  exchanging,
  ready,
  updating,
  cleanupRequired,
  completed,
  error,
  uncertain,
}

class PendingRecovery {
  static const int currentVersion = 1;
  static const int ttlMinutes = 60;

  final int version;
  final String intentId;
  final DateTime requestedAt;
  final RecoveryPhase phase;
  final String? verifiedUserId;

  PendingRecovery({
    this.version = currentVersion,
    required this.intentId,
    required this.requestedAt,
    required this.phase,
    this.verifiedUserId,
  });

  bool isExpired(DateTime now) {
    return now.toUtc().difference(requestedAt.toUtc()).inMinutes >= ttlMinutes;
  }

  PendingRecovery copyWith({
    RecoveryPhase? phase,
    String? verifiedUserId,
  }) {
    return PendingRecovery(
      version: version,
      intentId: intentId,
      requestedAt: requestedAt,
      phase: phase ?? this.phase,
      verifiedUserId: verifiedUserId ?? this.verifiedUserId,
    );
  }

  Map<String, dynamic> toJson() => {
    'v': version,
    'id': intentId,
    'ts': requestedAt.toUtc().toIso8601String(),
    'phase': phase.name,
    if (verifiedUserId != null) 'uid': verifiedUserId,
  };

  factory PendingRecovery.fromJson(Map<String, dynamic> json) {
    final v = json['v'] as int?;
    if (v != currentVersion) {
      throw const FormatException('Unsupported recovery marker version');
    }
    final id = json['id'] as String?;
    final tsStr = json['ts'] as String?;
    final phaseStr = json['phase'] as String?;
    if (id == null || id.isEmpty || tsStr == null || phaseStr == null) {
      throw const FormatException('Missing required fields in recovery marker');
    }
    final phase = RecoveryPhase.values.firstWhere(
      (p) => p.name == phaseStr,
      orElse: () => throw FormatException('Unknown recovery phase: $phaseStr'),
    );
    final ts = DateTime.parse(tsStr).toUtc();
    return PendingRecovery(
      version: v!,
      intentId: id,
      requestedAt: ts,
      phase: phase,
      verifiedUserId: json['uid'] as String?,
    );
  }
}
