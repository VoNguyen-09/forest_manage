import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';

/// AuthService — TV4
/// Bao gồm: signIn, signOut, getCurrentUser, getUserRole, OTP email flow,
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

  // ── Sign In / Out ─────────────────────────────────────────────────────────

  /// Đăng nhập bằng email + password.
  /// Trả về [UserCredential] hoặc ném [FirebaseAuthException].
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
  Future<UserModel?> getCurrentUserModel() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;

    try {
      final snap = await _db
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get();

      if (!snap.exists || snap.data() == null) return null;
      final data = snap.data()!..['uid'] = uid;
      return UserModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  // ── Password Reset (OTP flow) ─────────────────────────────────────────────

  /// Gửi email đặt lại mật khẩu — Firebase dùng link, hoạt động như OTP flow.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Đổi mật khẩu sau khi đăng nhập (yêu cầu re-authenticate nếu token cũ).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'Không tìm thấy người dùng.',
      );
    }

    // Re-authenticate
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  // ── User Management (Admin only) ──────────────────────────────────────────

  /// Tạo user mới trong Firebase Auth + ghi UserModel vào Firestore.
  /// Chỉ Platform Admin mới được gọi.
  Future<String> createUser({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
  }) async {
    // Tạo tài khoản Firebase Auth
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = cred.user!.uid;
    final now = DateTime.now();

    final model = UserModel(
      uid: uid,
      fullName: fullName,
      phone: phone,
      email: email.trim(),
      role: role,
      status: UserStatus.active,
      createdAt: now,
    );

    // Lưu vào Firestore
    await _db
        .collection(FirestoreCollections.users)
        .doc(uid)
        .set(model.toJson());

    return uid;
  }
}
