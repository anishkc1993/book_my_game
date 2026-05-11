import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/leaderboard_entry.dart';

class LeaderboardEntryModel extends LeaderboardEntry {
  const LeaderboardEntryModel({
    required super.phoneNumber,
    super.customerName,
    required super.bookingCount,
    required super.rank,
    required super.monthStart,
    required super.monthEnd,
  });

  factory LeaderboardEntryModel.fromEntity(LeaderboardEntry entity) {
    return LeaderboardEntryModel(
      phoneNumber: entity.phoneNumber,
      customerName: entity.customerName,
      bookingCount: entity.bookingCount,
      rank: entity.rank,
      monthStart: entity.monthStart,
      monthEnd: entity.monthEnd,
    );
  }

  factory LeaderboardEntryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaderboardEntryModel(
      phoneNumber: data['phoneNumber'] as String,
      customerName: data['customerName'] as String?,
      bookingCount: data['bookingCount'] as int,
      rank: data['rank'] as int,
      monthStart: (data['monthStart'] as Timestamp).toDate(),
      monthEnd: (data['monthEnd'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'phoneNumber': phoneNumber,
      'customerName': customerName,
      'bookingCount': bookingCount,
      'rank': rank,
      'monthStart': Timestamp.fromDate(monthStart),
      'monthEnd': Timestamp.fromDate(monthEnd),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  LeaderboardEntryModel copyWith({
    String? phoneNumber,
    String? customerName,
    int? bookingCount,
    int? rank,
    DateTime? monthStart,
    DateTime? monthEnd,
  }) {
    return LeaderboardEntryModel(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      customerName: customerName ?? this.customerName,
      bookingCount: bookingCount ?? this.bookingCount,
      rank: rank ?? this.rank,
      monthStart: monthStart ?? this.monthStart,
      monthEnd: monthEnd ?? this.monthEnd,
    );
  }
}
