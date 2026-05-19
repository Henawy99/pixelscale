import 'dart:math';
import '../models/models.dart';

/// Mock data service - replace with Supabase when ready
class DataService {
  static final _rng = Random(42);

  static AnalyticsData getAnalytics() {
    final daily = List.generate(30, (i) {
      final d = DateTime.now().subtract(Duration(days: 29 - i));
      return DailyView(date: d, views: 20 + _rng.nextInt(80));
    });
    return AnalyticsData(
      totalViews: 4823,
      todayViews: 47,
      weekViews: 312,
      monthViews: 1247,
      bounceRate: 34.2,
      avgSessionDuration: 142,
      dailyViews: daily,
      referrers: {'Google': 542, 'Direkt': 328, 'Facebook': 89, 'Instagram': 67, 'Willhaben': 45, 'Andere': 32},
      devices: {'Mobile': 612, 'Desktop': 489, 'Tablet': 72},
      countries: {'Österreich': 923, 'Deutschland': 187, 'Schweiz': 42, 'Andere': 21},
    );
  }

  static SeoInfo getSeoInfo() {
    return SeoInfo(
      title: 'Umzugsfirma Salzburg | Professioneller Umzug | Salzburg Umzugprofis',
      description: 'Ihr professionelles Umzugsunternehmen in Salzburg. Privat- und Firmenumzüge, Verpackung, Auf- und Abbau.',
      titleLength: 70,
      descLength: 105,
      hasCanonical: true,
      hasOgTags: true,
      hasSchema: true,
      mobileReady: true,
      pageSpeed: 92,
      isIndexed: true,
    );
  }

  static List<Booking> getBookings() {
    return [
      Booking(id: '1', name: 'Maria Huber', email: 'maria.h@gmail.com', phone: '+43 660 123 4567',
        fromAddress: 'Linzer Gasse 12, Salzburg', toAddress: 'Getreidegasse 5, Salzburg',
        distanceKm: 3.2, rooms: '2 Zimmer', floor: '3. Etage', hasElevator: false,
        extras: 'Verpackung, Montage', heavyItems: 'Waschmaschine', schedule: 'Standard',
        timePreference: 'Morgens', priceRange: '310€ – 366€', message: 'Bitte vorsichtig mit dem Klavier.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)), status: 'new'),
      Booking(id: '2', name: 'Thomas Berger', email: 'thomas.b@outlook.com', phone: '+43 664 987 6543',
        fromAddress: 'Rainerstraße 8, Salzburg', toAddress: 'Maxglan, Salzburg',
        distanceKm: 5.1, rooms: '3 Zimmer', floor: '1. Etage', hasElevator: true,
        extras: 'Verpackung, Entsorgung, Montage', heavyItems: 'Keine', schedule: 'Wochenende',
        timePreference: 'Nachmittags', priceRange: '450€ – 531€', createdAt: DateTime.now().subtract(const Duration(hours: 8)), status: 'contacted'),
      Booking(id: '3', name: 'Anna Maier', email: 'anna.maier@icloud.com', phone: '+43 699 555 1234',
        fromAddress: 'Aignerstraße 20, Salzburg', toAddress: 'Hallein',
        distanceKm: 15.3, rooms: '4 Zimmer', floor: '2. Etage', hasElevator: false,
        extras: 'Verpackung, Montage, Einlagerung', heavyItems: 'Klavier, Kühlschrank',
        schedule: 'Express', timePreference: 'Morgens', priceRange: '680€ – 802€',
        createdAt: DateTime.now().subtract(const Duration(days: 1)), status: 'confirmed'),
      Booking(id: '4', name: 'Stefan Koch', email: 'stefan.k@gmx.at', phone: '+43 650 111 2222',
        fromAddress: 'Schallmoos, Salzburg', toAddress: 'Wals-Siezenheim',
        distanceKm: 8.7, rooms: '1 Zimmer', floor: '0. Etage', hasElevator: true,
        extras: 'Keine', heavyItems: 'Keine', schedule: 'Standard',
        timePreference: 'Flexibel', priceRange: '145€ – 171€',
        createdAt: DateTime.now().subtract(const Duration(days: 3)), status: 'completed'),
      Booking(id: '5', name: 'Lisa Wagner', email: 'lisa.w@gmail.com',
        fromAddress: 'Nonntal, Salzburg', toAddress: 'Leopoldskron, Salzburg',
        distanceKm: 2.1, rooms: 'Studio', floor: '5. Etage', hasElevator: false,
        extras: 'Verpackung', heavyItems: 'Waschmaschine', schedule: 'Standard',
        timePreference: 'Morgens', priceRange: '240€ – 283€',
        createdAt: DateTime.now().subtract(const Duration(days: 5)), status: 'new'),
    ];
  }
}
