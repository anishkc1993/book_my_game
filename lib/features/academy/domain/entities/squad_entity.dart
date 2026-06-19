import 'package:equatable/equatable.dart';

/// An academy squad — a group of players that train together
/// (e.g., "U-13 Junior Squad"). Each squad has a coach + weekly schedule.
class SquadEntity extends Equatable {
  final String? id;
  /// e.g., "Junior Squad"
  final String name;
  /// Short label shown on the tab/chip. e.g., "U-13"
  final String shortLabel;
  /// e.g., "Born 2013-14"
  final String? description;
  /// Days the squad trains, 1=Mon ... 7=Sun.
  final List<int> daysOfWeek;
  /// Training start time as minutes past midnight (e.g. 16*60 = 4 PM).
  final int? startMinutes;
  /// Training end time as minutes past midnight.
  final int? endMinutes;
  final String? coachName;
  final bool isActive;
  final DateTime? createdAt;

  const SquadEntity({
    this.id,
    required this.name,
    required this.shortLabel,
    this.description,
    this.daysOfWeek = const [],
    this.startMinutes,
    this.endMinutes,
    this.coachName,
    this.isActive = true,
    this.createdAt,
  });

  String? get coachInitials {
    final n = coachName?.trim() ?? '';
    if (n.isEmpty) return null;
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Human-readable schedule range, e.g. "4:00 – 5:30 PM".
  String? get scheduleRange {
    if (startMinutes == null || endMinutes == null) return null;
    return '${_fmt(startMinutes!)} – ${_fmt(endMinutes!)}';
  }

  static String _fmt(int mins) {
    final h = (mins ~/ 60) % 24;
    final m = mins % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  SquadEntity copyWith({
    String? id,
    String? name,
    String? shortLabel,
    String? description,
    List<int>? daysOfWeek,
    int? startMinutes,
    int? endMinutes,
    String? coachName,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SquadEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      shortLabel: shortLabel ?? this.shortLabel,
      description: description ?? this.description,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      coachName: coachName ?? this.coachName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        shortLabel,
        description,
        daysOfWeek,
        startMinutes,
        endMinutes,
        coachName,
        isActive,
        createdAt,
      ];
}
