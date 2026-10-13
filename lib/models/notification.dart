import 'package:cloud_firestore/cloud_firestore.dart';

/// アプリ内通知（PS_07 / §3.9）。`notifications/{notificationId}` に保存される。
///
/// 生成は Cloud Functions（リアクション・コメント・イベント更新のトリガー）が
/// Admin SDK で行い、クライアントは受信者本人として読み取りと既読化のみ行う。
/// イミュータブル。
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.type,
    required this.sourceId,
    this.isRead = false,
    required this.createdAt,
  });

  /// 自分の投稿へのリアクション。[sourceId] は postId。
  static const String typeReaction = 'reaction';

  /// 自分の投稿へのコメント。[sourceId] は postId。
  static const String typeComment = 'comment';

  /// 参加表明したイベントの更新。[sourceId] は eventId。
  static const String typeEventUpdate = 'event_update';

  final String id;

  /// 受信者の UID（クエリに使用）。
  final String recipientId;

  /// 通知のトリガーとなったユーザーの UID。
  final String actorId;

  /// [typeReaction] / [typeComment] / [typeEventUpdate] のいずれか。
  final String type;

  /// 対象の postId または eventId。
  final String sourceId;

  final bool isRead;

  final DateTime createdAt;

  /// 遷移先が投稿（postId）かどうか。
  bool get targetsPost => type == typeReaction || type == typeComment;

  /// 遷移先がイベント（eventId）かどうか。
  bool get targetsEvent => type == typeEventUpdate;

  factory AppNotification.fromSnapshot(
    String id,
    Map<String, dynamic> document,
  ) {
    return AppNotification(
      id: id,
      recipientId: document['recipientId'] ?? '',
      actorId: document['actorId'] ?? '',
      type: document['type'] ?? '',
      sourceId: document['sourceId'] ?? '',
      isRead: document['isRead'] ?? false,
      createdAt:
          (document['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientId': recipientId,
      'actorId': actorId,
      'type': type,
      'sourceId': sourceId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
