import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {randomBytes} from "crypto";

admin.initializeApp();

const db = admin.firestore();

// 1st gen 関数を使うことで承認リンクの URL を決定的にする
//   https://<region>-<project>.cloudfunctions.net/handleApproval
// Firestore トリガーはデータベース(default)と同じリージョンに置く必要がある。
// このプロジェクトの Firestore は asia-northeast2(大阪) にあるため揃える。
const REGION = "asia-northeast2";

// 承認依頼の送信先（管理者）。デプロイ時に環境変数で上書き可能。
const ADMIN_EMAIL = process.env.ADMIN_EMAIL ?? "yokochi5123@gmail.com";

const PROJECT_ID = process.env.GCLOUD_PROJECT ?? "flutter-afterglow";

const FUNCTION_BASE_URL =
  `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/handleApproval`;

// Trigger Email 拡張が読み取るコレクション
const MAIL_COLLECTION = "mail";
const USERS_COLLECTION = "users";
const APPROVALS_COLLECTION = "registrationApprovals";
const CONTESTS_COLLECTION = "contests";
const POSTS_COLLECTION = "posts";
const EVENTS_COLLECTION = "events";
const NOTIFICATIONS_COLLECTION = "notifications";

// 通知種別（docs/詳細設計.md §3.9）
type NotificationType = "reaction" | "comment" | "event_update";

// 通知メール・プッシュ通知から開く Web アプリの URL
const APP_URL =
  process.env.APP_URL ?? "https://yokochi513.github.io/afterglow_app/";

// メールアドレス等の個人情報を格納する非公開サブコレクション（本人のみ
// 読み書き可。firestore.rules 参照）のドキュメントパス
const PRIVATE_PROFILE_DOC = "private/profile";

// FCM 登録トークン（tokens 配列）を保持する非公開ドキュメント。
// クライアントの PushNotificationService が書き込む
const PRIVATE_MESSAGING_DOC = "private/messaging";

/**
 * users/{uid}/private/profile 作成時に発火。公開プロフィール
 * （users/{uid}）とあわせて登録内容を取得し、承認トークンを生成して
 * 管理者へ承認依頼メールを送る（mail コレクションへの書き込みを
 * Trigger Email 拡張が送信する）。
 *
 * AuthService.register はこの非公開ドキュメントと公開ドキュメントを
 * 同一バッチで作成するため、このトリガー発火時点で公開ドキュメントは
 * 既にコミット済みであることが保証される。
 */
export const onUserCreated = functions
  .region(REGION)
  .firestore.document(`${USERS_COLLECTION}/{uid}/${PRIVATE_PROFILE_DOC}`)
  .onCreate(async (snapshot, context) => {
    const uid = context.params.uid as string;
    const privateData = snapshot.data();

    const userSnap = await db.collection(USERS_COLLECTION).doc(uid).get();
    const userData = userSnap.data();

    // 管理者が直接作成した等、既に承認済みなら何もしない
    if (userData?.approved === true) {
      return;
    }

    const username: string = userData?.username ?? "(名前未設定)";
    const email: string = privateData?.email ?? "(メール未設定)";

    const token = randomBytes(32).toString("hex");

    await db.collection(APPROVALS_COLLECTION).doc(uid).set({
      token,
      email,
      username,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const approveUrl =
      `${FUNCTION_BASE_URL}?uid=${uid}&token=${token}&action=approve`;
    const rejectUrl =
      `${FUNCTION_BASE_URL}?uid=${uid}&token=${token}&action=reject`;

    const html = `
      <h2>新規ユーザー登録の承認依頼</h2>
      <p>以下のユーザーが登録しました。承認しますか？</p>
      <ul>
        <li><strong>ユーザー名:</strong> ${escapeHtml(username)}</li>
        <li><strong>メール:</strong> ${escapeHtml(email)}</li>
      </ul>
      <p>
        <a href="${approveUrl}"
           style="display:inline-block;padding:10px 20px;background:#5b3cc4;color:#fff;text-decoration:none;border-radius:6px;margin-right:8px;">
          承認する
        </a>
        <a href="${rejectUrl}"
           style="display:inline-block;padding:10px 20px;background:#c4423c;color:#fff;text-decoration:none;border-radius:6px;">
          却下する
        </a>
      </p>
    `;

    await db.collection(MAIL_COLLECTION).doc(uid).set({
      to: [ADMIN_EMAIL],
      message: {
        subject: `【Afterglow】新規登録の承認依頼: ${username}`,
        html,
      },
    });
  });

/**
 * 承認/却下リンクのクリックを処理する HTTPS エンドポイント。
 * registrationApprovals/{uid}.token と照合して操作を実行する。
 */
export const handleApproval = functions
  .region(REGION)
  .https.onRequest(async (req, res) => {
    const uid = String(req.query.uid ?? "");
    const token = String(req.query.token ?? "");
    const action = String(req.query.action ?? "");

    if (!uid || !token || (action !== "approve" && action !== "reject")) {
      res.status(400).send(htmlPage("無効なリクエストです。"));
      return;
    }

    const approvalRef = db.collection(APPROVALS_COLLECTION).doc(uid);
    const approvalSnap = await approvalRef.get();

    if (!approvalSnap.exists || approvalSnap.data()?.token !== token) {
      res
        .status(403)
        .send(htmlPage("リンクが無効か、既に処理済みです。"));
      return;
    }

    if (action === "approve") {
      await db.collection(USERS_COLLECTION).doc(uid).update({approved: true});
      await approvalRef.delete();
      res.status(200).send(htmlPage("ユーザーを承認しました。"));
      return;
    }

    // 却下: 認証ユーザー・users ドキュメント（公開/非公開）・承認ドキュメントを削除
    await admin.auth().deleteUser(uid).catch(() => undefined);
    await db
      .doc(`${USERS_COLLECTION}/${uid}/${PRIVATE_PROFILE_DOC}`)
      .delete()
      .catch(() => undefined);
    await db.collection(USERS_COLLECTION).doc(uid).delete().catch(() => undefined);
    await approvalRef.delete();
    res.status(200).send(htmlPage("ユーザーの登録を却下しました。"));
  });

/**
 * 投票締切を過ぎたコンテスト投稿の匿名解除を行う。
 * userId が空の投稿だけを対象にするため、再実行しても同じ投稿を重複更新しない。
 */
export const revealContestAuthors = functions
  .region(REGION)
  .pubsub.schedule("every 30 minutes")
  .timeZone("Asia/Tokyo")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const contests = await db
      .collection(CONTESTS_COLLECTION)
      .where("votingDeadline", "<=", now)
      .get();

    for (const contest of contests.docs) {
      const posts = await db
        .collection(POSTS_COLLECTION)
        .where("contestId", "==", contest.id)
        .where("userId", "==", "")
        .where("stayAnonymous", "==", false)
        .get();

      let batch = db.batch();
      let writes = 0;

      for (const post of posts.docs) {
        const author = await post.ref.collection("private").doc("author").get();
        const authorId = author.data()?.userId;
        if (typeof authorId !== "string" || authorId.length === 0) {
          continue;
        }

        batch.update(post.ref, {userId: authorId});
        writes++;

        if (writes === 450) {
          await batch.commit();
          batch = db.batch();
          writes = 0;
        }
      }

      if (writes > 0) {
        await batch.commit();
      }
    }
  });

/**
 * コンテスト投票（contests/{contestId}/votes/{voterId}）の増減に合わせて
 * 対象投稿の voteCount を更新する。
 *
 * voteCount はコンテスト参加者全員に見える集計値で、投票ドキュメントの
 * 実体（誰がどの投稿に投票したか）は本人と管理者しか読めない（firestore.rules
 * 参照）。クライアントに voteCount の直接更新を許すと得票数を不正に
 * 書き換えられてしまうため、Admin SDK 経由のこのトリガーだけが更新する
 * （firestore.rules 側は posts/{postId}.voteCount へのクライアント書き込みを
 * 一切許可しない）。
 */
export const onContestVoteChange = functions
  .region(REGION)
  .firestore.document(`${CONTESTS_COLLECTION}/{contestId}/votes/{voterId}`)
  .onWrite(async (change) => {
    const before = change.before.exists
      ? (change.before.data()?.postId as string | undefined)
      : undefined;
    const after = change.after.exists
      ? (change.after.data()?.postId as string | undefined)
      : undefined;

    if (before === after) {
      return;
    }

    await db.runTransaction(async (transaction) => {
      if (before) {
        transaction.update(db.collection(POSTS_COLLECTION).doc(before), {
          voteCount: admin.firestore.FieldValue.increment(-1),
        });
      }
      if (after) {
        transaction.update(db.collection(POSTS_COLLECTION).doc(after), {
          voteCount: admin.firestore.FieldValue.increment(1),
        });
      }
    });
  });

/**
 * 通知ドキュメント（notifications/{id}）を作成する。自分自身の操作による
 * 通知（自分の投稿への自分のいいね等）は作らない。
 */
async function createNotification(
  recipientId: string,
  actorId: string,
  type: NotificationType,
  sourceId: string,
): Promise<void> {
  if (!recipientId || !actorId || recipientId === actorId) {
    return;
  }
  await db.collection(NOTIFICATIONS_COLLECTION).add({
    recipientId,
    actorId,
    type,
    sourceId,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * 投稿の実投稿者 UID を返す。匿名期間中のコンテスト投稿は userId が空なので
 * posts/{postId}/private/author から解決する。
 */
async function resolvePostAuthorId(postId: string): Promise<string | null> {
  const postRef = db.collection(POSTS_COLLECTION).doc(postId);
  const post = await postRef.get();
  if (!post.exists) {
    return null;
  }
  const userId = post.data()?.userId;
  if (typeof userId === "string" && userId.length > 0) {
    return userId;
  }
  const author = await postRef.collection("private").doc("author").get();
  const authorId = author.data()?.userId;
  return typeof authorId === "string" && authorId.length > 0 ? authorId : null;
}

/**
 * いいね（posts/{postId}/reactions/{userId}）の作成時に投稿者へ通知する。
 */
export const onReactionCreated = functions
  .region(REGION)
  .firestore.document(`${POSTS_COLLECTION}/{postId}/reactions/{userId}`)
  .onCreate(async (_snapshot, context) => {
    const postId = context.params.postId as string;
    const actorId = context.params.userId as string;
    const recipientId = await resolvePostAuthorId(postId);
    if (recipientId) {
      await createNotification(recipientId, actorId, "reaction", postId);
    }
  });

/**
 * コメント（posts/{postId}/comments/{commentId}）の作成時に投稿者へ通知する。
 */
export const onCommentCreated = functions
  .region(REGION)
  .firestore.document(`${POSTS_COLLECTION}/{postId}/comments/{commentId}`)
  .onCreate(async (snapshot, context) => {
    const postId = context.params.postId as string;
    const actorId = snapshot.data()?.userId as string | undefined;
    const recipientId = await resolvePostAuthorId(postId);
    if (recipientId && actorId) {
      await createNotification(recipientId, actorId, "comment", postId);
    }
  });

// 参加者へ知らせるべきイベントの変更項目（updatedAt 等の付随更新は除く）
const EVENT_NOTIFY_FIELDS = [
  "title",
  "description",
  "locationName",
  "latitude",
  "longitude",
  "startAt",
  "endAt",
];

/**
 * イベント（events/{eventId}）の内容が更新されたら参加表明者へ通知する。
 * 更新できるのは主催者（または管理者）なので、actorId は主催者とする。
 */
export const onEventUpdated = functions
  .region(REGION)
  .firestore.document(`${EVENTS_COLLECTION}/{eventId}`)
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const changed = EVENT_NOTIFY_FIELDS.some(
      (field) => !isSameValue(before[field], after[field]),
    );
    if (!changed) {
      return;
    }

    const eventId = context.params.eventId as string;
    const organizerId = (after.organizerId as string | undefined) ?? "";
    const participants = await change.after.ref
      .collection("participants")
      .get();

    await Promise.all(
      participants.docs.map((participant) =>
        createNotification(
          participant.id,
          organizerId,
          "event_update",
          eventId,
        ),
      ),
    );
  });

function isSameValue(a: unknown, b: unknown): boolean {
  if (a instanceof admin.firestore.Timestamp &&
      b instanceof admin.firestore.Timestamp) {
    return a.isEqual(b);
  }
  return a === b;
}

/**
 * 通知の作成時に受信者の端末（ブラウザ）へプッシュ通知を送る（FCM）。
 * 無効になったトークンは users/{uid}/private/messaging から取り除く。
 */
export const onNotificationCreated = functions
  .region(REGION)
  .firestore.document(`${NOTIFICATIONS_COLLECTION}/{notificationId}`)
  .onCreate(async (snapshot) => {
    const data = snapshot.data();
    const recipientId = data.recipientId as string | undefined;
    if (!recipientId) {
      return;
    }

    const messagingRef = db.doc(
      `${USERS_COLLECTION}/${recipientId}/${PRIVATE_MESSAGING_DOC}`,
    );
    const tokens =
      ((await messagingRef.get()).data()?.tokens ?? []) as string[];
    if (tokens.length === 0) {
      return;
    }

    const actorName = await getUsername(data.actorId as string | undefined);
    const body = notificationMessage(data.type as string, actorName);

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {title: "Afterglow", body},
      data: {
        notificationId: snapshot.id,
        type: String(data.type ?? ""),
        sourceId: String(data.sourceId ?? ""),
      },
      webpush: {
        fcmOptions: {link: APP_URL},
        notification: {icon: `${APP_URL}icons/Icon-192.png`},
      },
    });

    const invalid = response.responses
      .map((result, index) => ({result, token: tokens[index]}))
      .filter(({result}) =>
        result.error?.code === "messaging/registration-token-not-registered" ||
        result.error?.code === "messaging/invalid-registration-token",
      )
      .map(({token}) => token);
    if (invalid.length > 0) {
      await messagingRef.update({
        tokens: admin.firestore.FieldValue.arrayRemove(...invalid),
      });
    }
  });

async function getUsername(uid: string | undefined): Promise<string> {
  if (!uid) {
    return "だれか";
  }
  const user = await db.collection(USERS_COLLECTION).doc(uid).get();
  const username = user.data()?.username;
  return typeof username === "string" && username.length > 0 ?
    username :
    "だれか";
}

/** 通知種別ごとの文面（クライアントの NotificationPage と揃える）。 */
function notificationMessage(type: string, actorName: string): string {
  switch (type) {
  case "reaction":
    return `${actorName}さんがあなたの投稿にいいねしました`;
  case "comment":
    return `${actorName}さんがあなたの投稿にコメントしました`;
  case "event_update":
    return "参加予定のイベントが更新されました";
  default:
    return "新しい通知があります";
  }
}

// 週次ダイジェストで本文に並べる通知の最大件数
const DIGEST_MAX_ITEMS = 20;

const WEEK_MILLIS = 7 * 24 * 60 * 60 * 1000;

/**
 * 週次の通知ダイジェストメール（PS_07）。毎週月曜 9:00（日本時間）に、
 * メール通知を on にしている承認済みユーザーへ、直近 1 週間の未読通知を
 * まとめて送る（mail コレクションへの書き込みを Trigger Email 拡張が送信する）。
 * 未読通知がないユーザーには送らない。
 */
export const sendWeeklyNotificationDigest = functions
  .region(REGION)
  .pubsub.schedule("every monday 09:00")
  .timeZone("Asia/Tokyo")
  .onRun(async () => {
    const now = Date.now();
    const since = now - WEEK_MILLIS;
    // 再実行されても同じ日のメールを二重送信しないよう、日付をドキュメント ID に含める
    const dateKey = new Date(now).toISOString().slice(0, 10);

    const users = await db
      .collection(USERS_COLLECTION)
      .where("approved", "==", true)
      .get();

    for (const user of users.docs) {
      const profile = (await db
        .doc(`${USERS_COLLECTION}/${user.id}/${PRIVATE_PROFILE_DOC}`)
        .get()).data();
      const email = profile?.email;
      // emailNotification の既定は true（docs/詳細設計.md §3.2.1）
      if (profile?.emailNotification === false ||
          typeof email !== "string" || email.length === 0) {
        continue;
      }

      // 等価条件のみにして複合インデックスを不要にし、期間はメモリ上で絞り込む
      const unread = await db
        .collection(NOTIFICATIONS_COLLECTION)
        .where("recipientId", "==", user.id)
        .where("isRead", "==", false)
        .get();
      const recent = unread.docs
        .map((doc) => doc.data())
        .filter((data) => createdAtMillis(data) >= since)
        .sort((a, b) => createdAtMillis(b) - createdAtMillis(a));
      if (recent.length === 0) {
        continue;
      }

      const items = await Promise.all(
        recent.slice(0, DIGEST_MAX_ITEMS).map(async (data) =>
          notificationMessage(
            data.type as string,
            await getUsername(data.actorId as string | undefined),
          ),
        ),
      );
      const more = recent.length - items.length;
      const username = (user.data().username as string | undefined) ?? "";

      const html = `
        <p>${escapeHtml(username)} さん</p>
        <p>この 1 週間に未読の通知が ${recent.length} 件あります。</p>
        <ul>
          ${items.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}
        </ul>
        ${more > 0 ? `<p>ほか ${more} 件</p>` : ""}
        <p>
          <a href="${APP_URL}"
             style="display:inline-block;padding:10px 20px;background:#5b3cc4;color:#fff;text-decoration:none;border-radius:6px;">
            Afterglow を開く
          </a>
        </p>
        <p style="color:#888;font-size:12px;">
          このメールはアプリの「通知」画面の「週次メール通知」で停止できます。
        </p>
      `;

      // create は既存ドキュメントがあると失敗するので、再実行時に送信済みの
      // メールを上書き（＝ Trigger Email 拡張による再送）しない
      await db
        .collection(MAIL_COLLECTION)
        .doc(`weeklyDigest_${user.id}_${dateKey}`)
        .create({
          to: [email],
          message: {
            subject: `【Afterglow】今週の通知（未読 ${recent.length} 件）`,
            html,
          },
        })
        .catch(() => undefined);
    }
  });

function createdAtMillis(data: admin.firestore.DocumentData): number {
  const createdAt = data.createdAt;
  return createdAt instanceof admin.firestore.Timestamp ?
    createdAt.toMillis() :
    0;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function htmlPage(message: string): string {
  return `<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Afterglow</title></head>
    <body style="font-family:sans-serif;text-align:center;padding:48px;">
    <h1>${escapeHtml(message)}</h1>
    </body></html>`;
}
