/// MyCut CutSpec — pure Dart clipper guard conversion and cut specification.
///
/// This package has zero Flutter dependency and can be unit-tested in
/// isolation. It provides:
/// - `ClipperBrand` enum with per-brand guard→mm tables
/// - `guardToMm` and `mmToNearestGuard` conversion functions
/// - `CutSpec` structured cut specification model
library mycut_cutspec;

export 'src/clipper_brand.dart';
export 'src/cut_spec.dart';
export 'src/guard_conversion.dart';
