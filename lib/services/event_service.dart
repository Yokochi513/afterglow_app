import 'package:afterglow_app/models/event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// イベントの読み書きと参加表明を担うサービス（PS_06 / §6.5）。
/// イベントは `events/{eventId}`、参加表明は
/// `events/{eventId}/participants/{userId}` に保存する（§3.7 / §3.8）。
///
/// 閲覧は承認済みユーザー全員、作成・更新は主催者（`organizerId`）のみ、
/// 参加表明は本人のみという制約は Firestore ルール側で担保する（#18 / §7.2）。
/// 本サービスは主催者判定を [isOrganizedBy] として公開し、UI が編集導線の
/// 出し分けに使う。
class EventService {
  EventService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String eventsCollection = 'events';
  static const String participantsCollection = 'participants';

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection(eventsCollection);

  CollectionReference<Map<String, dynamic>> _participantsRef(String eventId) =>
      _eventsRef.doc(eventId).collection(participantsCollection);

  /// 全イベントを開催日（`startAt`）昇順に購読する（FR_05 / §5.7）。
  /// 承認済みユーザーであれば他ユーザーが主催するイベントも閲覧できる。
  Stream<List<Event>> getEvents() {
    return _eventsRef
        .orderBy('startAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Event.fromSnapshot(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// 単一イベントを購読する（詳細画面用）。存在しなければ null を流す。
  Stream<Event?> watchEvent(String eventId) {
    return _eventsRef.doc(eventId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return Event.fromSnapshot(snapshot.id, data);
    });
  }

  /// イベントを作成する。[event] の `id` が空文字なら Firestore が採番する。
  Future<bool> createEvent(Event event) async {
    try {
      final docRef = event.id.isEmpty
          ? _eventsRef.doc()
          : _eventsRef.doc(event.id);
      await docRef.set(event.toMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// イベントの内容を更新する。主催者のみ成功する（ルールで担保・PS_08 系）。
  ///
  /// `organizerId` と `createdAt` は作成時の値を正とするため書き換えない。
  /// 更新日時（`updatedAt`）は呼び出し時刻で打ち直す。
  Future<bool> updateEvent(Event event) async {
    try {
      await _eventsRef.doc(event.id).update({
        'title': event.title,
        'description': event.description,
        'locationName': event.locationName,
        'latitude': event.latitude,
        'longitude': event.longitude,
        'startAt': Timestamp.fromDate(event.startAt),
        'endAt': event.endAt == null ? null : Timestamp.fromDate(event.endAt!),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 参加表明をトグルする（PS_06）。
  ///
  /// `participants/{userId}` が無ければ作成（参加）、あれば削除（参加取消）する。
  /// ドキュメントの有無がそのまま参加状態を表すため、[comment] は参加時のみ
  /// 保存される。
  Future<void> toggleParticipation(
    String eventId,
    String userId,
    String? comment,
  ) async {
    final docRef = _participantsRef(eventId).doc(userId);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      await docRef.delete();
      return;
    }

    await docRef.set(
      EventParticipant(
        userId: userId,
        comment: comment,
        joinedAt: DateTime.now(),
      ).toMap(),
    );
  }

  /// 指定イベントの参加者を参加表明順（`joinedAt` 昇順）に購読する（§5.7）。
  Stream<List<EventParticipant>> getParticipants(String eventId) {
    return _participantsRef(eventId)
        .orderBy('joinedAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EventParticipant.fromSnapshot(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// 指定ユーザーが参加表明済みかどうかを購読する。参加ボタンの状態に使う。
  Stream<bool> watchIsParticipating(String eventId, String userId) {
    return _participantsRef(
      eventId,
    ).doc(userId).snapshots().map((snapshot) => snapshot.exists);
  }

  /// [event] をログイン中ユーザー [uid] が編集できるかどうか。
  /// ルールと同じ条件を UI 側で先回りして判定するためのヘルパー。
  bool isOrganizedBy(Event event, String? uid) =>
      uid != null && event.organizerId == uid;
}
