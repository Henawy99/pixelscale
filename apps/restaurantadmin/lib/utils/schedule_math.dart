class OverlapFraction {
  final double start; // 0..1 from slot start
  final double end;   // 0..1 from slot start, >= start
  const OverlapFraction(this.start, this.end);
}

class ScheduleMath {
  /// Compute fractional overlap of a slot [slotStart, slotStart+slotMinutes)
  /// with a range [rangeStart, rangeEnd). Returns start/end fractions in 0..1.
  static OverlapFraction slotOverlapFraction({
    required int slotStart,
    required int slotMinutes,
    required int rangeStart,
    required int rangeEnd,
  }) {
    final slotEnd = slotStart + slotMinutes;
    final interStart = (slotStart > rangeStart) ? slotStart : rangeStart;
    final interEnd = (slotEnd < rangeEnd) ? slotEnd : rangeEnd;
    if (interEnd <= interStart) {
      return const OverlapFraction(0.0, 0.0);
    }
    final startFrac = (interStart - slotStart) / slotMinutes;
    final endFrac = (interEnd - slotStart) / slotMinutes;
    final s = startFrac.clamp(0.0, 1.0);
    final e = endFrac.clamp(0.0, 1.0);
    return OverlapFraction(s, e);
  }

  /// Compute wage contribution for a slot given hourlyWage, slot minutes, and overlap fraction
  static double wageForSlot({
    required double hourlyWage,
    required int slotMinutes,
    required OverlapFraction frac,
  }) {
    final f = (frac.end - frac.start).clamp(0.0, 1.0);
    final mins = slotMinutes * f;
    return hourlyWage * (mins / 60.0);
  }
}

