import 'package:equatable/equatable.dart';

/// User roles in the system
enum UserRole {
  admin('ADMIN'),
  customer('CUSTOMER');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.customer,
    );
  }
}

/// Membership tiers
enum MembershipTier {
  free('FREE'),
  gold('GOLD'),
  platinum('PLATINUM');

  final String value;
  const MembershipTier(this.value);

  static MembershipTier fromString(String? value) {
    return MembershipTier.values.firstWhere(
      (tier) => tier.value == value,
      orElse: () => MembershipTier.free,
    );
  }
}

class UserEntity extends Equatable {
  final String uid;
  final String? phoneNumber;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final UserRole role;
  final MembershipTier membership;
  final DateTime? createdAt;

  const UserEntity({
    required this.uid,
    this.phoneNumber,
    this.displayName,
    this.email,
    this.photoUrl,
    this.role = UserRole.customer,
    this.membership = MembershipTier.free,
    this.createdAt,
  });

  bool get isAuthenticated => uid.isNotEmpty;
  bool get isAdmin => role == UserRole.admin;
  bool get isPremium => membership != MembershipTier.free;

  @override
  List<Object?> get props => [
        uid,
        phoneNumber,
        displayName,
        email,
        photoUrl,
        role,
        membership,
        createdAt,
      ];
}
