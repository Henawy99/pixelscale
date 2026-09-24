import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mycut_customer/src/providers/looks_provider.dart';
import 'package:mycut_ui/mycut_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Barber QR & Specification Dossier screen matching the user's HTML design.
class BarberQrTabScreen extends ConsumerStatefulWidget {
  const BarberQrTabScreen({this.preferredLookId, super.key});

  final String? preferredLookId;

  @override
  ConsumerState<BarberQrTabScreen> createState() => _BarberQrTabScreenState();
}

class _BarberQrTabScreenState extends ConsumerState<BarberQrTabScreen> {
  bool _isCopied = false;
  bool _showBeamedToast = false;
  bool _isBookmarked = true;

  @override
  Widget build(BuildContext context) {
    final looksState = ref.watch(looksListProvider);
    final look = looksState.maybeWhen(
      data: (looks) {
        if (widget.preferredLookId != null) {
          final found = looks
              .where((l) => l.id == widget.preferredLookId)
              .firstOrNull;
          if (found != null) return found;
        }
        return looks.firstOrNull;
      },
      orElse: () => null,
    );

    final title = look?.title ?? 'Textured Crop Low Fade';
    const shareCode = '482-901';
    final qrData = 'https://mycut.app/l/${shareCode.replaceAll('-', '')}';

    return ColoredBox(
      color: MyCutColors.surface,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 110,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Sub-bar Tracker ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: MyCutColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PulsingBarberDot(),
                            SizedBox(width: 8),
                            Text(
                              'LIVE CHAIR HANDOFF',
                              style: TextStyle(
                                color: MyCutColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: MyCutColors.surfaceContainer,
                        ),
                        icon: Icon(
                          _isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: MyCutColors.primary,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _isBookmarked = !_isBookmarked);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 1),
                              backgroundColor: MyCutColors.surfaceContainerHigh,
                              content: Text(
                                _isBookmarked
                                    ? 'Saved to Dossier'
                                    : 'Removed from Dossier',
                                style: const TextStyle(
                                  color: MyCutColors.onSurface,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Header Titles ──
                  const Row(
                    children: [
                      Text(
                        'SPECIFICATION DOSSIER',
                        style: TextStyle(
                          color: MyCutColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text('•', style: TextStyle(color: MyCutColors.secondary)),
                      SizedBox(width: 6),
                      Text(
                        'SPEC #MC-8821',
                        style: TextStyle(
                          color: MyCutColors.secondary,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      color: MyCutColors.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Verified by MyCut Neural Hair Engine',
                    style: TextStyle(
                      color: MyCutColors.secondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Core Handoff Module (Barber QR Code Card) ──
                  _buildQrCard(shareCode, qrData),
                  const SizedBox(height: 24),

                  // ── Technical Cut Specs Sheet ──
                  _buildSpecsSheet(),
                  const SizedBox(height: 24),

                  // ── Action CTAs ──
                  _buildActionCtas(),
                ],
              ),
            ),

            // ── Beamed to Station Toast Notification ──
            if (_showBeamedToast)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: MyCutColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cast_connected_rounded,
                        color: MyCutColors.onPrimary,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Beamed to Station #04',
                              style: TextStyle(
                                color: MyCutColors.onPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Barber Alex has loaded your 4 angles.',
                              style: TextStyle(
                                color: MyCutColors.onPrimaryContainer,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: MyCutColors.onPrimary,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _showBeamedToast = false),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard(String shareCode, String qrData) {
    return Container(
      decoration: BoxDecoration(
        color: MyCutColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MyCutColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          // Header & Icon
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.tap_and_play_rounded,
                color: MyCutColors.primary,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Scan with MyCut Receiver',
                style: TextStyle(
                  color: MyCutColors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Your barber scans this code with their station tablet to '
            'instantly beam high-res angles and cut parameters directly '
            'to their station mirror.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MyCutColors.secondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // QR Matrix Frame with Corner Reticles
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MyCutColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 4 Gold Corner Reticles
                const Positioned(
                  top: 0,
                  left: 0,
                  child: _ReticleCorner(isTop: true, isLeft: true),
                ),
                const Positioned(
                  top: 0,
                  right: 0,
                  child: _ReticleCorner(isTop: true, isLeft: false),
                ),
                const Positioned(
                  bottom: 0,
                  left: 0,
                  child: _ReticleCorner(isTop: false, isLeft: true),
                ),
                const Positioned(
                  bottom: 0,
                  right: 0,
                  child: _ReticleCorner(isTop: false, isLeft: false),
                ),

                // Crisp White QR Matrix Container
                Container(
                  width: 200,
                  height: 200,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      QrImageView(
                        data: qrData,
                        size: 180,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          color: Color(0xFF08080A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          color: Color(0xFF08080A),
                        ),
                      ),
                      // Center MyCut Emblem
                      const MyCutEmblem(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Station Code & Copy PIN Row
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: MyCutColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STATION CODE',
                        style: TextStyle(
                          color: MyCutColors.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PIN: $shareCode',
                        style: const TextStyle(
                          color: MyCutColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    backgroundColor: _isCopied
                        ? MyCutColors.primary
                        : MyCutColors.surfaceContainerHigh,
                    foregroundColor: _isCopied
                        ? MyCutColors.onPrimary
                        : MyCutColors.onSurface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: Icon(
                    _isCopied
                        ? Icons.check_rounded
                        : Icons.content_copy_rounded,
                    size: 16,
                    color: _isCopied
                        ? MyCutColors.onPrimary
                        : MyCutColors.primary,
                  ),
                  label: Text(
                    _isCopied ? 'COPIED!' : 'COPY',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: shareCode));
                    setState(() => _isCopied = true);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _isCopied = false);
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Station Connectivity Notice
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_tethering_rounded,
                color: MyCutColors.primary,
                size: 15,
              ),
              SizedBox(width: 6),
              Text(
                'Syncs with all MyCut Station Terminals v3.4+',
                style: TextStyle(
                  color: MyCutColors.secondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsSheet() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.precision_manufacturing_rounded,
                  color: MyCutColors.primary,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Technical Cut Specs',
                  style: TextStyle(
                    color: MyCutColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              'FOR PROFESSIONAL BARBERS',
              style: TextStyle(
                color: MyCutColors.tertiary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 4 Spec Cards
        _buildSpecRow(
          icon: Icons.content_cut_rounded,
          badge: '#1 LOW BLEND',
          title: 'Sides: #1 low fade blending to #2.5',
          subtitle:
              'Keep parietal ridge weight intact; taper temple points gently '
              'into beard junction.',
        ),
        const SizedBox(height: 10),
        _buildSpecRow(
          icon: Icons.straighten_rounded,
          badge: '1.5 - 2.0"',
          title: '1.5 - 2.0 inches, point cut for heavy texture',
          subtitle:
              'Deep slide cuts throughout crown for separation without '
              'thinning fringe base.',
        ),
        const SizedBox(height: 10),
        _buildSpecRow(
          icon: Icons.architecture_rounded,
          badge: 'TAPERED NAPE',
          title: 'Natural tapered nape (no block line)',
          subtitle:
              'Skin zero fade out at C2 vertebra, preserving natural '
              'hairline boundaries.',
        ),
        const SizedBox(height: 10),
        _buildSpecRow(
          icon: Icons.science_rounded,
          badge: 'MATTE HOLD',
          title: 'Matte styling clay / sea salt spray',
          subtitle:
              'Apply salt spray damp, blast dry with directional diffuser, '
              'finish with dime-size clay.',
        ),
      ],
    );
  }

  Widget _buildSpecRow({
    required IconData icon,
    required String badge,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MyCutColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: MyCutColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: MyCutColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SPECIFICATION',
                      style: TextStyle(
                        color: MyCutColors.secondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: MyCutColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: MyCutColors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: MyCutColors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: MyCutColors.secondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCtas() {
    return Column(
      children: [
        // Primary CTA: Send Directly to Barber Station
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MyCutColors.primary,
              foregroundColor: MyCutColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              elevation: 0,
            ),
            onPressed: () {
              setState(() => _showBeamedToast = true);
              Future.delayed(const Duration(seconds: 4), () {
                if (mounted) setState(() => _showBeamedToast = false);
              });
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.podcasts_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'SEND DIRECTLY TO BARBER STATION',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Secondary CTA: Download Reference Sheet
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: MyCutColors.surfaceContainer,
              foregroundColor: MyCutColors.onSurface,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: const Icon(
              Icons.download_rounded,
              color: MyCutColors.primary,
              size: 18,
            ),
            label: const Text(
              'Download Reference Sheet (PDF)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Specification dossier downloaded as PDF'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReticleCorner extends StatelessWidget {
  const _ReticleCorner({required this.isTop, required this.isLeft});

  final bool isTop;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(
        painter: _ReticleCornerPainter(isTop: isTop, isLeft: isLeft),
      ),
    );
  }
}

class _ReticleCornerPainter extends CustomPainter {
  const _ReticleCornerPainter({required this.isTop, required this.isLeft});

  final bool isTop;
  final bool isLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MyCutColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isTop && isLeft) {
      path
        ..moveTo(0, size.height)
        ..lineTo(0, 0)
        ..lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path
        ..moveTo(0, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PulsingBarberDot extends StatelessWidget {
  const _PulsingBarberDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: MyCutColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}
