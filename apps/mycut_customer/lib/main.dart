import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_customer/src/screens/customer_shell_screen.dart';
import 'package:mycut_customer/src/screens/headshot_capture_screen.dart';
import 'package:mycut_customer/src/screens/import_look_screen.dart';
import 'package:mycut_customer/src/screens/look_detail_screen.dart';
import 'package:mycut_customer/src/screens/my_looks_screen.dart';
import 'package:mycut_customer/src/screens/show_qr_screen.dart';
import 'package:mycut_customer/src/screens/style_browser_screen.dart';
import 'package:mycut_ui/mycut_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: MyCutConfig.supabaseUrl,
    publishableKey: MyCutConfig.supabasePublishableKey,
  );

  // Ensure active user session for instant generation
  if (Supabase.instance.client.auth.currentUser == null) {
    try {
      await Supabase.instance.client.auth.signInAnonymously();
    } catch (_) {
      // Offline fallback
    }
  }

  // Lock to portrait on phone
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: MyCutColors.surfaceContainerLowest,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: MyCutCustomerApp()));
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) {
        final tabStr = state.uri.queryParameters['tab'];
        final tab = int.tryParse(tabStr ?? '') ?? 0;
        return CustomerShellScreen(initialTabIndex: tab);
      },
    ),
    GoRoute(
      path: '/capture',
      builder: (context, state) => const HeadshotCaptureScreen(),
    ),
    GoRoute(
      path: '/styles',
      builder: (context, state) {
        final lookId = state.uri.queryParameters['lookId'] ?? '';
        final sourcePhotoId =
            state.uri.queryParameters['sourcePhotoId'] ?? '';
        return StyleBrowserScreen(
          lookId: lookId,
          sourcePhotoId: sourcePhotoId,
        );
      },
    ),
    GoRoute(
      path: '/looks',
      builder: (context, state) => const MyLooksScreen(),
    ),
    GoRoute(
      path: '/import',
      builder: (context, state) => const ImportLookScreen(),
    ),
    GoRoute(
      path: '/looks/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final look = state.extra as Look?;
        return LookDetailScreen(lookId: id, initialLook: look);
      },
    ),
    GoRoute(
      path: '/looks/:id/qr',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final look = state.extra as Look?;
        return ShowQrScreen(lookId: id, initialLook: look);
      },
    ),
  ],
);

class MyCutCustomerApp extends StatelessWidget {
  const MyCutCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MyCut',
      debugShowCheckedModeBanner: false,
      theme: MyCutTheme.dark,
      routerConfig: _router,
    );
  }
}

/// Home entry screen with quick actions for Step 2 visual handoff.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // MyCut emblem
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: MyCutColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(24),
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
              const SizedBox(height: 24),
              Text(
                'MYCUT',
                style: theme.textTheme.headlineMedium?.copyWith(
                  letterSpacing: 4,
                  color: MyCutColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI Hairstyle Studio & Barber Handoff',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: MyCutColors.secondary,
                ),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Take Headshots & Try Haircuts'),
                      onPressed: () => context.push('/capture'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Browse Haircut Catalog'),
                      onPressed: () => context.push('/styles'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate_rounded),
                      label: const Text('Import Look from Gallery'),
                      onPressed: () => context.push('/import'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.folder_copy_outlined),
                      label: const Text('My Saved Looks'),
                      onPressed: () => context.push('/looks'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
