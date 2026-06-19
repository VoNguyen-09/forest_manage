import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/core/models/notification_model.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final CollectionReference _collection = FirebaseFirestore.instance.collection(
    FirestoreCollections.notifications,
  );

  /// Get stream of notifications for a specific user, ordered by newest first
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _collection.where('userId', isEqualTo: userId).snapshots().map((
      snapshot,
    ) {
      final notifications = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (!data.containsKey('id')) {
          data['id'] = doc.id;
        }
        try {
          return NotificationModel.fromJson(data);
        } catch (e) {
          debugPrint('Error parsing NotificationModel ${doc.id}: $e');
          rethrow;
        }
      }).toList();

      // Sort by createdAt in memory to avoid composite index
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    });
  }

  Stream<List<NotificationModel>> getNotificationsForUserIdsStream(
    List<String> userIds,
  ) {
    final ids = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(10)
        .toList();

    if (ids.isEmpty) {
      return Stream.value(const []);
    }

    if (ids.length == 1) {
      return getNotificationsStream(ids.first);
    }

    return _collection.where('userId', whereIn: ids).snapshots().map((
      snapshot,
    ) {
      final notifications = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (!data.containsKey('id')) {
          data['id'] = doc.id;
        }
        try {
          return NotificationModel.fromJson(data);
        } catch (e) {
          debugPrint('Error parsing NotificationModel ${doc.id}: $e');
          rethrow;
        }
      }).toList();

      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    });
  }

  /// Get count of unread notifications for a specific user
  Stream<int> getUnreadCountStream(String userId) {
    return _collection.where('userId', isEqualTo: userId).snapshots().map((
      snapshot,
    ) {
      // Filter unread in memory to avoid composite index
      return snapshot.docs
          .where(
            (doc) => (doc.data() as Map<String, dynamic>)['isRead'] != true,
          )
          .length;
    });
  }

  /// Create a new notification
  Future<String> addNotification(NotificationModel notification) async {
    try {
      final ref = await _collection.add(notification.toJson()..remove('id'));
      return ref.id;
    } catch (e) {
      debugPrint('[NotificationService] addNotification failed: $e');
      rethrow;
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _collection.doc(notificationId).update({'isRead': true});
    } catch (e) {
      debugPrint('[NotificationService] markAsRead failed: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read for a specific user
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _collection
          .where('userId', isEqualTo: userId)
          .get();

      // Filter unread in memory
      final unreadDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['isRead'] != true;
      });

      for (final doc in unreadDocs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      debugPrint('[NotificationService] markAllAsRead failed: $e');
      rethrow;
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _collection.doc(notificationId).delete();
    } catch (e) {
      debugPrint('[NotificationService] deleteNotification failed: $e');
      rethrow;
    }
  }

  /// Delete all notifications for a specific user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final snapshot = await _collection
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('[NotificationService] deleteAllNotifications failed: $e');
      rethrow;
    }
  }

  /// Get a single notification by ID
  Future<NotificationModel?> getNotification(String notificationId) async {
    try {
      final doc = await _collection.doc(notificationId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return NotificationModel.fromJson(data);
    } catch (e) {
      debugPrint('[NotificationService] getNotification failed: $e');
      rethrow;
    }
  }
}
