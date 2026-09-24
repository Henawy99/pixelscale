import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_cutspec/mycut_cutspec.dart';
import 'package:mycut_receiver/main.dart';
import 'package:mycut_receiver/src/providers/receiver_provider.dart';

class FakeReceiverRepository implements ReceiverRepository {
  @override
  Future<Result<List<Consultation>, Failure>> getRecentConsultations({
    required String deviceFingerprint,
    int limit = 50,
  }) async {
    return const Success([]);
  }

  @override
  Future<Result<RedeemedLookPayload, Failure>> redeemCode({
    required String code,
    required String deviceFingerprint,
  }) async {
    const cutSpec = CutSpec(
      fadeType: FadeType.mid,
      fadeGuardStart: 1,
      fadeGuardEnd: 3,
      topLengthMm: 45,
    );

    const look = Look(
      id: 'look-456',
      userId: 'user-789',
      title: 'Mid Taper Fade',
      cutSpec: cutSpec,
    );

    return Success(
      RedeemedLookPayload(
        consultationId: 'cons-1',
        look: look,
        renders: const [],
        customerFirstName: 'Marcus',
        scannedAt: DateTime.now(),
      ),
    );
  }
}

void main() {
  testWidgets('MyCutReceiverApp renders station branding and scanner status',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receiverRepositoryProvider
              .overrideWithValue(FakeReceiverRepository()),
        ],
        child: const MyCutReceiverApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MYCUT STATION'), findsOneWidget);
    expect(find.text('SCANNER ACTIVE'), findsOneWidget);
    expect(find.text('Enter Code Manually'), findsOneWidget);
  });

  testWidgets('Manual code entry dialog redeems look and shows large view',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receiverRepositoryProvider
              .overrideWithValue(FakeReceiverRepository()),
        ],
        child: const MyCutReceiverApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Enter Code Manually"
    await tester.tap(find.text('Enter Code Manually'));
    await tester.pumpAndSettle();

    // Verify dialog opens
    expect(find.text('Enter 8-Character Share Code'), findsOneWidget);

    // Enter valid 8-char code
    await tester.enterText(find.byType(TextField), 'K7M4XQ2P');
    await tester.pumpAndSettle();

    // Tap "Redeem Code"
    await tester.tap(find.text('Redeem Code'));
    await tester.pumpAndSettle();

    // Verify transition to LargeLookScreen
    expect(find.text('CONSULTATION FOR MARCUS'), findsOneWidget);
    expect(find.text('Mid Taper Fade'), findsOneWidget);
    expect(find.text('CUT SPECIFICATION'), findsOneWidget);
    expect(find.text('Finish Consultation'), findsOneWidget);

    // Tap "Finish Consultation"
    await tester.tap(find.text('Finish Consultation'));
    await tester.pumpAndSettle();

    // Verify returned to scanner
    expect(find.text('SCANNER ACTIVE'), findsOneWidget);
    expect(find.text('Scans today: 1'), findsOneWidget);
  });
}
