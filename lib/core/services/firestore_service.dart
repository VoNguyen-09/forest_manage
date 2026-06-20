import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/models/log_entry_model.dart';
import 'package:forest_carbon_platform/core/models/plot_data_model.dart';
import 'package:forest_carbon_platform/core/models/carbon_result_model.dart';
import 'package:forest_carbon_platform/core/models/file_document_model.dart';
import 'package:forest_carbon_platform/core/models/worker_location_model.dart';
import 'package:forest_carbon_platform/core/models/notification_model.dart';
import 'package:flutter/foundation.dart';

/// FirestoreService — TV4
/// CRUD generic + các method cụ thể cho từng collection.
/// Mọi thành viên gọi qua FirestoreService.instance.method.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();
  static const String platformAdminNotificationUserId = 'platformAdmin';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ────────────────────────────────────────────────────────────────────────────
  // USERS
  // ────────────────────────────────────────────────────────────────────────────

  Future<UserModel?> getUser(String uid) async {
    final snap = await _db
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get();
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
    await _db.collection(FirestoreCollections.users).doc(uid).update({
      'status': status.name,
    });
  }

  Future<void> updateUserRole(String uid, UserRole role) async {
    await _db.collection(FirestoreCollections.users).doc(uid).update({
      'role': role.name,
    });
  }

  /// Admin: lấy toàn bộ danh sách user
  Future<List<UserModel>> listUsers() async {
    final snap = await _db.collection(FirestoreCollections.users).get();
    return snap.docs.map((d) {
      final data = d.data()..['uid'] = d.id;
      return UserModel.fromJson(data);
    }).toList();
  }

  Future<List<UserModel>> listPlatformAdmins() async {
    final users = await listUsers();
    return users
        .where(
          (user) =>
              user.role == UserRole.platformAdmin &&
              user.status == UserStatus.active,
        )
        .toList();
  }

  Future<List<UserModel>> listForestOwnerAccounts({String? ownerId}) async {
    final users = await listUsers();
    return users
        .where(
          (user) =>
              user.role == UserRole.forestOwner &&
              user.status == UserStatus.active &&
              (ownerId == null || ownerId.isEmpty || user.ownerId == ownerId),
        )
        .toList();
  }

  Stream<List<UserModel>> streamWorkersByOwner(String ownerId) {
    return _db
        .collection(FirestoreCollections.users)
        .where('ownerId', isEqualTo: ownerId)
        .where('role', isEqualTo: UserRole.forestWorker.name)
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs.map((doc) {
            final data = doc.data()..['uid'] = doc.id;
            return UserModel.fromJson(data);
          }).toList();
          users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return users;
        });
  }

  Stream<List<UserModel>> streamUsers() {
    return _db.collection(FirestoreCollections.users).snapshots().map((
      snapshot,
    ) {
      final users = snapshot.docs.map((doc) {
        final data = doc.data()..['uid'] = doc.id;
        return UserModel.fromJson(data);
      }).toList();
      users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return users;
    });
  }

  Future<void> deleteUserProfile(String uid) async {
    await _db.collection(FirestoreCollections.users).doc(uid).delete();
  }

  /// Tìm UserModel theo email (dùng sau khi tạo Auth để gán project)
  Future<UserModel?> findWorkerByEmail(String email) async {
    final snap = await _db
        .collection(FirestoreCollections.users)
        .where('email', isEqualTo: email.trim().toLowerCase())
        .where('role', isEqualTo: UserRole.forestWorker.name)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data()..['uid'] = snap.docs.first.id;
    return UserModel.fromJson(data);
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

  Future<String> saveUserProfile(UserModel user) async {
    final docRef = user.uid.isEmpty
        ? _db.collection(FirestoreCollections.users).doc()
        : _db.collection(FirestoreCollections.users).doc(user.uid);
    final userWithId = user.uid.isEmpty
        ? UserModel(
            uid: docRef.id,
            fullName: user.fullName,
            phone: user.phone,
            email: user.email,
            role: user.role,
            status: user.status,
            ownerId: user.ownerId,
            ownerName: user.ownerName,
            forestName: user.forestName,
            managementProvince: user.managementProvince,
            totalAreaHa: user.totalAreaHa,
            workerCode: user.workerCode,
            workerAssignment: user.workerAssignment,
            createdAt: user.createdAt,
          )
        : user;

    await docRef.set(userWithId.toJson(), SetOptions(merge: true));
    return docRef.id;
  }

  Future<ForestOwnerModel?> getForestOwner(String id) async {
    final snap = await _db
        .collection(FirestoreCollections.forestOwners)
        .doc(id)
        .get();
    if (!snap.exists) return null;
    final data = snap.data()!..['id'] = snap.id;
    return ForestOwnerModel.fromJson(data);
  }

  Stream<ForestOwnerModel?> streamForestOwner(String id) {
    return _db
        .collection(FirestoreCollections.forestOwners)
        .doc(id)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return null;
          final data = snap.data()!..['id'] = snap.id;
          return ForestOwnerModel.fromJson(data);
        });
  }

  Stream<List<ForestOwnerModel>> streamForestOwners() {
    return _db.collection(FirestoreCollections.forestOwners).snapshots().map((
      snap,
    ) {
      return snap.docs.map((d) {
        final data = d.data()..['id'] = d.id;
        return ForestOwnerModel.fromJson(data);
      }).toList();
    });
  }

  Future<String> saveForestOwner(ForestOwnerModel owner) async {
    if (owner.id.isEmpty) {
      final ref = await _ownersRef.add(owner.toJson()..remove('id'));
      return ref.id;
    } else {
      await _ownersRef
          .doc(owner.id)
          .set(owner.toJson(), SetOptions(merge: true));
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
    Query<Map<String, dynamic>> q = _projectsRef;
    if (ownerId != null) {
      q = q.where('ownerId', isEqualTo: ownerId);
    } else {
      q = q.orderBy('createdAt', descending: true);
    }
    final snap = await q.get();
    final projects = snap.docs.map((d) {
      final data = d.data()..['id'] = d.id;
      return ForestProjectModel.fromJson(data);
    }).toList();
    if (ownerId != null) {
      projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return projects;
  }

  Stream<List<ForestProjectModel>> streamForestProjects({String? ownerId}) {
    Query<Map<String, dynamic>> q = _projectsRef;
    if (ownerId != null) {
      q = q.where('ownerId', isEqualTo: ownerId);
    } else {
      q = q.orderBy('createdAt', descending: true);
    }
    return q.snapshots().map((snap) {
      final projects = snap.docs.map((d) {
        final data = d.data()..['id'] = d.id;
        return ForestProjectModel.fromJson(data);
      }).toList();
      if (ownerId != null) {
        projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      return projects;
    });
  }

  Future<ForestProjectModel?> getForestProject(String id) async {
    final snap = await _projectsRef.doc(id).get();
    if (!snap.exists) return null;
    final data = snap.data()!..['id'] = snap.id;
    return ForestProjectModel.fromJson(data);
  }

  Future<List<ForestProjectModel>> listForestProjectsByIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];

    // Firestore whereIn has a limit of 10 elements per query
    final List<ForestProjectModel> allProjects = [];

    // Chunk the ids array into chunks of 10
    for (var i = 0; i < ids.length; i += 10) {
      final end = (i + 10 < ids.length) ? i + 10 : ids.length;
      final chunk = ids.sublist(i, end);

      final snap = await _projectsRef
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      final projects = snap.docs.map((d) {
        final data = d.data()..['id'] = d.id;
        return ForestProjectModel.fromJson(data);
      }).toList();
      allProjects.addAll(projects);
    }

    return allProjects;
  }

  Future<String> saveForestProject(ForestProjectModel project) async {
    if (project.id.isEmpty) {
      final ref = await _projectsRef.add(project.toJson()..remove('id'));
      return ref.id;
    } else {
      await _projectsRef
          .doc(project.id)
          .set(project.toJson(), SetOptions(merge: true));
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
    // Avoid composite index by fetching without orderBy, then sorting in memory
    final snap = await _plotsRef.where('projectId', isEqualTo: projectId).get();
    final plots = snap.docs.map((d) {
      final data = d.data()..['id'] = d.id;
      return PlotDataModel.fromJson(data);
    }).toList();
    // Sort by createdAt descending in memory
    plots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return plots;
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
    // Build query without orderBy to avoid composite index requirement
    // Sorting and date filtering done in-memory instead
    Query<Map<String, dynamic>> q = _logRef;
    if (userId != null) q = q.where('userId', isEqualTo: userId);
    if (projectId != null) q = q.where('projectId', isEqualTo: projectId);

    final snap = await q.get();
    var entries = snap.docs.map((d) {
      final data = d.data()..['id'] = d.id;
      return LogEntryModel.fromJson(data);
    }).toList();

    // Filter by date range in memory
    if (from != null || to != null) {
      entries = entries.where((entry) {
        if (from != null && entry.date.isBefore(from)) return false;
        if (to != null && entry.date.isAfter(to)) return false;
        return true;
      }).toList();
    }

    // Sort by date descending in memory
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Future<String> saveLogEntry(LogEntryModel entry) async {
    if (entry.id.isEmpty) {
      final ref = await _logRef.add(entry.toJson()..remove('id'));
      final entryId = ref.id;

      // Send notification to forest owner
      try {
        final project = await getForestProject(entry.projectId);
        if (project != null) {
          await addNotification(
            userId: project.ownerId,
            title: 'Nhật ký hiện trường mới',
            body:
                'Nhân viên rừng vừa lưu một bản ghi hiện trường mới cho dự án "${project.projectName}"',
            type: NotificationType.fieldLog.name,
            relatedId: entryId,
          );
        }
      } catch (e) {
        debugPrint(
          '[FirestoreService] Failed to create notification for log entry: $e',
        );
      }

      return entryId;
    } else {
      final docRef = _logRef.doc(entry.id);
      final existing = await docRef.get();
      await docRef.set(entry.toJson(), SetOptions(merge: true));
      if (!existing.exists) {
        try {
          final project = await getForestProject(entry.projectId);
          if (project != null) {
            await addNotification(
              userId: project.ownerId,
              title: 'Nhật ký hiện trường mới',
              body:
                  'Nhân viên rừng vừa lưu một bản ghi hiện trường mới cho dự án "${project.projectName}"',
              type: NotificationType.fieldLog.name,
              relatedId: entry.id,
            );
          }
        } catch (e) {
          debugPrint(
            '[FirestoreService] Failed to create notification for offline log: $e',
          );
        }
      }
      return entry.id;
    }
  }

  Future<void> deleteLogEntry(String id) async {
    await _logRef.doc(id).delete();
  }

  Stream<List<LogEntryModel>> streamWorkerLogEntries(String userId) {
    return _logRef.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final logs = snap.docs.map((d) {
        final data = d.data()..['id'] = d.id;
        return LogEntryModel.fromJson(data);
      }).toList();
      logs.sort((a, b) => b.date.compareTo(a.date));
      return logs;
    });
  }

  Stream<List<LogEntryModel>> streamAllLogEntries() {
    return _logRef.snapshots().map((snap) {
      final logs = snap.docs.map((d) {
        final data = d.data()..['id'] = d.id;
        return LogEntryModel.fromJson(data);
      }).toList();
      logs.sort((a, b) => b.date.compareTo(a.date));
      return logs;
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CARBON RESULTS
  // ────────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _carbonRef =>
      _db.collection(FirestoreCollections.carbonResults);

  Future<String> saveCarbonResult(CarbonResultModel result) async {
    if (result.id.isEmpty) {
      final ref = await _carbonRef.add(result.toJson()..remove('id'));
      final resultId = ref.id;

      try {
        final project = await getForestProject(result.projectId);
        if (project != null) {
          final biomassFormatted = result.totalBiomassKg.toStringAsFixed(2);
          final carbonFormatted = result.carbonStockTon.toStringAsFixed(3);
          final co2eFormatted = result.co2eTon.toStringAsFixed(3);

          await notifyForestOwners(
            ownerId: project.ownerId,
            title: 'Tính toán Carbon hoàn tất',
            body:
                'Kết quả tính toán carbon cho dự án "${project.projectName}": Sinh khối $biomassFormatted kg, Carbon $carbonFormatted tC, CO₂e $co2eFormatted tCO₂e',
            type: NotificationType.carbon,
            relatedId: resultId,
          );
        }
      } catch (e) {
        debugPrint(
          '[FirestoreService] Failed to create notification for carbon result: $e',
        );
      }

      return resultId;
    } else {
      CarbonResultModel? previous;
      try {
        final oldSnap = await _carbonRef.doc(result.id).get();
        if (oldSnap.exists) {
          final data = oldSnap.data()!..['id'] = oldSnap.id;
          previous = CarbonResultModel.fromJson(data);
        }
      } catch (e) {
        debugPrint(
          '[FirestoreService] Failed to read previous carbon result: $e',
        );
      }

      await _carbonRef
        .doc(result.id)
        .set(result.toJson(), SetOptions(merge: true));

      if (previous == null) {
        try {
          final project = await getForestProject(result.projectId);
          if (project != null) {
            await notifyForestOwners(
              ownerId: project.ownerId,
              title: 'Tính toán Carbon hoàn tất',
              body:
                  'Kết quả tính toán carbon mới cho dự án "${project.projectName}": CO₂e ${result.co2eTon.toStringAsFixed(3)} tCO₂e',
              type: NotificationType.carbon,
              relatedId: result.id,
            );
          }
        } catch (e) {
          debugPrint(
            '[FirestoreService] Failed to create notification for offline carbon: $e',
          );
        }
      }

      final isSentToAdmin =
          result.status == CarbonApprovalStatus.approvedByOwner ||
          result.status == CarbonApprovalStatus.approvedByAdmin;
      final wasSentToAdmin =
          previous?.status == CarbonApprovalStatus.approvedByOwner ||
          previous?.status == CarbonApprovalStatus.approvedByAdmin;

      if (isSentToAdmin && !wasSentToAdmin) {
        try {
          final project = await getForestProject(result.projectId);
          final projectName = project?.projectName ?? result.projectId;
          await notifyAdmins(
            title: 'Dữ liệu tính toán Carbon mới',
            body:
                'Chủ rừng đã gửi dữ liệu carbon của dự án "$projectName": ${result.totalBiomassKg.toStringAsFixed(2)} kg sinh khối, ${result.carbonStockTon.toStringAsFixed(3)} tC, ${result.co2eTon.toStringAsFixed(3)} tCO₂e.',
            type: NotificationType.carbon,
            relatedId: result.id,
          );
        } catch (e) {
          debugPrint(
            '[FirestoreService] Failed to notify admins for carbon result: $e',
          );
        }
      }
      return result.id;
    }
  }

  Future<List<CarbonResultModel>> listCarbonResults({
    required String projectId,
  }) async {
    // Avoid composite index by fetching without orderBy, then sorting in memory
    final snap = await _carbonRef
        .where('projectId', isEqualTo: projectId)
        .get();
    final results = snap.docs.map((d) {
      final data = d.data()..['id'] = d.id;
      return CarbonResultModel.fromJson(data);
    }).toList();
    // Sort by calculatedAt descending in memory
    results.sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));
    return results;
  }

  Future<CarbonResultModel?> getLatestCarbonResult(String projectId) async {
    final results = await listCarbonResults(projectId: projectId);
    return results.isEmpty ? null : results.first;
  }

  Stream<List<CarbonResultModel>> streamCarbonResultsForProject(
    String projectId,
  ) {
    return _carbonRef.where('projectId', isEqualTo: projectId).snapshots().map((
      snap,
    ) {
      final results = snap.docs.map((d) {
        final data = d.data()..['id'] = d.id;
        return CarbonResultModel.fromJson(data);
      }).toList();
      results.sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));
      return results;
    });
  }

  Stream<List<CarbonResultModel>> streamAllCarbonResults() {
    return _carbonRef.snapshots().map((snap) {
      final results = snap.docs.map((d) {
        final data = d.data()..['id'] = d.id;
        return CarbonResultModel.fromJson(data);
      }).toList();
      results.sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));
      return results;
    });
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
      await _speciesRef
          .doc(sf.speciesId)
          .set(sf.toJson(), SetOptions(merge: true));
      return sf.speciesId;
    }
  }

  Future<void> deleteSpeciesFactor(String id) async {
    await _speciesRef.doc(id).delete();
  }

  Stream<List<SpeciesFactor>> streamSpeciesFactors() {
    return _speciesRef.orderBy('speciesName').snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data()..['speciesId'] = d.id;
        return SpeciesFactor.fromJson(data);
      }).toList();
    });
  }

  /// Get species factors filtered by species names (case-insensitive).
  /// Used to restrict workers to their project's tree species.
  Future<List<SpeciesFactor>> listSpeciesFactorsByNames(
    List<String> speciesNames,
  ) async {
    if (speciesNames.isEmpty) return <SpeciesFactor>[];

    final snap = await _speciesRef.orderBy('speciesName').get();
    final allFactors = <SpeciesFactor>[
      for (final d in snap.docs)
        SpeciesFactor.fromJson({...d.data(), 'speciesId': d.id}),
    ];

    // Filter by matching species names (case-insensitive)
    return allFactors
        .where(
          (factor) => speciesNames.any(
            (name) => name.toLowerCase() == factor.speciesName.toLowerCase(),
          ),
        )
        .toList();
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
        .map(
          (snap) => snap.docs.map((d) {
            final data = Map<String, dynamic>.from(d.data())..['id'] = d.id;
            return data;
          }).toList(),
        );
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
    if (userId.trim().isEmpty) return;
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

  Future<void> notifyAdmins({
    required String title,
    required String body,
    required NotificationType type,
    String? relatedId,
  }) async {
    await addNotification(
      userId: platformAdminNotificationUserId,
      title: title,
      body: body,
      type: type.name,
      relatedId: relatedId,
    );
  }

  Future<void> notifyForestOwners({
    String? ownerId,
    required String title,
    required String body,
    required NotificationType type,
    String? relatedId,
  }) async {
    List<UserModel> ownerAccounts = const [];
    try {
      ownerAccounts = await listForestOwnerAccounts(ownerId: ownerId);
    } catch (e) {
      debugPrint('[FirestoreService] Failed to resolve owner accounts: $e');
    }

    if (ownerAccounts.isNotEmpty) {
      for (final owner in ownerAccounts) {
        await addNotification(
          userId: owner.ownerId.isNotEmpty ? owner.ownerId : owner.uid,
          title: title,
          body: body,
          type: type.name,
          relatedId: relatedId,
        );
      }
      return;
    }

    if (ownerId != null && ownerId.isNotEmpty) {
      await addNotification(
        userId: ownerId,
        title: title,
        body: body,
        type: type.name,
        relatedId: relatedId,
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // FILE DOCUMENTS
  // ────────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _filesRef =>
      _db.collection(FirestoreCollections.files);

  Future<String> saveFileDocument(FileDocumentModel file) async {
    if (file.id.isEmpty) {
      final ref = await _filesRef.add(file.toJson()..remove('id'));
      await _notifyForNewFileDocument(file.copyWith(id: ref.id));
      return ref.id;
    }

    final docRef = _filesRef.doc(file.id);
    final existing = await docRef.get();
    await docRef.set(file.toJson(), SetOptions(merge: true));
    if (!existing.exists) {
      await _notifyForNewFileDocument(file);
    }
    return file.id;
  }

  Future<void> _notifyForNewFileDocument(FileDocumentModel file) async {
    try {
      final category = file.category.trim();
      final isAdminSubmission = file.status == 'approved';
      final uploader = file.uploadedByName.trim().isEmpty
          ? 'Người dùng'
          : file.uploadedByName.trim();
      final project = file.projectId.isEmpty
          ? null
          : await getForestProject(file.projectId);
      final projectName = project?.projectName ?? 'chưa chọn dự án';
      final ownerId = file.ownerId.isNotEmpty ? file.ownerId : project?.ownerId;

      if (category == 'Hình ảnh hiện trường' && isAdminSubmission) {
        await notifyAdmins(
          title: 'Báo cáo hình ảnh hiện trường mới',
          body:
              '$uploader đã gửi báo cáo hình ảnh hiện trường "${file.name}" cho dự án "$projectName".',
          type: NotificationType.fieldLog,
          relatedId: file.id,
        );
        return;
      }

      if (category == 'Báo cáo khảo sát' && isAdminSubmission) {
        await notifyAdmins(
          title: 'Báo cáo khảo sát mới',
          body:
              '$uploader đã gửi báo cáo khảo sát "${file.name}" cho dự án "$projectName".',
          type: NotificationType.survey,
          relatedId: file.id,
        );
        return;
      }

      if ((category == 'Hồ sơ pháp lý' || category == 'Hồ sơ dự án') &&
          isAdminSubmission) {
        await notifyForestOwners(
          ownerId: ownerId,
          title: 'Tài liệu mới từ Admin',
          body:
              'Admin đã tải lên $category "${file.name}" cho dự án "$projectName".',
          type: NotificationType.document,
          relatedId: file.id,
        );
      }
    } catch (e) {
      debugPrint('[FirestoreService] Failed to create file notification: $e');
    }
  }

  Future<void> updateFileStatus(String fileId, String status) async {
    final docRef = _filesRef.doc(fileId);
    final snap = await docRef.get();
    FileDocumentModel? previous;
    if (snap.exists) {
      final data = snap.data()!..['id'] = snap.id;
      previous = FileDocumentModel.fromJson(data);
    }

    final now = DateTime.now();
    await docRef.update({'status': status, 'updatedAt': now.toIso8601String()});

    if (status == 'approved' &&
        previous != null &&
        previous.status != 'approved') {
      await _notifyForNewFileDocument(
        previous.copyWith(status: status, updatedAt: now),
      );
    }
  }

  Future<void> deleteFileDocument(String id) async {
    await _filesRef.doc(id).delete();
  }

  Stream<List<FileDocumentModel>> streamFileDocuments({
    String? ownerId,
    String? projectId,
    bool excludePending = false,
  }) {
    // If ownerId is provided (forest owner), fetch both their documents and admin documents (ownerId='')
    if (ownerId != null && ownerId.isNotEmpty) {
      return Rx.combineLatest2(
        // Query 1: Documents for this specific owner
        _filesRef.where('ownerId', isEqualTo: ownerId).snapshots(),
        // Query 2: Admin documents (ownerId = '') visible to all
        _filesRef.where('ownerId', isEqualTo: '').snapshots(),
        (QuerySnapshot snap1, QuerySnapshot snap2) {
          final files = <FileDocumentModel>[];

          // Process documents from both queries
          for (var doc in [...snap1.docs, ...snap2.docs]) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            files.add(FileDocumentModel.fromJson(data));
          }

          // Remove duplicates (if any)
          final uniqueFiles = <String, FileDocumentModel>{};
          for (var file in files) {
            uniqueFiles[file.id] = file;
          }

          var resultFiles = uniqueFiles.values.toList();

          // Apply projectId filter if provided
          if (projectId != null && projectId.isNotEmpty) {
            resultFiles = resultFiles
                .where((f) => f.projectId == projectId)
                .toList();
          }

          if (excludePending) {
            resultFiles = resultFiles
                .where((f) => f.status != 'pending')
                .toList();
          }

          resultFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return resultFiles;
        },
      );
    }

    // For admins or when no ownerId is specified, use the original logic
    Query<Map<String, dynamic>> q = _filesRef;
    if (projectId != null && projectId.isNotEmpty) {
      q = q.where('projectId', isEqualTo: projectId);
    }
    return q.snapshots().map((snap) {
      var files = snap.docs.map((doc) {
        final data = doc.data()..['id'] = doc.id;
        return FileDocumentModel.fromJson(data);
      }).toList();
      if (excludePending) {
        files = files.where((f) => f.status != 'pending').toList();
      }
      files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return files;
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // WORKER LOCATIONS
  // ────────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _workerLocationRef =>
      _db.collection(FirestoreCollections.workerLocations);

  Future<void> saveWorkerLocation(WorkerLocationModel location) async {
    await _workerLocationRef
        .doc(location.workerId)
        .set(location.toJson(), SetOptions(merge: true));
  }

  Future<void> setWorkerOffline(String workerId) async {
    await _workerLocationRef.doc(workerId).set({
      'workerId': workerId,
      'isOnline': false,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Stream<List<WorkerLocationModel>> streamWorkerLocations({String? ownerId}) {
    Query<Map<String, dynamic>> q = _workerLocationRef;
    if (ownerId != null && ownerId.isNotEmpty) {
      q = q.where('ownerId', isEqualTo: ownerId);
    }
    return q.snapshots().map((snap) {
      final locations = snap.docs.map((d) {
        final data = d.data()..['workerId'] = d.id;
        return WorkerLocationModel.fromJson(data);
      }).toList();
      locations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return locations;
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
