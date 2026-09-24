import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_customer/src/providers/looks_provider.dart';
import 'package:mycut_ui/mycut_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Full-screen high-contrast QR display for physical barbershop handoff.
///
/// Features:
/// - Full-screen dark layout.
/// - Scannable QR code encoding `https://mycut.app/l/<code>`.
/// - Prominent 8-character Crockford Base32 text fallback.
/// - 30-minute expiry countdown timer.
/// - Realtime listener on consultations that transitions to
///   "Scanned by a barber ✓".
class ShowQrScreen extends ConsumerStatefulWidget {
  const ShowQrScreen({
    required this.lookId,
    this.initialLook,
    super.key,
  });

  final String lookId;
  final Look? initialLook;

  @override
  ConsumerState<ShowQrScreen> createState() => _ShowQrScreenState();
}

class _ShowQrScreenState extends ConsumerState<ShowQrScreen> {
  LookShare? _share;
  bool _isLoading = true;
  String? _errorMessage;

  bool _isScanned = false;

  Timer? _countdownTimer;
  StreamSubscription<Consultation>? _consultationSub;
  Duration _remaining = const Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _initShareCode();
    _startConsultationListener();
  }

  Future<void> _initShareCode() async {
    final repo = ref.read(shareRepositoryProvider);
    final result = await repo.rotateShareCode(widget.lookId);

    if (!mounted) return;

    switch (result) {
      case Success(:final value):
        setState(() {
          _share = value;
          _isLoading = false;
          _remaining = value.remainingDuration;
        });
        _startTimer();
      case Error():
        // If Supabase is not connected in local mock mode,
        // create a local share code
        final fallbackCode = CrockfordBase32.generateRandom();
        setState(() {
          _share = LookShare(
            code: fallbackCode,
            lookId: widget.lookId,
            expiresAt: DateTime.now().add(const Duration(minutes: 30)),
            shareUrl: 'https://mycut.app/l/$fallbackCode',
          );
          _isLoading = false;
          _remaining = const Duration(minutes: 30);
        });
        _startTimer();
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_share == null) return;

      final diff = _share!.remainingDuration;
      if (diff == Duration.zero) {
        timer.cancel();
        setState(() => _remaining = Duration.zero);
      } else {
        setState(() => _remaining = diff);
      }
    });
  }

  void _startConsultationListener() {
    final repo = ref.read(shareRepositoryProvider);
    _consultationSub = repo.watchConsultationsForLook(widget.lookId).listen(
      (consultation) {
        if (!mounted) return;
        setState(() {
          _isScanned = true;
        });
      },
      onError: (_) {
        // Realtime errors don't interrupt static display
      },
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _consultationSub?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: MyCutColors.surface,
      appBar: AppBar(
        title: Text(_isScanned ? 'Consultation Active' : 'Barber Handoff'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isScanned) ...[
                          // Prominent Scanned ✓ Celebration Card
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(40),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.green,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 48,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'SCANNED BY A BARBER ✓',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.green,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Your barber station has loaded your look and '
                            'cut specifications.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: MyCutColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 48),
                          ElevatedButton(
                            onPressed: () => context.pop(),
                            child: const Text('Back to Looks'),
                          ),
                        ] else ...[
                          Text(
                            'SHOW THIS TO YOUR BARBER',
                            style: theme.textTheme.labelMedium?.copyWith(
                              letterSpacing: 2,
                              color: MyCutColors.primary,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // QR Code Container
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: MyCutColors.primary.withAlpha(50),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: _share?.shareUrl ?? '',
                              size: 220,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Large 8-Character Fallback Code
                          Text(
                            'MANUAL CODE FALLBACK',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.5,
                              color: MyCutColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: MyCutColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: MyCutColors.primary.withAlpha(100),
                              ),
                            ),
                            child: Text(
                              CrockfordBase32.format(_share?.code ?? ''),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: MyCutColors.primary,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Countdown timer
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 18,
                                color: _remaining == Duration.zero
                                    ? MyCutColors.error
                                    : MyCutColors.secondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _remaining == Duration.zero
                                    ? 'Code expired. Refresh to generate new.'
                                    : 'Expires in '
                                        '${_formatDuration(_remaining)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _remaining == Duration.zero
                                      ? MyCutColors.error
                                      : MyCutColors.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 36),

                          // Simulation helper button for testing
                          OutlinedButton.icon(
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            label: const Text('Simulate Barber Scan'),
                            onPressed: () {
                              setState(() => _isScanned = true);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}
