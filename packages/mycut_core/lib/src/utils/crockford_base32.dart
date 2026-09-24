import 'dart:math';

/// Crockford's Base32 encoding and normalization utility.
///
/// Designed to be human-readable, error-tolerant, and unambiguous:
/// - Excludes 'I', 'L', 'O', 'U' to avoid confusion with 1, 0, and obscenity.
/// - Automatically maps 'i' and 'l' to '1', 'o' to '0'.
/// - Case-insensitive.
abstract final class CrockfordBase32 {
  /// The 32 characters in Crockford's alphabet.
  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// Normalizes an input code by trimming, uppercasing, removing spaces/hyphens,
  /// and correcting easily confused characters (I/L -> 1, O -> 0).
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.toUpperCase().runes) {
      final char = String.fromCharCode(rune);
      if (char == ' ' || char == '-') {
        continue;
      }
      if (char == 'I' || char == 'L') {
        buffer.write('1');
      } else if (char == 'O') {
        buffer.write('0');
      } else if (alphabet.contains(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// Validates whether [input] represents a valid Crockford Base32 code
  /// of the specified [length] (default 8).
  static bool isValid(String input, {int length = 8}) {
    final normalized = normalize(input);
    if (normalized.length != length) {
      return false;
    }
    for (final rune in normalized.runes) {
      final char = String.fromCharCode(rune);
      if (!alphabet.contains(char)) {
        return false;
      }
    }
    return true;
  }

  /// Formats an 8-character normalized code into two 4-character blocks
  /// separated by a space or separator (e.g. "K7M4 XQ2P").
  static String format(String input, {String separator = ' '}) {
    final normalized = normalize(input);
    if (normalized.length <= 4) {
      return normalized;
    }
    final mid = normalized.length ~/ 2;
    final firstHalf = normalized.substring(0, mid);
    final secondHalf = normalized.substring(mid);
    return '$firstHalf$separator$secondHalf';
  }

  /// Generates a random Crockford code of [length] characters using
  /// [Random.secure].
  static String generateRandom({int length = 8, Random? random}) {
    final rng = random ?? Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(alphabet[rng.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }
}
