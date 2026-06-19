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

/**
 * users/{uid} 作成時に発火。承認トークンを生成し、管理者へ承認依頼メールを
 * 送る（mail コレクションへの書き込みを Trigger Email 拡張が送信する）。
 */
export const onUserCreated = functions
  .region(REGION)
  .firestore.document(`${USERS_COLLECTION}/{uid}`)
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    // 管理者が直接作成した等、既に承認済みなら何もしない
    if (data?.approved === true) {
      return;
    }

    const uid = context.params.uid as string;
    const username: string = data?.username ?? "(名前未設定)";
    const email: string = data?.email ?? "(メール未設定)";

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

    // 却下: 認証ユーザー・users ドキュメント・承認ドキュメントを削除
    await admin.auth().deleteUser(uid).catch(() => undefined);
    await db.collection(USERS_COLLECTION).doc(uid).delete().catch(() => undefined);
    await approvalRef.delete();
    res.status(200).send(htmlPage("ユーザーの登録を却下しました。"));
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
