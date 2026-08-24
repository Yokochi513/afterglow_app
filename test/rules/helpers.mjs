import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';

/// リポジトリの firestore.rules をそのまま読む。cwd に依存しないよう
/// このファイルからの相対で解決する。
const rulesPath = fileURLToPath(new URL('../../firestore.rules', import.meta.url));

/// エミュレータの接続先。`firebase emulators:exec` が FIRESTORE_EMULATOR_HOST を
/// 立てるのでそれを使い、無ければ既定ポートにフォールバックする。
function emulatorAddress() {
  const [host = '127.0.0.1', port = '8080'] = (
    process.env.FIRESTORE_EMULATOR_HOST ?? ''
  ).split(':');
  return { host, port: Number(port) };
}

/// テスト用の Firestore 環境を作る。プロジェクトIDは `demo-` 始まりにして
/// 実プロジェクトへ接続しないようにする。
///
/// `node --test` はテストファイルを並列に実行するため、テストファイルごとに
/// 別のプロジェクトIDを渡すこと。同じIDを共有すると、片方の `clearFirestore()`
/// がもう片方の前提データを消してしまい、無関係なテストが落ちる。
export function createTestEnv(projectId) {
  return initializeTestEnvironment({
    projectId: `demo-afterglow-${projectId}`,
    firestore: { rules: readFileSync(rulesPath, 'utf8'), ...emulatorAddress() },
  });
}

/// ルールを無効化した状態で前提データを書き込む。承認状態の users や、
/// 他人が作った投稿など「テスト対象の操作の前提」を用意するのに使う。
export function seed(testEnv, write) {
  return testEnv.withSecurityRulesDisabled((context) => write(context.firestore()));
}

/// 承認済みユーザーとしての Firestore。
export function approved(testEnv, uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

/// 未ログイン状態の Firestore。
export function signedOut(testEnv) {
  return testEnv.unauthenticatedContext().firestore();
}
