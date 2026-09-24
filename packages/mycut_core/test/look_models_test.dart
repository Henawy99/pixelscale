import 'package:flutter_test/flutter_test.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_cutspec/mycut_cutspec.dart';

void main() {
  group('Look and LookRender Models', () {
    test('Look serialization round-trip with CutSpec', () {
      const cutSpec = CutSpec(
        fadeType: FadeType.low,
        fadeGuardStart: 1,
        fadeGuardEnd: 3,
        topLengthMm: 35,
      );

      const look = Look(
        id: 'look-123',
        userId: 'user-456',
        title: 'Summer Fade',
        styleKey: 'low_taper',
        cutSpec: cutSpec,
        renders: [
          LookRender(
            id: 'render-1',
            lookId: 'look-123',
            view: RenderView.front,
            storagePath: 'user-456/look-123/front.jpg',
            signedUrl: 'https://example.com/signed-url',
          ),
        ],
      );

      final json = look.toJson();
      expect(json['id'], equals('look-123'));
      expect(json['title'], equals('Summer Fade'));
      final cutSpecJson = json['cut_spec'] as Map<String, dynamic>;
      final sidesJson = cutSpecJson['sides'] as Map<String, dynamic>;
      expect(sidesJson['guard_start'], equals(1));

      final restored = Look.fromJson(json, renders: look.renders);
      expect(restored.id, equals(look.id));
      expect(restored.title, equals(look.title));
      expect(restored.cutSpec?.fadeGuardStart, equals(1));
      expect(restored.renders.length, equals(1));
      expect(restored.renders.first.view, equals(RenderView.front));
      expect(
        restored.renders.first.signedUrl,
        equals('https://example.com/signed-url'),
      );
    });

    test('LookShare expiry and validation calculation', () {
      final validShare = LookShare(
        code: 'K7M4XQ2P',
        lookId: 'look-1',
        expiresAt: DateTime.now().add(const Duration(minutes: 25)),
        shareUrl: 'https://mycut.app/l/K7M4XQ2P',
      );

      expect(validShare.isExpired, isFalse);
      expect(validShare.isValid, isTrue);
      expect(validShare.remainingDuration.inMinutes, greaterThanOrEqualTo(24));

      final expiredShare = LookShare(
        code: 'K7M4XQ2P',
        lookId: 'look-1',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        shareUrl: 'https://mycut.app/l/K7M4XQ2P',
      );

      expect(expiredShare.isExpired, isTrue);
      expect(expiredShare.isValid, isFalse);
      expect(expiredShare.remainingDuration, equals(Duration.zero));
    });

    test('RedeemedLookPayload parses correctly', () {
      final payloadJson = {
        'consultation_id': 'cons-999',
        'look': {
          'id': 'look-888',
          'user_id': 'user-777',
          'title': 'Textured Crop',
        },
        'renders': [
          {
            'id': 'ren-1',
            'look_id': 'look-888',
            'view': 'front',
            'storage_path': 'user-777/look-888/front.jpg',
            'signed_url': 'https://storage/signed',
          }
        ],
        'customer_first_name': 'Marcus',
        'scanned_at': '2026-09-21T03:00:00.000Z',
      };

      final payload = RedeemedLookPayload.fromJson(payloadJson);
      expect(payload.consultationId, equals('cons-999'));
      expect(payload.customerFirstName, equals('Marcus'));
      expect(payload.look.title, equals('Textured Crop'));
      expect(payload.renders.length, equals(1));
      expect(payload.renders.first.signedUrl, equals('https://storage/signed'));
    });
  });
}
