import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_receiver/src/providers/receiver_provider.dart';
import 'package:mycut_receiver/src/screens/large_look_screen.dart';
import 'package:mycut_ui/mycut_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: MyCutConfig.supabaseUrl,
    publishableKey: MyCutConfig.supabasePublishableKey,
  );

  // Lock to landscape for tablet barber use
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Immersive dark UI for glare reduction
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: MyCutColors.surfaceContainerLowest,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Full-screen immersive for barbershop tablet
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  runApp(const ProviderScope(child: MyCutReceiverApp()));
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ReceiverStationScreen(),
    ),
  ],
);

class MyCutReceiverApp extends StatelessWidget {
  const MyCutReceiverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MyCut Receiver',
      debugShowCheckedModeBanner: false,
      theme: MyCutTheme.receiver,
      routerConfig: _router,
    );
  }
}

/// Root station screen: displays either active scanner or active consultation.
class ReceiverStationScreen extends ConsumerWidget {
  const ReceiverStationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiverProvider);

    return switch (state) {
      ReceiverActiveLook(:final payload) => LargeLookScreen(payload: payload),
      _ => const IdleScanScreen(),
    };
  }
}

/// Idle / scan-ready screen — the default state of the Receiver tablet.
class IdleScanScreen extends ConsumerStatefulWidget {
  const IdleScanScreen({super.key});

  @override
  ConsumerState<IdleScanScreen> createState() => _IdleScanScreenState();
}

class _IdleScanScreenState extends ConsumerState<IdleScanScreen> {
  final MobileScannerController _scannerController =
      MobileScannerController();

  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String rawCode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final success =
        await ref.read(receiverProvider.notifier).redeemCode(rawCode);

    if (mounted) {
      setState(() => _isProcessing = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid or expired code. Please try again.'),
            backgroundColor: MyCutColors.error,
          ),
        );
      }
    }
  }

  void _showManualCodeDialog() {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: MyCutColors.surfaceContainer,
          title: const Text('Enter 8-Character Share Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the code shown underneath the customer’s QR code:',
                style: TextStyle(color: MyCutColors.secondary, fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  letterSpacing: 4,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
                decoration: const InputDecoration(
                  hintText: 'e.g. K7M4 XQ2P',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final code = controller.text.trim();
                Navigator.of(dialogCtx).pop();
                if (code.isNotEmpty) {
                  _handleCode(code);
                }
              },
              child: const Text('Redeem Code'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.watch(receiverProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // Left panel — branding + manual entry CTA
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // MyCut emblem
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: MyCutColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: MyCutColors.surfaceContainerHigh,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'M',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: MyCutColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'MYCUT STATION',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          letterSpacing: 4,
                          color: MyCutColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hold customer QR code up to camera',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: MyCutColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Live scan pulse indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: MyCutColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(
                            color: MyCutColors.primary.withAlpha(51),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: MyCutColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isProcessing
                                  ? 'LOADING LOOK...'
                                  : 'SCANNER ACTIVE',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: MyCutColors.primary,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Manual 8-Character Fallback Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.keyboard_alt_outlined, size: 20),
                        label: const Text('Enter Code Manually'),
                        onPressed: _showManualCodeDialog,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Right panel — camera scanner viewport
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: MyCutColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: MyCutColors.outlineVariant.withAlpha(77),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          final barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            if (barcode.rawValue != null) {
                              _handleCode(barcode.rawValue!);
                              break;
                            }
                          }
                        },
                      ),
                      // Target crosshair overlay
                      Center(
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: MyCutColors.primary.withAlpha(180),
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: MyCutColors.surfaceContainerLowest,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Scans today: ${notifier.scansToday}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: MyCutColors.outline,
                fontSize: 14,
              ),
            ),
            Text(
              'Unclaimed device',
              style: theme.textTheme.labelMedium?.copyWith(
                color: MyCutColors.outline,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
