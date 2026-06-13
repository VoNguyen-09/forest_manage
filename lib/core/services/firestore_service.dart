import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/models/log_entry_model.dart';
import 'package:forest_carbon_platform/core/models/plot_data_model.dart';
import 'package:forest_carbon_platform/core/models/carbon_result_model.dart';

/// FirestoreService — TV4
/// CRUD generic + các method cụ thể cho từng collection.
/// Mọi thành viên gọi qua FirestoreService.instance.method.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ────────────────────────────────────────────────────────────────────────────
  // USERS
  // ────────────────────────────────────────────────────────────────────────────

  Future<UserModel?> getUser(String uid) async {
    final snap = await _db.collection(FirestoreCollections.users).doc(uid).get();
    if (!snap.exists) return null;
    final data = snap.data()!..['uid'] = snap.id;
    return UserModel.fromJson(data);
  }

  Future<void> saveUser(UserModel user) async {
    await _db
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .set(user.toJson(), SetOptions(merge: true));
  }

  Future<void> updateUserStatus(String uid, UserStatus status) async {
    await _db
        .collection(FirestoreCollections.users)
        .doc(uid)
        .update({'status': status.name});
  }

  Future<void> updateUserRole(String uid, UserRole role) async {
    await _db
        .collection(FirestoreCollections.users)
        .doc(uid)
        .update({'role': role.name});
  }

  /// Admin: lấy toàn bộ danh sách user
  Future<List<UserModel>> listUsers() async {
    final snap = await _db.collection(FirestoreCollections.users).get();
    return snap.docs.map((d) {
      final data = d.data()..['uid'] = d.id;
      return UserModel.fromJson(data);
    }).toList();
  }

  /// Alias requested by TV1
  Future<List<UserModel>> getAccounts() => listUsers();

  // ────────────────────────────────────────────────────────────────────────────
  // FOREST OWNERS
  // ────────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _ownersRef =>
      _db.collection(FirestoreCollections.forestOwners);

  Future<List<ForestOwnerModel>> listForestOwners() async {
    final snap = await _ownersRef.orderBy('ownerName').get();
    return snap.docs.map((d) {
      final data = d.data()..['id'] = d.id;
      return ForestOwnerModel.fromJson(data);
    }).toList();
  }

  Future<ForestOwnerModel?> getForestOwner(String id) async {
    final snap = await _ownersRef.doc(id).get();
    if (!snap.exists) return null;
    final data = snap.data()!..['id'] = snap.id;
    return ForestOwnerModel.fromJson(data);
  }

  Future<String> saveForestOwner(ForestOwnerModel owner) async {
    if (owner.id.isEmpty) {
      final ref = await _ownersRef.add(owner.toJson()..remove('id'));
      return ref.id;
    } else {
      await _ownersRef.doc(owner.id).set(owner.toJson(), SetOptions(merge: true));
      return owner.id;
    }
  }

  Future<void> deleteForestOwner(String id) async {
    await _ownersRef.doc(id).delete();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // FOREST PROJECTS
  // ────────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _projectsRef =>
      _db.collection(FirestoreCollections.forestProjects);

  Future<List<ForestProjectModel>> listForestProjects({String? ownerId}) async {
    Query<Map<String, dynamic>> q = _projectsRef.orderBy('createdAt', descending: true);
    if (ownerId != null) q = q.where('ownerId', isEqualTo: ownerId);
    final snap = await q.get();
    return snap.docs.map((d) {
      final data = d.data()..['id'] = d.id;
      return ForestProjectModel.fromJson(data);
    }).toList();
  }

  Stream<List<ForestProjectModel>> streamForestProjects({String? ownerId}) {
    Query<Map<String, dynamic>> q = _projectsRef.orderBy('createdAt', descending: true);
    if (ownerId != null) q = q.where('ownerId', isEqualTo: ownerId);
    return q.snapshots().map((snap) => snap.docs.map((d) {
          final data = d.data()..['id'] = d.id;
          return ForestProjectModel.fromJson(data);
        }).toList());
  }

  Future<ForestProjectModel?> getForestProject(String id) async {
    final snap = await _projectsRef.doc(id).get();
    if (!snap.exists) return null;
    final data = snap.data()!..['id'] = snap.id;
    return ForestProjectModel.fromJson(data);
  }

  Future<String> saveForestProject(ForestProjectModel project) async {
    if (project.id.isEmpty) {
      final ref = await _projectsRef.add(project.toJson()..remove('id'));
      return ref.id;
    } else {
      await _projectsRef.doc(project.id).set(project.toJson(), SetOptions(merge: true));
      return project.id;
    }
  }

  Future<void> deleteForestProject(String id) async {
    await _projectsRef.doc(id).delete();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // PLOTS
  // ────────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _plotsRef =>
      _db.collection(FirestoreCollections.plots);

  Future<List<PlotDataModel>> listPlots({required String projectId}) async {
    // Composite index: (projectId ASC, createdAt DESC)
    final snap = await _plotsRef
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) {
      final data = d.data()..['id'] = d.id;
      return PlotDataModel.fromJson(data);
    }).toList();
  }

  Future<PlotDataModel?> getPlot(String id) async {
    final snap = await _plotsRef.doc(id).get();
    if (!snap.exists) return null;
    final data = snap.data()!..['id'] = snap.id;
    return PlotDataModel.fromJson(data);
  }

  Future<String> savePlot(PlotDataModel plot) async {
    if (plot.id.isEmpty) {
      final ref = await _plotsRef.add(plot.toJson()..remove('id'));
      return ref.id;
    } else {
      await _plotsRef.doc(plot.id).set(plot.toJson(), SetOptions(merge: true));
      return plot.id;
    }
  }

  Future<void> deletePlot(String id) async {
    await _plotsRef.doc(id).delete();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // LOG ENTRIES
  // ────────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _logRef =>
      _db.collection(FirestoreCollections.logEntries);

  Future<List<LogEntryModel>> listLogEntries({
    String? userId,
    String? projectId,
    DateTime? from,
    DateTime? to,
  }) async {
    // Composite index: (userId ASC, date DESC)
    Query<Map<String, dynamic>> q = _logRef.orderBy('date', descending: true);
    if (userId != null) q = q.where('userId', isEqualTo: userId);
    if (projectId != null) q = q.where('projectId', isEqualTo: projectId);
    if (from != null) q = q.where('date', isGreaterThanOrEqualTo: from.toIso8601String());
    if (to != null) q = q.where('date', isLessThanOrEqualTo: to.toIso8601String());
    final snap = await q.get();
    return snap.docs.map((d) {
      final data = d.data()..['id'] = d.id;
      return LogEntryModel.fromJson(data);
    }).toList();
  }

  Future<String> saveLogEntry(LogEntryModel entry) async {
    if (entry.id.isEmpty) {
      final ref = await _logRef.add(entry.toJson()..remove('id'));
      return ref.id;
    } else {
      await _logRef.doc(entry.id).set(entry.toJson(), SetOptions(merge: true));
      return entry.id;
    }
  }

  Future<void> deleteLogEntry(String id) async {
    await _logRef.doc(id).delete();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CARBON RESULTS
  // ────────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _carbonRef =>
      _db.collection(FirestoreCollections.carbonResults);

  Future<String> saveCarbonResult(CarbonResultModel result) async {
    if (result.id.isEmpty) {
      final ref = await _carbonRef.add(result.toJson()..remove('id'));
      return ref.id;
    } else {
      await _carbonRef.doc(result.id).set(result.toJson(), SetOptions(merge: true));
      return result.id;
    }
  }

  Future<List<CarbonResultModel>> listCarbonResults({required String projectId}) async {
    // Composite index: (projectId ASC, calculatedAt DESC)
    final snap = await _carbonRef
        .where('projectId', isEqualTo: projectId)
        .orderBy('calculatedAt', descending: true)
        .get();
    return snap.docs.map((d) {
      final data = d.data()..['id'] = d.id;
      return CarbonResultModel.fromJson(data);
    }).toList();
  }

  Future<CarbonResultModel?> getLatestCarbonResult(String projectId) async {
    final results = await listCarbonResults(projectId: projectId);
    return results.isEmpty ? null : results.first;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // SPECIES FACTORS
  // ────────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _speciesRef =>
      _db.collection(FirestoreCollections.speciesFactors);

  Future<List<SpeciesFactor>> listSpeciesFactors() async {
    final snap = await _speciesRef.orderBy('speciesName').get();
    return snap.docs.map((d) {
      final data = d.data()..['speciesId'] = d.id;
      return SpeciesFactor.fromJson(data);
    }).toList();
  }

  Future<String> saveSpeciesFactor(SpeciesFactor sf) async {
    if (sf.speciesId.isEmpty) {
      final ref = await _speciesRef.add(sf.toJson()..remove('speciesId'));
      return ref.id;
    } else {
      await _speciesRef.doc(sf.speciesId).set(sf.toJson(), SetOptions(merge: true));
      return sf.speciesId;
    }
  }

  Future<void> deleteSpeciesFactor(String id) async {
    await _speciesRef.doc(id).delete();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // NOTIFICATIONS  (TV1 uses this via streamNotifications)
  // ────────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _notifRef =>
      _db.collection(FirestoreCollections.notifications);

  /// TV1 gọi method này để lắng nghe thông báo realtime.
  Stream<List<Map<String, dynamic>>> streamNotifications(String userId) {
    return _notifRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data())..['id'] = d.id;
              return data;
            }).toList());
  }

  Future<void> markNotificationRead(String notifId) async {
    await _notifRef.doc(notifId).update({'isRead': true});
  }

  Future<void> addNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
  }) async {
    await _notifRef.add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'relatedId': relatedId,
      'isRead': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // DASHBOARD DATA (For TV1)
  // ────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardData() async {
    final owners = await listForestOwners();
    final projects = await listForestProjects();
    
    double totalArea = 0;
    int totalTrees = 0;
    double totalCarbon = 0;
    
    for (var project in projects) {
      totalArea += project.totalAreaHa;
      
      final plots = await listPlots(projectId: project.id);
      for (var plot in plots) {
        for (var tree in plot.trees) {
          totalTrees += tree.quantity;
        }
      }
      
      final latestCarbon = await getLatestCarbonResult(project.id);
      if (latestCarbon != null) {
        totalCarbon += latestCarbon.co2eTon;
      }
    }

    return {
      'totalOwners': owners.length,
      'totalProjects': projects.length,
      'totalAreaHa': totalArea,
      'totalTrees': totalTrees,
      'totalCarbonCo2e': totalCarbon,
    };
  }
}
