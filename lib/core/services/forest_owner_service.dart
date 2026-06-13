import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:flutter/foundation.dart';

class ForestOwnerService {
  ForestOwnerService._();
  static final ForestOwnerService instance = ForestOwnerService._();

  final CollectionReference _collection = FirebaseFirestore.instance.collection(FirestoreCollections.forestOwners);

  /// Get stream of all owners
  Stream<List<ForestOwnerModel>> getOwnersStream() {
    return _collection.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Fallback for id if not present in data
        if (!data.containsKey('id')) {
          data['id'] = doc.id;
        }
        try {
          return ForestOwnerModel.fromJson(data);
        } catch (e) {
          debugPrint('Error parsing ForestOwnerModel ${doc.id}: $e');
          // Return a dummy or rethrow depending on needs, here we return a safe parsed one if possible or skip
          rethrow;
        }
      }).toList();
    });
  }

  /// Add a new owner
  Future<void> addOwner(ForestOwnerModel owner) async {
    try {
      await _collection.doc(owner.id).set(owner.toJson());
    } catch (e) {
      debugPrint('[ForestOwnerService] addOwner failed: $e');
      rethrow;
    }
  }

  /// Update an existing owner
  Future<void> updateOwner(ForestOwnerModel owner) async {
    try {
      await _collection.doc(owner.id).update(owner.toJson());
    } catch (e) {
      debugPrint('[ForestOwnerService] updateOwner failed: $e');
      rethrow;
    }
  }

  /// Delete an owner
  Future<void> deleteOwner(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      debugPrint('[ForestOwnerService] deleteOwner failed: $e');
      rethrow;
    }
  }
}
