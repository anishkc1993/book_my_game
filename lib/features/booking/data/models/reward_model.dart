import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/reward_entity.dart';

class RewardModel extends RewardEntity {
  const RewardModel({
    required super.userPhone,
    super.progressCount,
    super.totalClaimed,
    super.lastUpdated,
    super.lastClaimedAt,
  });

  factory RewardModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return RewardModel(
      userPhone: (data['userPhone'] as String?) ?? doc.id,
      progressCount: (data['progressCount'] as num?)?.toInt() ?? 0,
      totalClaimed: (data['totalClaimed'] as num?)?.toInt() ?? 0,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      lastClaimedAt: (data['lastClaimedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Doc id is the phone with non-digit chars stripped (so `+9779…` →
  /// `9779…`). Avoids issues with `+` in document paths.
  static String docIdFor(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '');
}
