import 'package:mycut_cutspec/src/clipper_brand.dart';

/// Top-level convenience for [ClipperBrand.guardToMm].
///
/// Defaults to [ClipperBrand.wahl] when [brand] is omitted.
double guardToMm(int guard, {ClipperBrand brand = ClipperBrand.wahl}) {
  return brand.guardToMm(guard);
}

/// Top-level convenience for [ClipperBrand.mmToNearestGuard].
///
/// Defaults to [ClipperBrand.wahl] when [brand] is omitted.
int mmToNearestGuard(double mm, {ClipperBrand brand = ClipperBrand.wahl}) {
  return brand.mmToNearestGuard(mm);
}
