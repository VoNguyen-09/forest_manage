import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/core/models/carbon_result_model.dart';
import 'package:forest_carbon_platform/core/models/file_document_model.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/core/models/gps_point.dart';
import 'package:forest_carbon_platform/core/models/log_entry_model.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/core/services/cloudinary_service.dart';
import 'package:forest_carbon_platform/core/services/firestore_service.dart';
import 'package:forest_carbon_platform/features/worker/services/field_log_pdf_service.dart';

/// Hàng đợi offline cho dữ liệu do Forest Worker tạo.
///
/// Không gọi Cloudinary hay Firestore khi offline. Dữ liệu và ảnh được giữ trong
/// Hive/app documents; khi kết nối trở lại, bản ghi được đồng bộ theo từng job.
class WorkerOfflineSyncService {
  WorkerOfflineSyncService._();

  static final WorkerOfflineSyncService instance = WorkerOfflineSyncService._();

  final Connectivity _connectivity = Connectivity();
  final FirestoreService _db = FirestoreService.instance;
  final CloudinaryService _cloudinary = CloudinaryService.instance;
  final FieldLogPdfService _pdfService = FieldLogPdfService.instance;
  final Uuid _uuid = const Uuid();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _retryTimer;
  Box<dynamic>? _logBox;
  Box<dynamic>? _carbonBox;
  Box<dynamic>? _cacheBox;
  final Map<String, List<SpeciesFactor>> _speciesFactorsMemory = {};
  String? _activeWorkerId;
  bool _initialized = false;
  bool _syncing = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _logBox = await Hive.openBox<dynamic>(HiveBoxes.pendingWorkerLogs);
    _carbonBox = await Hive.openBox<dynamic>(HiveBoxes.pendingWorkerCarbons);
    _cacheBox = await Hive.openBox<dynamic>(HiveBoxes.userCache);
    _initialized = true;

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (_activeWorkerId != null && _hasConnection(results)) {
        unawaited(syncPending());
      }
    });
  }

  Future<void> activateForWorker(String workerId) async {
    await initialize();
    _activeWorkerId = workerId;
    _startRetryTimer();
    await syncPending();
  }

  void deactivateWorker(String workerId) {
    if (_activeWorkerId == workerId) {
      _activeWorkerId = null;
      _retryTimer?.cancel();
      _retryTimer = null;
    }
  }

  Future<bool> isNetworkAvailable() async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  Future<void> queueLog({
    required UserModel user,
    required ForestProjectModel project,
    required DateTime date,
    required WorkType workType,
    required String description,
    required GpsPoint gps,
    required List<String> photoSourcePaths,
    String? jobId,
    List<String> uploadedPhotoUrls = const [],
    String pdfUrl = '',
  }) async {
    await initialize();
    _activeWorkerId = user.uid;
    final resolvedJobId = jobId ?? _uuid.v4();
    final cachedPhotos = await _persistPhotos(resolvedJobId, photoSourcePaths);
    await _logBox!.put(resolvedJobId, <String, dynamic>{
      'id': resolvedJobId,
      'user': user.toJson(),
      'project': project.toJson(),
      'date': date.toIso8601String(),
      'workType': workType.name,
      'description': description,
      'gps': gps.toJson(),
      'photoPaths': cachedPhotos,
      'photoUrls': uploadedPhotoUrls,
      'createdAt': DateTime.now().toIso8601String(),
      'pdfUrl': pdfUrl,
    });
  }

  Future<void> queueCarbon({
    required CarbonResultModel result,
  }) async {
    await initialize();
    _activeWorkerId = result.workerId;
    final jobId = result.id.isEmpty ? _uuid.v4() : result.id;
    await _carbonBox!.put(jobId, <String, dynamic>{
      'id': jobId,
      'result': result.copyWith(id: jobId).toJson(),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> cacheWorkerContext({
    required UserModel user,
    ForestOwnerModel? owner,
    required List<ForestProjectModel> projects,
    required List<ForestProjectModel> allOwnerProjects,
  }) async {
    await initialize();
    await _cacheBox!.put('worker_context_${user.uid}', <String, dynamic>{
      'user': user.toJson(),
      if (owner != null) 'owner': owner.toJson(),
      'projects': projects.map((project) => project.toJson()).toList(),
      'allOwnerProjects': allOwnerProjects
          .map((project) => project.toJson())
          .toList(),
    });
  }

  Future<WorkerOfflineContext?> getCachedWorkerContext(String uid) async {
    await initialize();
    final raw = _cacheBox!.get('worker_context_$uid');
    if (raw is! Map) return null;
    try {
      final data = Map<String, dynamic>.from(raw);
      return WorkerOfflineContext(
        user: UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
        owner: data['owner'] is Map
            ? ForestOwnerModel.fromJson(
                Map<String, dynamic>.from(data['owner'] as Map),
              )
            : null,
        projects: (data['projects'] as List? ?? const [])
            .map(
              (item) => ForestProjectModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        allOwnerProjects: (data['allOwnerProjects'] as List? ?? const [])
            .map(
              (item) => ForestProjectModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheSpeciesFactors(
    String projectId,
    List<SpeciesFactor> factors,
  ) async {
    await initialize();
    _speciesFactorsMemory[projectId] = List<SpeciesFactor>.from(factors);
    await _cacheBox!.put(
      'species_factors_$projectId',
      factors.map((factor) => factor.toJson()).toList(),
    );
  }

  Future<List<SpeciesFactor>> getCachedSpeciesFactors(String projectId) async {
    await initialize();
    final inMemory = _speciesFactorsMemory[projectId];
    if (inMemory != null && inMemory.isNotEmpty) {
      return List<SpeciesFactor>.from(inMemory);
    }
    final raw = _cacheBox!.get('species_factors_$projectId');
    if (raw is! List) return const [];
    try {
      final factors = raw
          .map(
            (item) => SpeciesFactor.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      if (factors.isNotEmpty) {
        _speciesFactorsMemory[projectId] = List<SpeciesFactor>.from(factors);
      }
      return factors;
    } catch (_) {
      return const [];
    }
  }

  /// Đồng bộ các bản ghi đang chờ. Timer định kỳ là lớp dự phòng cho trường hợp
  /// Android không phát sự kiện connectivity sau khi người dùng bật lại mạng.
  Future<WorkerSyncReport> syncPending() async {
    await initialize();
    final report = WorkerSyncReport();
    final activeWorkerId = _activeWorkerId;
    if (activeWorkerId == null ||
        activeWorkerId.isEmpty ||
        _syncing ||
        !await isNetworkAvailable()) {
      return report;
    }
    _syncing = true;
    try {
      for (final key in List<dynamic>.from(_carbonBox!.keys)) {
        final raw = _carbonBox!.get(key);
        if (raw is! Map) continue;
        try {
          final data = Map<String, dynamic>.from(raw);
          final result = CarbonResultModel.fromJson(
            Map<String, dynamic>.from(data['result'] as Map),
          );
          if (result.workerId != activeWorkerId) continue;
          await _db.saveCarbonResult(result);
          await _carbonBox!.delete(key);
          report.syncedCarbons++;
        } catch (error, stackTrace) {
          // Giữ job trong queue để thử lại lần kết nối tiếp theo.
          report.addError('carbon', error);
          debugPrint('[WorkerOfflineSync] Không đồng bộ được carbon: $error\n$stackTrace');
        }
      }

      for (final key in List<dynamic>.from(_logBox!.keys)) {
        final raw = _logBox!.get(key);
        if (raw is! Map) continue;
        try {
          final data = Map<String, dynamic>.from(raw);
          final user = Map<String, dynamic>.from(data['user'] as Map);
          if (user['uid'] != activeWorkerId) continue;
          await _syncLog(key, data);
          report.syncedLogs++;
        } catch (error, stackTrace) {
          // Giữ job cùng ảnh local để tránh mất dữ liệu khi upload dở dang.
          report.addError('log', error);
          debugPrint('[WorkerOfflineSync] Không đồng bộ được nhật ký: $error\n$stackTrace');
        }
      }
    } finally {
      _syncing = false;
    }
    return report;
  }

  void _startRetryTimer() {
    _retryTimer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(syncPending());
    });
  }

  /// Các bản ghi chờ được hiển thị ngay trên thiết bị, kể cả trước khi có mạng.
  Stream<List<PendingWorkerLog>> watchPendingLogs({
    required String userId,
    required String projectId,
  }) async* {
    await initialize();
    List<PendingWorkerLog> read() => _pendingLogsFor(userId, projectId);
    yield read();
    yield* _logBox!.watch().map((_) => read());
  }

  Stream<List<CarbonResultModel>> watchPendingCarbons({
    required String workerId,
    required String projectId,
  }) async* {
    await initialize();
    List<CarbonResultModel> read() => _pendingCarbonsFor(workerId, projectId);
    yield read();
    yield* _carbonBox!.watch().map((_) => read());
  }

  List<PendingWorkerLog> _pendingLogsFor(String userId, String projectId) {
    final logs = <PendingWorkerLog>[];
    for (final key in _logBox?.keys ?? const <dynamic>[]) {
      final raw = _logBox!.get(key);
      if (raw is! Map) continue;
      try {
        final data = Map<String, dynamic>.from(raw);
        final user = Map<String, dynamic>.from(data['user'] as Map);
        final project = Map<String, dynamic>.from(data['project'] as Map);
        if (user['uid'] != userId || project['id'] != projectId) continue;
        // Nhật ký đã có trên Firestore thì không hiển thị hai lần. Job được giữ
        // lại chỉ để retry PDF/tài liệu nền nếu Cloudinary đang lỗi.
        if (data['logSaved'] == true) continue;
        logs.add(PendingWorkerLog.fromQueue(data));
      } catch (_) {
        // Bỏ qua job hỏng, nhưng vẫn giữ trong queue để không tự ý mất dữ liệu.
      }
    }
    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs;
  }

  List<CarbonResultModel> _pendingCarbonsFor(String workerId, String projectId) {
    final results = <CarbonResultModel>[];
    for (final key in _carbonBox?.keys ?? const <dynamic>[]) {
      final raw = _carbonBox!.get(key);
      if (raw is! Map) continue;
      try {
        final data = Map<String, dynamic>.from(raw);
        final result = CarbonResultModel.fromJson(
          Map<String, dynamic>.from(data['result'] as Map),
        );
        if (result.workerId == workerId && result.projectId == projectId) {
          results.add(result);
        }
      } catch (_) {
        // Giữ job lỗi trong queue; sync sẽ ghi lỗi cụ thể vào debug console.
      }
    }
    results.sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));
    return results;
  }

  Future<void> _syncLog(dynamic key, Map<String, dynamic> data) async {
    final user = UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    final project = ForestProjectModel.fromJson(
      Map<String, dynamic>.from(data['project'] as Map),
    );
    final jobId = data['id'] as String;
    final photoPaths = List<String>.from(data['photoPaths'] as List? ?? const []);
    final photoUrls = List<String>.from(data['photoUrls'] as List? ?? const []);

    if (photoUrls.isEmpty) {
      final photoFiles = photoPaths
          .map((path) => File(path))
          .where((file) => file.existsSync())
          .toList();
      if (photoFiles.length != photoPaths.length || photoFiles.isEmpty) {
        throw StateError('Không tìm thấy ảnh local của nhật ký ngoại tuyến.');
      }
      final uploadedUrls = await _cloudinary.uploadImages(
        photoFiles,
        folder: 'field_logs/${project.id}',
      );
      data['photoUrls'] = uploadedUrls;
      await _logBox!.put(key, data);
    }

    final urls = List<String>.from(data['photoUrls'] as List? ?? const []);
    final now = DateTime.now();
    final entry = LogEntryModel(
      id: jobId,
      date: DateTime.parse(data['date'] as String),
      userId: user.uid,
      projectId: project.id,
      gps: GpsPoint.fromJson(Map<String, dynamic>.from(data['gps'] as Map)),
      workType: WorkType.values.firstWhere(
        (type) => type.name == data['workType'],
        orElse: () => WorkType.care,
      ),
      description: data['description'] as String? ?? '',
      photoUrls: urls,
      isSynced: true,
      createdAt: DateTime.parse(data['createdAt'] as String),
      syncedAt: now,
    );
    // PDF có thể cần retry riêng (ví dụ preset Cloudinary cho raw file chưa
    // được cấu hình). Ghi nhật ký trước và lưu marker để retry PDF không ghi
    // lại nhật ký hoặc gửi thông báo trùng cho chủ rừng.
    if (data['logSaved'] != true) {
      await _db.saveLogEntry(entry);
      data['logSaved'] = true;
      await _logBox!.put(key, data);
    }

    // PDF/file document là dữ liệu phụ trợ. Không để lỗi raw-upload PDF làm
    // nhật ký và thông báo chủ rừng bị coi là chưa đồng bộ.
    try {
      var pdfUrl = data['pdfUrl'] as String? ?? '';
      if (pdfUrl.isEmpty) {
        final photoFiles = photoPaths.map((path) => File(path)).toList();
        final pdfBytes = await _pdfService.buildFieldLogPdf(
          user: user,
          project: project,
          entry: entry,
          photoFiles: photoFiles,
        );
        final fileName = _buildFieldLogFileName(
          projectName: project.projectName,
          date: entry.date,
          logId: jobId,
        );
        pdfUrl = await _cloudinary.uploadBytes(
          pdfBytes,
          identifier: fileName,
          folder: 'field_log_pdfs/${project.id}',
          extension: '.pdf',
        );
        data['pdfUrl'] = pdfUrl;
        await _logBox!.put(key, data);
      }

      final fileName = _buildFieldLogFileName(
        projectName: project.projectName,
        date: entry.date,
        logId: jobId,
      );
      await _db.saveFileDocument(
        FileDocumentModel(
          id: 'offline-log-$jobId',
          name: fileName,
          category: 'Hình ảnh hiện trường',
          type: 'pdf',
          url: pdfUrl,
          ownerId: project.ownerId,
          projectId: project.id,
          uploadedBy: user.uid,
          uploadedByName: user.fullName.isNotEmpty ? user.fullName : user.email,
          source: 'workerLogbook',
          sourceLogId: jobId,
          status: 'pending',
          photoUrls: urls,
          createdAt: entry.createdAt,
          updatedAt: now,
        ),
      );

      await _deleteCachedPhotos(photoPaths);
      await _logBox!.delete(key);
    } catch (error, stackTrace) {
      data['pdfError'] = error.toString();
      await _logBox!.put(key, data);
      debugPrint(
        '[WorkerOfflineSync] Nhật ký đã đồng bộ, đang chờ retry PDF: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<List<String>> _persistPhotos(
    String jobId,
    List<String> sourcePaths,
  ) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'worker_offline_logs', jobId));
    await directory.create(recursive: true);
    final persisted = <String>[];
    for (var index = 0; index < sourcePaths.length; index++) {
      final source = File(sourcePaths[index]);
      if (!await source.exists()) {
        throw StateError('Không đọc được ảnh hiện trường đã chọn.');
      }
      final extension = p.extension(source.path).isEmpty
          ? '.jpg'
          : p.extension(source.path);
      final target = File(p.join(directory.path, 'photo_$index$extension'));
      await source.copy(target.path);
      persisted.add(target.path);
    }
    return persisted;
  }

  Future<void> _deleteCachedPhotos(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  String _buildFieldLogFileName({
    required String projectName,
    required DateTime date,
    required String logId,
  }) {
    final projectSlug = projectName
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final shortId = logId.replaceAll('-', '').substring(0, 8);
    return 'Hien_Truong_${projectSlug.isEmpty ? 'Du_An' : projectSlug}_${date.day}_${date.month}_${date.year}_$shortId.pdf';
  }
}

class WorkerOfflineContext {
  final UserModel user;
  final ForestOwnerModel? owner;
  final List<ForestProjectModel> projects;
  final List<ForestProjectModel> allOwnerProjects;

  const WorkerOfflineContext({
    required this.user,
    required this.owner,
    required this.projects,
    required this.allOwnerProjects,
  });
}

class WorkerSyncReport {
  int syncedLogs = 0;
  int syncedCarbons = 0;
  final List<String> errors = [];

  bool get hasChanges => syncedLogs > 0 || syncedCarbons > 0;
  bool get hasErrors => errors.isNotEmpty;

  void addError(String type, Object error) {
    errors.add('$type: $error');
  }
}

class PendingWorkerLog {
  final String id;
  final DateTime date;
  final WorkType workType;
  final String description;
  final int photoCount;

  const PendingWorkerLog({
    required this.id,
    required this.date,
    required this.workType,
    required this.description,
    required this.photoCount,
  });

  factory PendingWorkerLog.fromQueue(Map<String, dynamic> data) {
    return PendingWorkerLog(
      id: data['id'] as String,
      date: DateTime.parse(data['date'] as String),
      workType: WorkType.values.firstWhere(
        (type) => type.name == data['workType'],
        orElse: () => WorkType.care,
      ),
      description: data['description'] as String? ?? '',
      photoCount: (data['photoPaths'] as List? ?? const []).length,
    );
  }
}
