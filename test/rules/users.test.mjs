import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import { approved, createTestEnv, seed, signedOut } from './helpers.mjs';

/// users と、承認状態（approved）による締め出しのルール（§7.2）。
///
/// 本番へルールを反映する際の最大のリスクは「承認済みのつもりのユーザーが
/// 締め出される」ことなので、承認済み / 未承認 / 未ログイン / 管理者の
/// 4 者について読み書きの可否を固定する（Issue #61）。
describe('users と承認状態のルール', () => {
  let testEnv;

  before(async () => {
    testEnv = await createTestEnv('users');
  });

  after(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await seed(testEnv, async (db) => {
      await setDoc(doc(db, 'users/member'), {
        username: 'member',
        approved: true,
        role: 'member',
      });
      await setDoc(doc(db, 'users/pending'), {
        username: 'pending',
        approved: false,
        role: 'member',
      });
      await setDoc(doc(db, 'users/admin'), {
        username: 'admin',
        approved: true,
        role: 'admin',
      });
      await setDoc(doc(db, 'posts/post-1'), {
        userId: 'member',
        caption: 'テスト投稿',
        likeCount: 0,
      });
      await setDoc(doc(db, 'albums/album-1'), { ownerId: 'member' });
      await setDoc(doc(db, 'events/event-1'), { organizerId: 'member' });
      await setDoc(doc(db, 'notifications/n-1'), { recipientId: 'member' });
      await setDoc(doc(db, 'registrationApprovals/pending'), { token: 'secret' });
      await setDoc(doc(db, 'mail/m-1'), { to: 'admin@example.com' });
    });
  });

  describe('ユーザードキュメントの読み取り', () => {
    it('ログイン済みなら未承認でも他人のユーザー情報を読める（投稿者名の表示に必要）', async () => {
      await assertSucceeds(getDoc(doc(approved(testEnv, 'pending'), 'users/member')));
    });

    it('未ログインでは読めない', async () => {
      await assertFails(getDoc(doc(signedOut(testEnv), 'users/member')));
    });
  });

  describe('新規登録', () => {
    it('本人が未承認・一般ロールで作成できる', async () => {
      const db = approved(testEnv, 'newbie');
      await assertSucceeds(
        setDoc(doc(db, 'users/newbie'), {
          username: 'newbie',
          approved: false,
          role: 'member',
        }),
      );
    });

    it('最初から承認済みとして作成できない', async () => {
      const db = approved(testEnv, 'newbie');
      await assertFails(
        setDoc(doc(db, 'users/newbie'), {
          username: 'newbie',
          approved: true,
          role: 'member',
        }),
      );
    });

    it('最初から管理者として作成できない', async () => {
      const db = approved(testEnv, 'newbie');
      await assertFails(
        setDoc(doc(db, 'users/newbie'), {
          username: 'newbie',
          approved: false,
          role: 'admin',
        }),
      );
    });

    it('他人の UID のドキュメントは作成できない', async () => {
      const db = approved(testEnv, 'newbie');
      await assertFails(
        setDoc(doc(db, 'users/someone-else'), {
          username: 'なりすまし',
          approved: false,
          role: 'member',
        }),
      );
    });
  });

  describe('プロフィール更新と権限昇格の防止', () => {
    it('本人はプロフィールを更新できる', async () => {
      const db = approved(testEnv, 'member');
      await assertSucceeds(
        updateDoc(doc(db, 'users/member'), { bio: 'よろしく', username: '新しい名前' }),
      );
    });

    it('未承認ユーザーも自分のプロフィールは更新できる（承認待ち中の名前変更）', async () => {
      const db = approved(testEnv, 'pending');
      await assertSucceeds(updateDoc(doc(db, 'users/pending'), { bio: '承認待ち' }));
    });

    it('自分を承認済みに書き換えられない', async () => {
      const db = approved(testEnv, 'pending');
      await assertFails(updateDoc(doc(db, 'users/pending'), { approved: true }));
    });

    it('自分を管理者に昇格できない', async () => {
      const db = approved(testEnv, 'member');
      await assertFails(updateDoc(doc(db, 'users/member'), { role: 'admin' }));
    });

    it('他人のプロフィールは更新できない', async () => {
      const db = approved(testEnv, 'member');
      await assertFails(updateDoc(doc(db, 'users/pending'), { bio: '改ざん' }));
    });

    it('管理者はユーザーを承認できる', async () => {
      const db = approved(testEnv, 'admin');
      await assertSucceeds(updateDoc(doc(db, 'users/pending'), { approved: true }));
    });

    it('一般ユーザーは自分のドキュメントも削除できない（削除は管理者のみ）', async () => {
      await assertFails(deleteDoc(doc(approved(testEnv, 'member'), 'users/member')));
      await assertSucceeds(deleteDoc(doc(approved(testEnv, 'admin'), 'users/member')));
    });
  });

  describe('未承認ユーザーの締め出し', () => {
    it('未承認ユーザーは投稿・アルバム・イベントを読めない', async () => {
      const db = approved(testEnv, 'pending');
      await assertFails(getDoc(doc(db, 'posts/post-1')));
      await assertFails(getDoc(doc(db, 'albums/album-1')));
      await assertFails(getDoc(doc(db, 'events/event-1')));
    });

    it('未承認ユーザーは投稿できない', async () => {
      const db = approved(testEnv, 'pending');
      await assertFails(
        setDoc(doc(db, 'posts/new-post'), { userId: 'pending', caption: '未承認' }),
      );
    });

    it('承認済みユーザーは投稿・アルバム・イベントを読める', async () => {
      const db = approved(testEnv, 'member');
      await assertSucceeds(getDoc(doc(db, 'posts/post-1')));
      await assertSucceeds(getDoc(doc(db, 'albums/album-1')));
      await assertSucceeds(getDoc(doc(db, 'events/event-1')));
    });

    it('未ログインでは投稿を読めない', async () => {
      await assertFails(getDoc(doc(signedOut(testEnv), 'posts/post-1')));
    });
  });

  describe('通知（§3.9）', () => {
    it('受信者本人だけが読める', async () => {
      await assertSucceeds(getDoc(doc(approved(testEnv, 'member'), 'notifications/n-1')));
      await assertFails(getDoc(doc(approved(testEnv, 'admin'), 'notifications/n-1')));
    });

    it('クライアントからは書き込めない（Functions / Admin SDK のみ）', async () => {
      await assertFails(
        setDoc(doc(approved(testEnv, 'admin'), 'notifications/n-2'), {
          recipientId: 'member',
        }),
      );
    });
  });

  describe('Functions 専用コレクション', () => {
    it('registrationApprovals は管理者でも読み書きできない', async () => {
      const db = approved(testEnv, 'admin');
      await assertFails(getDoc(doc(db, 'registrationApprovals/pending')));
      await assertFails(
        setDoc(doc(db, 'registrationApprovals/pending'), { token: '改ざん' }),
      );
    });

    it('mail（Trigger Email の送信キュー）は管理者でも読み書きできない', async () => {
      const db = approved(testEnv, 'admin');
      await assertFails(getDoc(doc(db, 'mail/m-1')));
      await assertFails(setDoc(doc(db, 'mail/m-2'), { to: 'attacker@example.com' }));
    });
  });
});
