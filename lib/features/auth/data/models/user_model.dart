import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    super.phoneNumber,
    super.displayName,
    super.email,
    super.photoUrl,
    super.role = UserRole.customer,
    super.membership = MembershipTier.free,
    super.createdAt,
  });

  /// Create from Firebase Auth user (initial login, no Firestore data yet)
  factory UserModel.fromFirebaseUser(firebase_auth.User user) {
    return UserModel(
      uid: user.uid,
      phoneNumber: user.phoneNumber,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoURL,
      role: UserRole.customer,
      membership: MembershipTier.free,
      createdAt: user.metadata.creationTime,
    );
  }

  /// Create from Firestore document (existing user)
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      phoneNumber: data['phone'] as String?,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      photoUrl: data['photoUrl'] as String?,
      role: UserRole.fromString(data['role'] as String?),
      membership: MembershipTier.fromString(data['membership'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore document for new user creation
  Map<String, dynamic> toFirestore() {
    return {
      'phone': phoneNumber,
      'role': role.value,
      'membership': membership.value,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert to Firestore document for updates (excludes createdAt)
  Map<String, dynamic> toFirestoreUpdate() {
    return {
      'phone': phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? phoneNumber,
    String? displayName,
    String? email,
    String? photoUrl,
    UserRole? role,
    MembershipTier? membership,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      membership: membership ?? this.membership,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Merge Firebase Auth user with Firestore data
  UserModel mergeWithFirestore(Map<String, dynamic> firestoreData) {
    return UserModel(
      uid: uid,
      phoneNumber: phoneNumber,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl,
      role: UserRole.fromString(firestoreData['role'] as String?),
      membership: MembershipTier.fromString(firestoreData['membership'] as String?),
      createdAt: (firestoreData['createdAt'] as Timestamp?)?.toDate() ?? createdAt,
    );
  }
}
