class Booking {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String fromAddress;
  final String toAddress;
  final double distanceKm;
  final String rooms;
  final String floor;
  final bool hasElevator;
  final String heavyItems;
  final String extras;
  final String schedule;
  final String timePreference;
  final String priceRange;
  final String message;
  final DateTime createdAt;
  final String status; // new, contacted, confirmed, completed

  Booking({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.fromAddress,
    required this.toAddress,
    this.distanceKm = 0,
    this.rooms = '',
    this.floor = '',
    this.hasElevator = false,
    this.heavyItems = '',
    this.extras = '',
    this.schedule = '',
    this.timePreference = '',
    this.priceRange = '',
    this.message = '',
    required this.createdAt,
    this.status = 'new',
  });
}

class AnalyticsData {
  final int totalViews;
  final int todayViews;
  final int weekViews;
  final int monthViews;
  final double bounceRate;
  final double avgSessionDuration;
  final List<DailyView> dailyViews;
  final Map<String, int> referrers;
  final Map<String, int> devices;
  final Map<String, int> countries;

  AnalyticsData({
    this.totalViews = 0,
    this.todayViews = 0,
    this.weekViews = 0,
    this.monthViews = 0,
    this.bounceRate = 0,
    this.avgSessionDuration = 0,
    this.dailyViews = const [],
    this.referrers = const {},
    this.devices = const {},
    this.countries = const {},
  });
}

class DailyView {
  final DateTime date;
  final int views;
  DailyView({required this.date, required this.views});
}

class SeoInfo {
  final String title;
  final String description;
  final int titleLength;
  final int descLength;
  final bool hasCanonical;
  final bool hasOgTags;
  final bool hasSchema;
  final bool mobileReady;
  final double pageSpeed;
  final bool isIndexed;

  SeoInfo({
    this.title = '',
    this.description = '',
    this.titleLength = 0,
    this.descLength = 0,
    this.hasCanonical = false,
    this.hasOgTags = false,
    this.hasSchema = false,
    this.mobileReady = true,
    this.pageSpeed = 0,
    this.isIndexed = true,
  });
}
