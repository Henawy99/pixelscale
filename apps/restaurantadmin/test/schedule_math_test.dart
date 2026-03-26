import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantadmin/utils/schedule_math.dart';

void main() {
  group('slotOverlapFraction', () {
    test('full overlap', () {
      final f = ScheduleMath.slotOverlapFraction(slotStart: 600, slotMinutes: 60, rangeStart: 600, rangeEnd: 660);
      expect(f.start, 0.0);
      expect(f.end, 1.0);
    });
    test('partial start', () {
      final f = ScheduleMath.slotOverlapFraction(slotStart: 600, slotMinutes: 60, rangeStart: 630, rangeEnd: 700);
      expect((f.start * 60).round(), 30);
      expect((f.end * 60).round(), 60);
    });
    test('partial end', () {
      final f = ScheduleMath.slotOverlapFraction(slotStart: 600, slotMinutes: 60, rangeStart: 560, rangeEnd: 630);
      expect((f.start * 60).round(), 0);
      expect((f.end * 60).round(), 30);
    });
    test('no overlap', () {
      final f = ScheduleMath.slotOverlapFraction(slotStart: 600, slotMinutes: 60, rangeStart: 0, rangeEnd: 100);
      expect(f.start, 0.0);
      expect(f.end, 0.0);
    });
  });

  group('wageForSlot', () {
    test('wage from partial fraction', () {
      final w = ScheduleMath.wageForSlot(hourlyWage: 12.0, slotMinutes: 60, frac: const OverlapFraction(0.5, 1.0));
      expect(w, 6.0);
    });
  });
}

