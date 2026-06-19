import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/models/notification_model.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:flutter/foundation.dart';

class ForestProjectService {
  ForestProjectService._();
  static final ForestProjectService instance = ForestProjectService._();

  final CollectionReference _collection = FirebaseFirestore.instance.collection(
    FirestoreCollections.forestProjects,
  );

  /// Get stream of all projects
  Stream<List<ForestProjectModel>> getProjectsStream() {
    return _collection.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (!data.containsKey('id')) {
          data['id'] = doc.id;
        }
        try {
          return ForestProjectModel.fromJson(data);
        } catch (e) {
          debugPrint('Error parsing ForestProjectModel ${doc.id}: $e');
          rethrow;
        }
      }).toList();
    });
  }

  /// Get stream of projects for a specific owner
  Stream<List<ForestProjectModel>> getProjectsByOwnerStream(String ownerId) {
    return _collection.where('ownerId', isEqualTo: ownerId).snapshots().map((
      snapshot,
    ) {
      final projects = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (!data.containsKey('id')) {
          data['id'] = doc.id;
        }
        return ForestProjectModel.fromJson(data);
      }).toList();
      projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return projects;
    });
  }

  /// Add a new project
  Future<void> addProject(ForestProjectModel project) async {
    try {
      await _collection.doc(project.id).set(project.toJson());
    } catch (e) {
      debugPrint('[ForestProjectService] addProject failed: $e');
      rethrow;
    }

    try {
      await FirestoreService.instance.notifyForestOwners(
        ownerId: project.ownerId,
        title: 'Dự án mới được phân công',
        body:
            'Admin đã phân dự án "${project.projectName}" cho chủ rừng. Loài cây: ${project.treeSpecies.isEmpty ? 'chưa cập nhật' : project.treeSpecies}, diện tích: ${project.totalAreaHa.toStringAsFixed(2)} ha.',
        type: NotificationType.project,
        relatedId: project.id,
      );
    } catch (e) {
      debugPrint('[ForestProjectService] project notification failed: $e');
    }
  }

  /// Update an existing project
  Future<void> updateProject(ForestProjectModel project) async {
    try {
      await _collection.doc(project.id).update(project.toJson());
    } catch (e) {
      debugPrint('[ForestProjectService] updateProject failed: $e');
      rethrow;
    }
  }

  /// Delete a project
  Future<void> deleteProject(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      debugPrint('[ForestProjectService] deleteProject failed: $e');
      rethrow;
    }
  }
}
