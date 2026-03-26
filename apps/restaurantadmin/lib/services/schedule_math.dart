/// Pure schedule math helpers to enable isolated unit testing.
/// No framework or network dependencies.
library;

class SlotFractionValue {
  final double start; // 0..1 inclusive
  final double end; // 0..1 inclusive and end >= start
  const SlotFractionValue(this.start, this.end);
}

/// Compute per-slot fractions for a time range with end exclusive semantics.
///
/// Example (60-min slots): 13:50–18:20
/// - 13:00 slot: start ~0.833.., end 1.0
/// - middle slots: 0..1
/// - 18:00 slot: 0..~0.333..
/// Supports overnight by splitting around midnight: if end < start, treats as
/// [start, 24:00) U [00:00, end].
Map<int, SlotFractionValue> computeSlotFractions({
  required int slotMinutes,
  required int startMinutes,
  required int endMinutes,
  required List<int> slots, // slot start minutes (sorted ascending), 0..1439
}) {
  final wraps = endMinutes < startMinutes;
  bool overlaps(int slotStart, int slotEnd) {
    if (!wraps) {
      final interStart = slotStart > startMinutes ? slotStart : startMinutes;
      final interEnd = slotEnd < endMinutes ? slotEnd : endMinutes;
      return interEnd > interStart;
    }
    // wrap: [start, 24h) OR [0, end)
    final interStart1 = slotStart > startMinutes ? slotStart : startMinutes;
    final interEnd1 = slotEnd < (24 * 60) ? slotEnd : (24 * 60);
    final interStart2 = slotStart > 0 ? slotStart : 0;
    final interEnd2 = slotEnd < endMinutes ? slotEnd : endMinutes;
    return (interEnd1 > interStart1) || (interEnd2 > interStart2);
  }

  final out = <int, SlotFractionValue>{};
  for (final m in slots) {
    final slotStart = m;
    final slotEnd = m + slotMinutes;
    if (!overlaps(slotStart, slotEnd)) {
      continue;
    }
    double interStart;
    double interEnd;
    if (!wraps) {
      interStart = (slotStart > startMinutes ? slotStart : startMinutes)
          .toDouble();
      interEnd = (slotEnd < endMinutes ? slotEnd : endMinutes).toDouble();
    } else {
      // choose larger overlap segment for this slot
      final a1s = (slotStart > startMinutes ? slotStart : startMinutes)
          .toDouble();
      final a1e = (slotEnd < (24 * 60) ? slotEnd : (24 * 60)).toDouble();
      final a2s = (slotStart > 0 ? slotStart : 0).toDouble();
      final a2e = (slotEnd < endMinutes ? slotEnd : endMinutes).toDouble();
      final seg1 = (a1e - a1s).clamp(0, slotMinutes).toDouble();
      final seg2 = (a2e - a2s).clamp(0, slotMinutes).toDouble();
      if (seg1 >= seg2 && seg1 > 0) {
        interStart = a1s;
        interEnd = a1e;
      } else {
        interStart = a2s;
        interEnd = a2e;
      }
    }
    final fracStart = ((interStart - slotStart) / slotMinutes).clamp(0.0, 1.0);
    final fracEnd = ((interEnd - slotStart) / slotMinutes).clamp(
      fracStart,
      1.0,
    );
    out[m] = SlotFractionValue(fracStart, fracEnd);
  }
  return out;
}

/// Overlay weekly assignments on top of recurring per slot.
/// Weekly entries replace recurring entries for the same slot.
Map<int, Set<String>> overlayRecurringWeekly({
  required Map<int, Set<String>> recurring,
  required Map<int, Set<String>> weekly,
}) {
  final out = <int, Set<String>>{};
  // start with recurring
  recurring.forEach((slot, ids) {
    out[slot] = {...ids};
  });
  // overlay weekly
  weekly.forEach((slot, ids) {
    out[slot] = {...ids};
  });
  return out;
}

/// Compute a daily wage total from assignments and per-slot fractions.
/// Assumes end-exclusive fractions and fraction ranges in [0,1].
/// If a fraction is missing for an employee in a slot, assumes full coverage (0..1).
/// slotMinutes is used to convert fraction to minutes.
/// wageByEmployee maps employeeId -> hourly rate.
/// Returns a double rounded to 2 decimals.
double computeDailyWageTotal({
  required Map<int, Set<String>> assignments,
  required Map<int, Map<String, SlotFractionValue>> fractions,
  required Map<String, double> wageByEmployee,
  required int slotMinutes,
}) {
  double total = 0.0;
  assignments.forEach((slot, ids) {
    for (final id in ids) {
      final frac = fractions[slot]?[id];
      final start = (frac?.start ?? 0.0).clamp(0.0, 1.0);
      final end = (frac?.end ?? 1.0).clamp(start, 1.0);
      final f = (end - start).clamp(0.0, 1.0);
      final mins = slotMinutes * f;
      final rate = wageByEmployee[id] ?? 0.0;
      total += rate * (mins / 60.0);
    }
  });
  return double.parse(total.toStringAsFixed(2));
}
