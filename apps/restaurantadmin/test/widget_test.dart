// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:restaurantadmin/main.dart';

void main() {
  testWidgets('App renders smoke test and shows initial Orders screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: Supabase initialization in main.dart is async.
    // For widget tests, if main() is async, you might need to handle this.
    // However, flutter_dotenv and Supabase.initialize are usually fine
    // as they complete before runApp. If issues arise, consider mocking.
    await tester.pumpWidget(const RestaurantManagerApp());

    // Allow time for async operations like Supabase init if they were to affect the first frame.
    // For this basic setup, it might not be strictly necessary but is good practice.
    await tester.pumpAndSettle();

    // Verify that the initial screen (Orders) is displayed.
    // We can check for the AppBar title or the content of the OrdersScreen.
    expect(find.text('Orders'), findsNWidgets(2)); // AppBar title and BottomNavigationBar label
    expect(find.text('Orders Screen'), findsOneWidget); // Content of OrdersScreen
  });
}
