import 'package:equatable/equatable.dart';

class LeaderboardEntry extends Equatable {
  final String phoneNumber;
  final String? customerName;
  final int bookingCount;
  final int rank;
  final DateTime monthStart;
  final DateTime monthEnd;

  const LeaderboardEntry({
    required this.phoneNumber,
    this.customerName,
    required this.bookingCount,
    required this.rank,
    required this.monthStart,
    required this.monthEnd,
  });

  /// Masked phone number for display (e.g., +977 98****1234)
  String get maskedPhone {
    if (phoneNumber.length < 8) return phoneNumber;
    final visible = phoneNumber.substring(0, phoneNumber.length - 4);
    final lastFour = phoneNumber.substring(phoneNumber.length - 4);
    final masked = visible.substring(0, visible.length - 4).padRight(4, '*');
    return '${visible.substring(0, visible.length - 4)}$masked$lastFour';
  }

  /// Display name - customer name if available, otherwise masked phone
  String get displayName => customerName ?? maskedPhone;

  @override
  List<Object?> get props => [
        phoneNumber,
        customerName,
        bookingCount,
        rank,
        monthStart,
        monthEnd,
      ];
}
