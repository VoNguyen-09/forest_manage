import 'package:forest_carbon_platform/core/models/user_model.dart';

class LocalAccountStore {
  LocalAccountStore._();
  static final LocalAccountStore instance = LocalAccountStore._();

  Map<String, dynamic>? _currentAccount;

  final List<Map<String, dynamic>> _accounts = [
    {
      'id': '1',
      'name': 'Nguyen Van Admin',
      'email': 'admin@gmail.com',
      'password': '123456',
      'role': UserRole.platformAdmin,
      'status': UserStatus.active,
      'date': '01/01/2026',
    },
    {
      'id': '2',
      'name': 'Quang Minh',
      'email': 'quangminh@gmail.com',
      'password': 'owner123',
      'role': UserRole.forestOwner,
      'ownerId': 'owner-quang-minh',
      'ownerName': 'Quang Minh',
      'forestName': 'Rung Quang Minh',
      'managementProvince': 'Dak Lak',
      'totalAreaHa': 192.0,
      'status': UserStatus.active,
      'date': '15/02/2026',
    },
    {
      'id': '4',
      'name': 'Trong Nhan',
      'email': 'trongnhan@gmail.com',
      'password': 'owner123',
      'role': UserRole.forestOwner,
      'ownerId': 'owner-trong-nhan',
      'ownerName': 'Trong Nhan',
      'forestName': 'Rung Trong Nhan',
      'managementProvince': 'Dak Lak',
      'totalAreaHa': 508.3,
      'status': UserStatus.active,
      'date': '16/02/2026',
    },
    {
      'id': '3',
      'name': 'Le Van Forest Worker',
      'email': 'levanforestworker@gmail.com',
      'password': 'worker123',
      'role': UserRole.forestWorker,
      'status': UserStatus.active,
      'date': '20/03/2026',
    },
  ];

  List<Map<String, dynamic>> get accounts => List.unmodifiable(_accounts);
  Map<String, dynamic>? get currentAccount => _currentAccount;

  Map<String, dynamic>? authenticate({
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    for (final account in _accounts) {
      final accountEmail = (account['email'] as String).trim().toLowerCase();
      final passwordMatches = account['password'] == password ||
          (accountEmail == 'admin@gmail.com' && password == 'admin123');
      if (accountEmail == normalizedEmail && passwordMatches) {
        if (account['status'] == UserStatus.locked) return null;
        _currentAccount = account;
        return account;
      }
    }
    return null;
  }

  void signOut() {
    _currentAccount = null;
  }

  void saveAccount(Map<String, dynamic> account) {
    final id = account['id'] as String?;
    if (id == null) {
      _accounts.insert(0, {
        ...account,
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'date': _formatToday(),
      });
      return;
    }

    final index = _accounts.indexWhere((item) => item['id'] == id);
    if (index == -1) {
      _accounts.insert(0, account);
    } else {
      _accounts[index] = {
        ..._accounts[index],
        ...account,
      };
    }
  }

  void deleteAccount(String id) {
    _accounts.removeWhere((account) => account['id'] == id);
  }

  void toggleStatus(String id) {
    final index = _accounts.indexWhere((account) => account['id'] == id);
    if (index == -1) return;
    final current = _accounts[index]['status'] as UserStatus;
    _accounts[index]['status'] =
        current == UserStatus.active ? UserStatus.locked : UserStatus.active;
  }

  bool emailExists(String email, {String? exceptId}) {
    final normalizedEmail = email.trim().toLowerCase();
    return _accounts.any((account) {
      if (exceptId != null && account['id'] == exceptId) return false;
      return (account['email'] as String).trim().toLowerCase() == normalizedEmail;
    });
  }

  String ownerEmailFromName(String ownerName) {
    final normalized = _removeVietnameseMarks(ownerName)
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$normalized@gmail.com';
  }

  String _removeVietnameseMarks(String input) {
    const vietnamese = {
      'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a',
      'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a',
      'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a',
      'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
      'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
      'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',
      'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o',
      'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o',
      'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',
      'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
      'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',
      'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
      'đ': 'd',
    };

    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(vietnamese[char] ?? char);
    }
    return buffer.toString();
  }

  String _formatToday() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    return '$day/$month/${now.year}';
  }
}
