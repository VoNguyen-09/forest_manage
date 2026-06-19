import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/firebase_options.dart';

/// AuthService — TV4
/// Bao gồm: signIn, signOut, getCurrentUser, getUserRole,
/// và stream authStateChanges để TV1 lắng nghe trạng thái đăng nhập.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Phát ra User? mỗi khi trạng thái auth thay đổi (login / logout).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Getters ───────────────────────────────────────────────────────────────

  /// Người dùng hiện tại (có thể null nếu chưa đăng nhập).
  User? get currentUser => _auth.currentUser;

  /// Cached UserModel (được set sau khi đăng nhập thành công).
  UserModel? currentUserModel;

  // ── Sign In / Out ─────────────────────────────────────────────────────────

  /// Đăng nhập bằng email + password.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Đăng xuất khỏi Firebase Auth.
  Future<void> signOut() async {
    currentUserModel = null;
    await _auth.signOut();
  }

  // ── Role Fetching ─────────────────────────────────────────────────────────

  /// Đọc role từ Firestore `users/{uid}`.
  /// Trả về [UserRole.forestWorker] nếu không tìm thấy.
  Future<UserRole> getUserRole() async {
    final uid = currentUser?.uid;
    if (uid == null) return UserRole.forestWorker;

    try {
      final snap = await _db
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get();

      final roleStr = snap.data()?['role'] as String?;
      return UserRole.values.firstWhere(
        (e) => e.name == roleStr,
        orElse: () => UserRole.forestWorker,
      );
    } catch (_) {
      return UserRole.forestWorker;
    }
  }

  /// Lấy [UserModel] đầy đủ của người dùng hiện tại từ Firestore.
  Future<UserModel?> getCurrentUserModel({bool throwOnError = false}) async {
    final uid = currentUser?.uid;
    if (uid == null) return null;

    try {
      final snap = await _db
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get();

      if (!snap.exists || snap.data() == null) return null;
      final data = snap.data()!..['uid'] = uid;
      final model = UserModel.fromJson(data);
      currentUserModel = model;
      return model;
    } catch (e) {
      if (throwOnError) rethrow;
      return null;
    }
  }

  // ── User Management ───────────────────────────────────────────────────────

  /// Tạo user mới trong Firebase Auth + ghi UserModel vào Firestore.
  Future<String> createUser({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
    String ownerId = '',
    String ownerName = '',
    String forestName = '',
    String managementProvince = '',
    double totalAreaHa = 0,
    String workerCode = '',
    String workerAssignment = '',
    List<String> assignedProjectIds = const [],
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final secondaryAuth = await _getUserCreationAuth();

    final cred = await secondaryAuth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    await secondaryAuth.signOut();

    final uid = cred.user!.uid;
    final now = DateTime.now();

    final model = UserModel(
      uid: uid,
      fullName: fullName,
      phone: phone,
      email: normalizedEmail,
      role: role,
      status: UserStatus.active,
      ownerId: ownerId,
      ownerName: ownerName,
      forestName: forestName,
      managementProvince: managementProvince,
      totalAreaHa: totalAreaHa,
      workerCode: workerCode,
      workerAssignment: workerAssignment,
      assignedProjectIds: assignedProjectIds,
      createdAt: now,
    );

    await _db
        .collection(FirestoreCollections.users)
        .doc(uid)
        .set(model.toJson());

    return uid;
  }

  /// Xóa user: xóa profile Firestore + tài khoản Firebase Auth.
  /// Dùng secondary app để xóa Auth mà không ảnh hưởng session hiện tại.
  Future<void> deleteUserWithCleanup(String uid, {String? email, String? password}) async {
    // 1. Xóa Firestore profile
    try {
      await _db.collection(FirestoreCollections.users).doc(uid).delete();
    } catch (e) {
      debugPrint('[AuthService] deleteUser - Firestore delete failed: $e');
    }

    // 2. Thử xóa Firebase Auth account qua secondary app (nếu có email)
    if (email != null && email.isNotEmpty && password != null) {
      try {
        final secondaryAuth = await _getUserCreationAuth();
        final cred = await secondaryAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        await cred.user?.delete();
        await secondaryAuth.signOut();
      } catch (e) {
        debugPrint('[AuthService] deleteUser - Auth delete via secondary failed: $e');
        // Non-critical – profile already deleted from Firestore
      }
    }
  }

  Future<FirebaseAuth> _getUserCreationAuth() async {
    const appName = 'userCreation';
    try {
      return FirebaseAuth.instanceFor(app: Firebase.app(appName));
    } catch (_) {
      final app = await Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return FirebaseAuth.instanceFor(app: app);
    }
  }
}
