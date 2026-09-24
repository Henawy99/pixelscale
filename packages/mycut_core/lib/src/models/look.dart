import 'package:mycut_core/src/config/mycut_config.dart';
import 'package:mycut_cutspec/mycut_cutspec.dart';

/// Available viewing angles for look renders.
enum RenderView {
  front('front', 'Front View'),
  sideLeft('side_left', 'Left Profile'),
  sideRight('side_right', 'Right Profile'),
  back('back', 'Back View'),
  isometric('isometric', 'Isometric');

  const RenderView(this.value, this.label);

  final String value;
  final String label;

  static RenderView fromValue(String value) {
    return RenderView.values.firstWhere(
      (v) => v.value == value,
      orElse: () => RenderView.front,
    );
  }
}

/// A rendered image view of a Look.
class LookRender {
  const LookRender({
    required this.id,
    required this.lookId,
    required this.view,
    required this.storagePath,
    this.provider = 'manual-upload',
    this.resolution = 'final',
    this.costMicros = 0,
    this.signedUrl,
    this.createdAt,
  });

  factory LookRender.fromJson(Map<String, dynamic> json) {
    return LookRender(
      id: json['id'] as String? ?? '',
      lookId: json['look_id'] as String? ?? '',
      view: RenderView.fromValue(json['view'] as String? ?? 'front'),
      storagePath: json['storage_path'] as String? ?? '',
      provider: json['provider'] as String? ?? 'manual-upload',
      resolution: json['resolution'] as String? ?? 'final',
      costMicros: (json['cost_micros'] as num?)?.toInt() ?? 0,
      signedUrl: json['signed_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  final String id;
  final String lookId;
  final RenderView view;
  final String storagePath;
  final String provider;
  final String resolution;
  final int costMicros;
  final String? signedUrl;
  final DateTime? createdAt;

  /// The accessible image URL (signed URL if provided, or public storage URL).
  String get url {
    if (signedUrl != null && signedUrl!.isNotEmpty) {
      return signedUrl!;
    }
    return '${MyCutConfig.supabaseUrl}/storage/v1/object/public/renders/'
        '$storagePath';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'look_id': lookId,
        'view': view.value,
        'storage_path': storagePath,
        'provider': provider,
        'resolution': resolution,
        'cost_micros': costMicros,
        if (signedUrl != null) 'signed_url': signedUrl,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

/// A saved customer Look with associated cut specification.
class Look {
  const Look({
    required this.id,
    required this.userId,
    required this.title,
    this.sourcePhotoId,
    this.styleKey = 'custom',
    this.promptSnapshot = const {},
    this.cutSpec,
    this.isArchived = false,
    this.createdAt,
    this.renders = const [],
  });

  factory Look.fromJson(
    Map<String, dynamic> json, {
    List<LookRender> renders = const [],
  }) {
    CutSpec? cutSpec;
    if (json['cut_spec'] != null && json['cut_spec'] is Map<String, dynamic>) {
      cutSpec = CutSpec.fromJson(json['cut_spec'] as Map<String, dynamic>);
    }

    return Look(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      sourcePhotoId: json['source_photo_id'] as String?,
      title: json['title'] as String? ?? 'My Look',
      styleKey: json['style_key'] as String? ?? 'custom',
      promptSnapshot: (json['prompt_snapshot'] as Map<String, dynamic>?) ?? {},
      cutSpec: cutSpec,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      renders: renders,
    );
  }

  final String id;
  final String userId;
  final String? sourcePhotoId;
  final String title;
  final String styleKey;
  final Map<String, dynamic> promptSnapshot;
  final CutSpec? cutSpec;
  final bool isArchived;
  final DateTime? createdAt;
  final List<LookRender> renders;

  Look copyWith({
    String? id,
    String? userId,
    String? sourcePhotoId,
    String? title,
    String? styleKey,
    Map<String, dynamic>? promptSnapshot,
    CutSpec? cutSpec,
    bool? isArchived,
    DateTime? createdAt,
    List<LookRender>? renders,
  }) {
    return Look(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sourcePhotoId: sourcePhotoId ?? this.sourcePhotoId,
      title: title ?? this.title,
      styleKey: styleKey ?? this.styleKey,
      promptSnapshot: promptSnapshot ?? this.promptSnapshot,
      cutSpec: cutSpec ?? this.cutSpec,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      renders: renders ?? this.renders,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        if (sourcePhotoId != null) 'source_photo_id': sourcePhotoId,
        'title': title,
        'style_key': styleKey,
        'prompt_snapshot': promptSnapshot,
        if (cutSpec != null) 'cut_spec': cutSpec!.toJson(),
        'is_archived': isArchived,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}
