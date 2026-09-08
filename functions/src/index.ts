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

// メールアドレス等の個人情報を格納する非公開サブコレクション（本人のみ
// 読み書き可。firestore.rules 参照）のドキュメントパス
const PRIVATE_PROFILE_DOC = "private/profile";

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
