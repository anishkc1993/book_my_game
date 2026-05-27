import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/turf_model.dart';

abstract class TurfRemoteDataSource {
  Future<List<TurfModel>> listActiveTurfs();
  Future<TurfModel?> getTurf(String id);
  Future<TurfModel?> findTurfByAdminPhone(String phone);
  Future<TurfModel> createTurf({
    required String name,
    required String adminPhone,
    String? address,
  });
  Future<void> updateVenueDetails({
    required String turfId,
    String? venueName,
    String? street,
    String? cityArea,
    String? landmark,
    double? latitude,
    double? longitude,
    String? shareSlug,
  });
}

class TurfRemoteDataSourceImpl implements TurfRemoteDataSource {
  final FirebaseFirestore _firestore;

  static const String _collection = 'turfs';

  TurfRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<TurfModel>> listActiveTurfs() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();
      final list =
          snapshot.docs.map((d) => TurfModel.fromFirestore(d)).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      debugPrint('❌ listActiveTurfs: $e');
      throw ServerException('Failed to load turfs: ${e.toString()}');
    }
  }

  @override
  Future<TurfModel?> getTurf(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      return doc.exists ? TurfModel.fromFirestore(doc) : null;
    } catch (e) {
      debugPrint('❌ getTurf: $e');
      return null;
    }
  }

  @override
  Future<TurfModel?> findTurfByAdminPhone(String phone) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('adminPhone', isEqualTo: phone)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return TurfModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      debugPrint('❌ findTurfByAdminPhone: $e');
      return null;
    }
  }

  @override
  Future<TurfModel> createTurf({
    required String name,
    required String adminPhone,
    String? address,
  }) async {
    try {
      final docRef = await _firestore.collection(_collection).add({
        'name': name,
        'adminPhone': adminPhone,
        'address': address,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return TurfModel(
        id: docRef.id,
        name: name,
        adminPhone: adminPhone,
        address: address,
        isActive: true,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ createTurf: $e');
      throw ServerException('Failed to create turf: ${e.toString()}');
    }
  }

  @override
  Future<void> updateVenueDetails({
    required String turfId,
    String? venueName,
    String? street,
    String? cityArea,
    String? landmark,
    double? latitude,
    double? longitude,
    String? shareSlug,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (venueName != null) updates['venueName'] = venueName;
      if (street != null) updates['street'] = street;
      if (cityArea != null) updates['cityArea'] = cityArea;
      if (landmark != null) updates['landmark'] = landmark;
      if (latitude != null) updates['latitude'] = latitude;
      if (longitude != null) updates['longitude'] = longitude;
      if (shareSlug != null) updates['shareSlug'] = shareSlug;

      await _firestore.collection(_collection).doc(turfId).update(updates);
    } catch (e) {
      debugPrint('❌ updateVenueDetails: $e');
      throw ServerException('Failed to save venue details: ${e.toString()}');
    }
  }
}
