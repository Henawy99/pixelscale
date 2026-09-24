import 'package:flutter_test/flutter_test.dart';
import 'package:mycut_core/mycut_core.dart';

void main() {
  group('CrockfordBase32', () {
    test('normalize converts lowercase and removes hyphens/spaces', () {
      expect(CrockfordBase32.normalize('k7m4-xq2p'), equals('K7M4XQ2P'));
      expect(CrockfordBase32.normalize('k7m4 xq2p'), equals('K7M4XQ2P'));
      expect(CrockfordBase32.normalize('  K7M4-XQ2P  '), equals('K7M4XQ2P'));
    });

    test('normalize maps ambiguous characters I and L to 1, O to 0', () {
      expect(CrockfordBase32.normalize('IL-oo'), equals('1100'));
      expect(CrockfordBase32.normalize('il-OO'), equals('1100'));
    });

    test('isValid validates 8-character codes', () {
      expect(CrockfordBase32.isValid('K7M4XQ2P'), isTrue);
      expect(CrockfordBase32.isValid('k7m4-xq2p'), isTrue);
      expect(CrockfordBase32.isValid('K7M4'), isFalse);
      expect(CrockfordBase32.isValid('K7M4XQ2P9'), isFalse);
      // 'U' is excluded from Crockford Base32
      expect(CrockfordBase32.isValid('K7M4UQ2P'), isFalse);
    });

    test('format adds separator between 4-char blocks', () {
      expect(CrockfordBase32.format('K7M4XQ2P'), equals('K7M4 XQ2P'));
      expect(
        CrockfordBase32.format('k7m4xq2p', separator: '-'),
        equals('K7M4-XQ2P'),
      );
    });

    test('generateRandom creates valid 8-char codes', () {
      for (var i = 0; i < 50; i++) {
        final code = CrockfordBase32.generateRandom();
        expect(code.length, equals(8));
        expect(CrockfordBase32.isValid(code), isTrue);
      }
    });
  });
}
