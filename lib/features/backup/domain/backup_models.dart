class BackupManifest {
  final int schemaVersion;
  final String appVersion;
  final String createdAt;
  final bool includesVoice;
  final Map<String, int> counts;
  final Map<String, String> checksums;

  const BackupManifest({
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.includesVoice,
    required this.counts,
    required this.checksums,
  });

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'app_version': appVersion,
        'created_at': createdAt,
        'includes_voice': includesVoice,
        'counts': counts,
        'checksums': checksums,
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      schemaVersion: json['schema_version'] as int? ?? 1,
      appVersion: json['app_version'] as String? ?? '1.0.0',
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      includesVoice: json['includes_voice'] as bool? ?? false,
      counts: (json['counts'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0),
          ) ??
          {},
      checksums: (json['checksums'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
    );
  }
}

class BackupPreview {
  final bool isValid;
  final String? errorMessage;
  final int schemaVersion;
  final DateTime? createdAt;
  final bool includesVoice;
  final bool isEncrypted;
  final int tasksCount;
  final int goalsCount;
  final int ideasCount;
  final int notesCount;
  final int habitsCount;
  final int financeCount;
  final int voiceNotesCount;
  final int fileSizeBytes;

  const BackupPreview({
    required this.isValid,
    this.errorMessage,
    this.schemaVersion = 1,
    this.createdAt,
    this.includesVoice = false,
    this.isEncrypted = false,
    this.tasksCount = 0,
    this.goalsCount = 0,
    this.ideasCount = 0,
    this.notesCount = 0,
    this.habitsCount = 0,
    this.financeCount = 0,
    this.voiceNotesCount = 0,
    this.fileSizeBytes = 0,
  });

  factory BackupPreview.invalid(String error) {
    return BackupPreview(
      isValid: false,
      errorMessage: error,
    );
  }

  factory BackupPreview.encryptedNeedPassword({int fileSizeBytes = 0}) {
    return BackupPreview(
      isValid: true,
      isEncrypted: true,
      fileSizeBytes: fileSizeBytes,
    );
  }
}
