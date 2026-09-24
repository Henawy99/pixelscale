import 'package:flutter_test/flutter_test.dart';
import 'package:mycut_core/mycut_core.dart';

void main() {
  group('GenerationJobStatus', () {
    test('fromValue maps valid strings', () {
      expect(
        GenerationJobStatus.fromValue('queued'),
        GenerationJobStatus.queued,
      );
      expect(
        GenerationJobStatus.fromValue('running'),
        GenerationJobStatus.running,
      );
      expect(
        GenerationJobStatus.fromValue('succeeded'),
        GenerationJobStatus.succeeded,
      );
      expect(
        GenerationJobStatus.fromValue('failed'),
        GenerationJobStatus.failed,
      );
    });

    test('fromValue returns queued for unknown values', () {
      expect(
        GenerationJobStatus.fromValue('invalid'),
        GenerationJobStatus.queued,
      );
    });

    test('isTerminal is correct', () {
      expect(GenerationJobStatus.queued.isTerminal, isFalse);
      expect(GenerationJobStatus.running.isTerminal, isFalse);
      expect(GenerationJobStatus.succeeded.isTerminal, isTrue);
      expect(GenerationJobStatus.failed.isTerminal, isTrue);
    });

    test('isInProgress is correct', () {
      expect(GenerationJobStatus.queued.isInProgress, isTrue);
      expect(GenerationJobStatus.running.isInProgress, isTrue);
      expect(GenerationJobStatus.succeeded.isInProgress, isFalse);
      expect(GenerationJobStatus.failed.isInProgress, isFalse);
    });
  });

  group('GenerationJob', () {
    final sampleJson = <String, dynamic>{
      'id': 'job-123',
      'user_id': 'user-456',
      'look_id': 'look-789',
      'source_photo_id': 'photo-abc',
      'style_key': 'mid_fade',
      'prompt': 'test prompt',
      'variation_count': 4,
      'status': 'running',
      'error_message': null,
      'cost_micros': 500,
      'created_at': '2024-01-01T00:00:00.000Z',
      'started_at': '2024-01-01T00:00:05.000Z',
      'completed_at': null,
    };

    test('fromJson deserializes correctly', () {
      final job = GenerationJob.fromJson(sampleJson);

      expect(job.id, 'job-123');
      expect(job.userId, 'user-456');
      expect(job.lookId, 'look-789');
      expect(job.sourcePhotoId, 'photo-abc');
      expect(job.styleKey, 'mid_fade');
      expect(job.prompt, 'test prompt');
      expect(job.variationCount, 4);
      expect(job.status, GenerationJobStatus.running);
      expect(job.errorMessage, isNull);
      expect(job.costMicros, 500);
      expect(job.createdAt, isNotNull);
      expect(job.startedAt, isNotNull);
      expect(job.completedAt, isNull);
    });

    test('fromJson handles missing optional fields', () {
      final minimalJson = <String, dynamic>{
        'id': 'job-min',
        'user_id': 'user-1',
        'look_id': 'look-1',
        'style_key': 'buzz_cut',
      };

      final job = GenerationJob.fromJson(minimalJson);

      expect(job.id, 'job-min');
      expect(job.sourcePhotoId, isNull);
      expect(job.prompt, '');
      expect(job.variationCount, 4);
      expect(job.status, GenerationJobStatus.queued);
      expect(job.costMicros, 0);
    });

    test('toJson serializes correctly', () {
      final job = GenerationJob.fromJson(sampleJson);
      final json = job.toJson();

      expect(json['id'], 'job-123');
      expect(json['user_id'], 'user-456');
      expect(json['look_id'], 'look-789');
      expect(json['source_photo_id'], 'photo-abc');
      expect(json['style_key'], 'mid_fade');
      expect(json['status'], 'running');
      expect(json['cost_micros'], 500);
      // completed_at should NOT be in JSON since it's null
      expect(json.containsKey('completed_at'), isFalse);
    });

    test('roundtrip fromJson → toJson → fromJson preserves data', () {
      final original = GenerationJob.fromJson(sampleJson);
      final roundTripped = GenerationJob.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.userId, original.userId);
      expect(roundTripped.lookId, original.lookId);
      expect(roundTripped.sourcePhotoId, original.sourcePhotoId);
      expect(roundTripped.styleKey, original.styleKey);
      expect(roundTripped.prompt, original.prompt);
      expect(roundTripped.status, original.status);
      expect(roundTripped.costMicros, original.costMicros);
    });

    test('copyWith overrides specified fields', () {
      final job = GenerationJob.fromJson(sampleJson);
      final updated = job.copyWith(
        status: GenerationJobStatus.succeeded,
        completedAt: DateTime.utc(2024, 1, 1, 0, 0, 30),
      );

      expect(updated.status, GenerationJobStatus.succeeded);
      expect(updated.completedAt, isNotNull);
      // Unchanged fields
      expect(updated.id, job.id);
      expect(updated.lookId, job.lookId);
      expect(updated.styleKey, job.styleKey);
    });

    test('processingDuration returns null when incomplete', () {
      final job = GenerationJob.fromJson(sampleJson);
      expect(job.processingDuration, isNull);
    });

    test('processingDuration calculates when complete', () {
      final completeJson = Map<String, dynamic>.from(sampleJson)
        ..['completed_at'] = '2024-01-01T00:00:30.000Z';

      final job = GenerationJob.fromJson(completeJson);
      expect(job.processingDuration, const Duration(seconds: 30));
    });

    test('toString includes id and status', () {
      final job = GenerationJob.fromJson(sampleJson);
      expect(job.toString(), contains('job-123'));
      expect(job.toString(), contains('running'));
    });
  });
}
