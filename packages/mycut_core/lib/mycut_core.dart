/// MyCut Core — shared models, repositories, and infrastructure.
///
/// Provides:
/// - Result / Failure sealed types for typed error handling
/// - Supabase client wrapper
/// - Repository interfaces
library mycut_core;

export 'src/config/mycut_config.dart';
export 'src/failures.dart';
export 'src/models/consultation.dart';
export 'src/models/generation_job.dart';
export 'src/models/hairstyle.dart';
export 'src/models/look.dart';
export 'src/models/look_share.dart';
export 'src/repositories/generation_repository.dart';
export 'src/repositories/looks_repository.dart';
export 'src/repositories/receiver_repository.dart';
export 'src/repositories/share_repository.dart';
export 'src/result.dart';
export 'src/utils/crockford_base32.dart';
