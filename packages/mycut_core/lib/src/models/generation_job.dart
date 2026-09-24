/// Status of an AI generation job.
enum GenerationJobStatus {
  /// Job is queued and waiting to be processed.
  queued('queued'),

  /// Job is actively being processed by the AI provider.
  running('running'),

  /// Job completed successfully with rendered outputs.
  succeeded('succeeded'),

  /// Job failed due to an error.
  failed('failed');

  const GenerationJobStatus(this.value);

  final String value;

  static GenerationJobStatus fromValue(String value) {
    return GenerationJobStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => GenerationJobStatus.queued,
    );
  }

  /// Whether the job is in a terminal state.
  bool get isTerminal => this == succeeded || this == failed;

  /// Whether the job is still in progress.
  bool get isInProgress => this == queued || this == running;
}

/// Tracks an AI hairstyle generation request through its lifecycle.
class GenerationJob {
  const GenerationJob({
    required this.id,
    required this.userId,
    required this.lookId,
    required this.styleKey,
    this.sourcePhotoId,
    this.prompt = '',
    this.variationCount = 4,
    this.status = GenerationJobStatus.queued,
    this.errorMessage,
    this.costMicros = 0,
    this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  factory GenerationJob.fromJson(Map<String, dynamic> json) {
    return GenerationJob(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      lookId: json['look_id'] as String? ?? '',
      sourcePhotoId: json['source_photo_id'] as String?,
      styleKey: json['style_key'] as String? ?? 'custom',
      prompt: json['prompt'] as String? ?? '',
      variationCount: (json['variation_count'] as num?)?.toInt() ?? 4,
      status: GenerationJobStatus.fromValue(
        json['status'] as String? ?? 'queued',
      ),
      errorMessage: json['error_message'] as String?,
      costMicros: (json['cost_micros'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }

  final String id;
  final String userId;
  final String lookId;
  final String? sourcePhotoId;
  final String styleKey;
  final String prompt;
  final int variationCount;
  final GenerationJobStatus status;
  final String? errorMessage;
  final int costMicros;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  GenerationJob copyWith({
    String? id,
    String? userId,
    String? lookId,
    String? sourcePhotoId,
    String? styleKey,
    String? prompt,
    int? variationCount,
    GenerationJobStatus? status,
    String? errorMessage,
    int? costMicros,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return GenerationJob(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lookId: lookId ?? this.lookId,
      sourcePhotoId: sourcePhotoId ?? this.sourcePhotoId,
      styleKey: styleKey ?? this.styleKey,
      prompt: prompt ?? this.prompt,
      variationCount: variationCount ?? this.variationCount,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      costMicros: costMicros ?? this.costMicros,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'look_id': lookId,
        if (sourcePhotoId != null) 'source_photo_id': sourcePhotoId,
        'style_key': styleKey,
        'prompt': prompt,
        'variation_count': variationCount,
        'status': status.value,
        if (errorMessage != null) 'error_message': errorMessage,
        'cost_micros': costMicros,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (startedAt != null) 'started_at': startedAt!.toIso8601String(),
        if (completedAt != null)
          'completed_at': completedAt!.toIso8601String(),
      };

  /// Duration from creation to completion, or null if not yet complete.
  Duration? get processingDuration {
    if (createdAt == null || completedAt == null) return null;
    return completedAt!.difference(createdAt!);
  }

  @override
  String toString() => 'GenerationJob($id, status: ${status.value})';
}
