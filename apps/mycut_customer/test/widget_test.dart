import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_customer/main.dart';
import 'package:mycut_customer/src/providers/looks_provider.dart';
import 'package:mycut_customer/src/screens/show_qr_screen.dart';
import 'package:mycut_cutspec/mycut_cutspec.dart';

class FakeShareRepository implements ShareRepository {
  @override
  Future<Result<LookShare, Failure>> rotateShareCode(String lookId) async {
    return Success(
      LookShare(
        code: 'K7M4XQ2P',
        lookId: lookId,
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
        shareUrl: 'https://mycut.app/l/K7M4XQ2P',
      ),
    );
  }

  @override
  Stream<Consultation> watchConsultationsForLook(String lookId) {
    return const Stream.empty();
  }
}

class FakeLooksRepository implements LooksRepository {
  @override
  Future<Result<void, Failure>> archiveLook(String id) async =>
      const Success(null);

  @override
  Future<Result<Look, Failure>> createLook({
    required String title,
    String styleKey = 'custom',
    CutSpec? cutSpec,
    Uint8List? imageBytes,
    String? imageFileName,
    RenderView view = RenderView.front,
  }) async {
    return Success(
      Look(
        id: 'look-1',
        userId: 'user-1',
        title: title,
        styleKey: styleKey,
        cutSpec: cutSpec,
      ),
    );
  }

  @override
  Future<Result<({Look look, String sourcePhotoId}), Failure>>
      createLookWithHeadshots({
    required Uint8List frontImageBytes,
    Uint8List? leftImageBytes,
    Uint8List? rightImageBytes,
    Uint8List? backImageBytes,
    String title = 'My AI Hairstyle',
  }) async {
    return Success(
      (
        look: Look(
          id: 'look-1',
          userId: 'user-1',
          title: title,
          sourcePhotoId: 'photo-1',
        ),
        sourcePhotoId: 'photo-1',
      ),
    );
  }

  @override
  Future<Result<Look, Failure>> getLookById(String id) async {
    return const Success(
      Look(
        id: 'look-1',
        userId: 'user-1',
        title: 'Test Look',
      ),
    );
  }

  @override
  Future<Result<List<Look>, Failure>> getLooks({
    bool includeArchived = false,
  }) async {
    return const Success([
      Look(
        id: 'look-1',
        userId: 'user-1',
        title: 'Sample Fade',
      ),
    ]);
  }
}

void main() {
  testWidgets('MyCutCustomerApp renders home branding and handoff actions',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          looksRepositoryProvider.overrideWithValue(FakeLooksRepository()),
          shareRepositoryProvider.overrideWithValue(FakeShareRepository()),
        ],
        child: const MyCutCustomerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MYCUT'), findsOneWidget);
    expect(
      find.text('AI Hairstyle Studio & Barber Handoff'),
      findsOneWidget,
    );
    expect(find.text('Import Look from Gallery'), findsOneWidget);
    expect(find.text('My Saved Looks'), findsOneWidget);
  });

  testWidgets('ShowQrScreen renders manual code fallback and scan simulation',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shareRepositoryProvider.overrideWithValue(FakeShareRepository()),
        ],
        child: const MaterialApp(
          home: ShowQrScreen(lookId: 'test-look-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SHOW THIS TO YOUR BARBER'), findsOneWidget);
    expect(find.text('MANUAL CODE FALLBACK'), findsOneWidget);
    expect(find.text('K7M4 XQ2P'), findsOneWidget);
    expect(find.text('Simulate Barber Scan'), findsOneWidget);

    // Tap simulate scan
    await tester.tap(find.text('Simulate Barber Scan'));
    await tester.pumpAndSettle();

    expect(find.text('SCANNED BY A BARBER ✓'), findsOneWidget);
  });
}
