import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_customer/src/providers/looks_provider.dart';
import 'package:mycut_ui/mycut_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The 4 headshot capture angles for accurate AI haircut simulation.
enum HeadshotAngle {
  front(
    title: 'Front View',
    hint: 'Look straight at the camera with clear lighting',
    required: true,
    icon: Icons.face_rounded,
  ),
  left(
    title: 'Left Profile',
    hint: 'Turn 90° left showing temple, fade & sideburn',
    required: false,
    icon: Icons.turn_left_rounded,
  ),
  right(
    title: 'Right Profile',
    hint: 'Turn 90° right showing temple, fade & sideburn',
    required: false,
    icon: Icons.turn_right_rounded,
  ),
  back(
    title: 'Back View',
    hint: 'Back of head showing crown, nape & neckline',
    required: false,
    icon: Icons.replay_rounded,
  );

  const HeadshotAngle({
    required this.title,
    required this.hint,
    required this.required,
    required this.icon,
  });

  final String title;
  final String hint;
  final bool required;
  final IconData icon;
}

/// Screen allowing the customer to capture 4 angles of their head
/// before trying on AI hairstyles.
class HeadshotCaptureScreen extends ConsumerStatefulWidget {
  const HeadshotCaptureScreen({super.key});

  @override
  ConsumerState<HeadshotCaptureScreen> createState() =>
      _HeadshotCaptureScreenState();
}

class _HeadshotCaptureScreenState extends ConsumerState<HeadshotCaptureScreen> {
  final _picker = ImagePicker();
  final Map<HeadshotAngle, Uint8List> _capturedPhotos = {};
  bool _isUploading = false;
  String? _uploadStatusText;

  int get _capturedCount => _capturedPhotos.length;
  bool get _canProceed => _capturedPhotos.containsKey(HeadshotAngle.front);

  Future<void> _pickPhoto(HeadshotAngle angle, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 768,
        maxHeight: 768,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.front,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _capturedPhotos[angle] = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not capture photo: $e'),
            backgroundColor: MyCutColors.error,
          ),
        );
      }
    }
  }

  void _showSourceSelector(HeadshotAngle angle) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MyCutColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Capture ${angle.title}',
                  style: const TextStyle(
                    color: MyCutColors.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  angle.hint,
                  style: const TextStyle(
                    color: MyCutColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MyCutColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: MyCutColors.primary,
                    ),
                  ),
                  title: const Text(
                    'Take Photo with Camera',
                    style: TextStyle(
                      color: MyCutColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Use your iPhone front or back camera',
                    style: TextStyle(color: MyCutColors.outline, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhoto(angle, ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MyCutColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: MyCutColors.secondary,
                    ),
                  ),
                  title: const Text(
                    'Choose from Library',
                    style: TextStyle(
                      color: MyCutColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Select an existing photo from camera roll',
                    style: TextStyle(color: MyCutColors.outline, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhoto(angle, ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _proceedToStyles() async {
    final frontBytes = _capturedPhotos[HeadshotAngle.front];
    if (frontBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture at least the Front View photo.'),
          backgroundColor: MyCutColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'Authenticating session...';
    });

    try {
      // Ensure user is signed in
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) {
        await client.auth.signInAnonymously();
      }

      setState(() {
        _uploadStatusText = 'Uploading headshots to secure studio...';
      });

      final repo = ref.read(looksRepositoryProvider);
      final result = await repo.createLookWithHeadshots(
        frontImageBytes: frontBytes,
        leftImageBytes: _capturedPhotos[HeadshotAngle.left],
        rightImageBytes: _capturedPhotos[HeadshotAngle.right],
        backImageBytes: _capturedPhotos[HeadshotAngle.back],
      );

      if (!mounted) return;

      switch (result) {
        case Success(:final value):
          setState(() {
            _uploadStatusText = 'Ready! Loading hairstyle catalog...';
          });
          // Navigate to StyleBrowserScreen with lookId & sourcePhotoId
          await Future<void>.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            await context.push(
              '/styles?lookId=${value.look.id}'
              '&sourcePhotoId=${value.sourcePhotoId}',
            );
          }
        case Error(:final failure):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: ${failure.message}'),
              backgroundColor: MyCutColors.error,
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: MyCutColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatusText = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: MyCutColors.surface,
      appBar: AppBar(
        title: const Text('Capture Your Headshots'),
        backgroundColor: MyCutColors.surfaceContainer,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top instructions header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MyCutColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: MyCutColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '4-Angle Head Simulation',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: MyCutColors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '$_capturedCount of 4 angles captured',
                              style: TextStyle(
                                color: _canProceed
                                    ? MyCutColors.primary
                                    : MyCutColors.onSurfaceVariant,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Capture front, sides, and back of your head so our AI '
                    'seamlessly keeps your real facial features and simulates '
                    'cuts from every perspective.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: MyCutColors.outline,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: MyCutColors.outlineVariant),

            // Grid of 4 angles
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
                children: HeadshotAngle.values.map((angle) {
                  final photoBytes = _capturedPhotos[angle];
                  final isCaptured = photoBytes != null;

                  return _AngleCard(
                    angle: angle,
                    photoBytes: photoBytes,
                    isCaptured: isCaptured,
                    onTap: () => _showSourceSelector(angle),
                  );
                }).toList(),
              ),
            ),

            // Bottom CTA section
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: const BoxDecoration(
                color: MyCutColors.surfaceContainer,
                border: Border(
                  top: BorderSide(
                    color: MyCutColors.outlineVariant,
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isUploading) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MyCutColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _uploadStatusText ?? 'Processing headshots...',
                          style: const TextStyle(
                            color: MyCutColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        _canProceed
                            ? 'Continue to Haircut Studio ($_capturedCount/4)'
                            : 'Capture Front Photo to Continue',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canProceed
                            ? MyCutColors.primary
                            : MyCutColors.surfaceContainerHigh,
                        foregroundColor: _canProceed
                            ? MyCutColors.onPrimary
                            : MyCutColors.outline,
                        elevation: _canProceed ? 2 : 0,
                      ),
                      onPressed: (_canProceed && !_isUploading)
                          ? _proceedToStyles
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AngleCard extends StatelessWidget {
  const _AngleCard({
    required this.angle,
    required this.photoBytes,
    required this.isCaptured,
    required this.onTap,
  });

  final HeadshotAngle angle;
  final Uint8List? photoBytes;
  final bool isCaptured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isCaptured
                ? MyCutColors.surfaceContainerHigh
                : MyCutColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCaptured
                  ? MyCutColors.primary
                  : MyCutColors.outlineVariant,
              width: isCaptured ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isCaptured && photoBytes != null) ...[
                  Image.memory(
                    photoBytes!,
                    fit: BoxFit.cover,
                  ),
                  // Dark gradient overlay at bottom
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Empty placeholder state
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: MyCutColors.surfaceContainerHighest,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: MyCutColors.outlineVariant,
                              ),
                            ),
                            child: Icon(
                              angle.icon,
                              color: angle.required
                                  ? MyCutColors.primary
                                  : MyCutColors.outline,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            angle.title,
                            style: const TextStyle(
                              color: MyCutColors.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            angle.required ? 'Required' : 'Recommended',
                            style: TextStyle(
                              color: angle.required
                                  ? MyCutColors.primary
                                  : MyCutColors.outline,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_a_photo_rounded,
                                size: 14,
                                color: MyCutColors.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Tap to Take',
                                style: TextStyle(
                                  color: MyCutColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Captured badge and Retake CTA
                if (isCaptured) ...[
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: MyCutColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: MyCutColors.onPrimary,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          angle.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
