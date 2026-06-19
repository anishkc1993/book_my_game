class AppConstants {
  static const String appName = 'BMG';

  static const int otpLength = 6;
  static const int otpTimeoutSeconds = 60;

  static const String usersCollection = 'users';
  static const String bookingsCollection = 'bookings';

  static const String defaultCountryCode = '+977';

  // Booking slot hours
  static const int slotStartHour = 6; // 6 AM
  static const int slotEndHour = 22; // 10 PM (last bookable slot is 9-10 PM)

  // Firestore collections
  static const String settingsCollection = 'settings';
  static const String slotConfigDoc = 'slot_config';

  // Email link auth
  static const String firebaseProjectId = 'book-my-game-a9b76';
  static const String emailLinkUrl = String.fromEnvironment(
    'EMAIL_LINK_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const String pendingEmailKey = 'bmg_pending_email_link';
}

class RouteNames {
  static const String splash = 'splash';
  static const String phoneInput = 'phone-input';
  static const String otpVerification = 'otp-verification';
  static const String emailInput = 'email-input';
  static const String home = 'home';
  static const String booking = 'booking';
  static const String adminBooking = 'admin-booking';
  static const String leaderboard = 'leaderboard';
  static const String slotManagement = 'slot-management';
  static const String adminAnalytics = 'admin-analytics';
  static const String regularBookings = 'regular-bookings';
  static const String selectTurf = 'select-turf';
  static const String venueLocation = 'venue-location';
  static const String academy = 'academy';
  static const String monthlyPlans = 'monthly-plans';
  static const String yearlyRevenue = 'yearly-revenue';
  static const String concessions = 'concessions';
  static const String moreActions = 'more-actions';
  static const String hourlyBreakdown = 'hourly-breakdown';
  static const String concessionCollections = 'concession-collections';
  static const String concessionHistory = 'concession-history';
}

class RoutePaths {
  static const String splash = '/';
  static const String phoneInput = '/phone-input';
  static const String otpVerification = '/otp-verification';
  static const String emailInput = '/email-input';
  static const String home = '/home';
  static const String booking = '/booking';
  static const String adminBooking = '/admin/booking';
  static const String leaderboard = '/admin/leaderboard';
  static const String slotManagement = '/admin/slots';
  static const String adminAnalytics = '/admin/analytics';
  static const String regularBookings = '/admin/regulars';
  static const String selectTurf = '/select-turf';
  static const String venueLocation = '/admin/venue';
  static const String academy = '/admin/academy';
  static const String monthlyPlans = '/admin/monthly-plans';
  static const String yearlyRevenue = '/admin/analytics/yearly';
  static const String concessions = '/admin/concessions';
  static const String moreActions = '/admin/more';
  static const String hourlyBreakdown = '/admin/analytics/hourly';
  static const String concessionCollections = '/admin/concessions/collections';
  static const String concessionHistory = '/admin/concessions/history';
}
