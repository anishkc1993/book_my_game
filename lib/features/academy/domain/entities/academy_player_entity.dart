import 'package:equatable/equatable.dart';

/// A player enrolled in the academy at a given turf.
class AcademyPlayerEntity extends Equatable {
  final String? id;
  final String name;
  final DateTime? dob;
  final String? parentPhone;
  final String? position; // e.g., 'Forward', 'Midfielder', 'Defender', 'Goalkeeper'
  final int skillLevel; // 1..5
  final String? photoUrl;
  /// Monthly enrollment fee for this player (currency units).
  final double monthlyFee;
  final DateTime? enrolledAt;
  final bool isActive;
  /// Denormalized: the most recent paid month, format `YYYY-MM` (e.g. `2026-06`).
  /// Used so the list query doesn't need a second round-trip per row.
  final String? lastPaidMonth;
  /// The squad this player belongs to (links to `SquadEntity.id`).
  final String? squadId;

  const AcademyPlayerEntity({
    this.id,
    required this.name,
    this.dob,
    this.parentPhone,
    this.position,
    this.skillLevel = 1,
    this.photoUrl,
    this.monthlyFee = 0,
    this.enrolledAt,
    this.isActive = true,
    this.lastPaidMonth,
    this.squadId,
  });

  /// Age in years from DOB (null if no DOB).
  int? get age {
    if (dob == null) return null;
    final now = DateTime.now();
    int years = now.year - dob!.year;
    if (now.month < dob!.month ||
        (now.month == dob!.month && now.day < dob!.day)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }

  /// Whether this player's fee is paid for the given month (`YYYY-MM`).
  bool isPaidFor(String month) => lastPaidMonth == month;

  static String monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  AcademyPlayerEntity copyWith({
    String? id,
    String? name,
    DateTime? dob,
    String? parentPhone,
    String? position,
    int? skillLevel,
    String? photoUrl,
    double? monthlyFee,
    DateTime? enrolledAt,
    bool? isActive,
    String? lastPaidMonth,
    String? squadId,
  }) {
    return AcademyPlayerEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      dob: dob ?? this.dob,
      parentPhone: parentPhone ?? this.parentPhone,
      position: position ?? this.position,
      skillLevel: skillLevel ?? this.skillLevel,
      photoUrl: photoUrl ?? this.photoUrl,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      isActive: isActive ?? this.isActive,
      lastPaidMonth: lastPaidMonth ?? this.lastPaidMonth,
      squadId: squadId ?? this.squadId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        dob,
        parentPhone,
        position,
        skillLevel,
        photoUrl,
        monthlyFee,
        enrolledAt,
        isActive,
        lastPaidMonth,
        squadId,
      ];
}
