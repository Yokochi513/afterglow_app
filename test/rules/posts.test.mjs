import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  increment,
  runTransaction,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import { approved, createTestEnv, seed } from './helpers.mjs';

/// posts コレクションのルール（§7.2）。
///
/// `fake_cloud_firestore` を使う Dart 側のテストはルールを一切評価しないため、
/// 「クライアントの書き込みがルールで拒否される」類の不具合はここでしか
/// 検出できない（Issue #62）。
describe('posts のルール', () => {
  let testEnv;

  /// author が投稿者、liker は別の承認済みユーザー、pending は未承認。
  before(async () => {
    testEnv = await createTestEnv();
  });

  after(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await seed(testEnv, async (db) => {
      await setDoc(doc(db, 'users/author'), { approved: true, role: 'member' });
      await setDoc(doc(db, 'users/liker'), { approved: true, role: 'member' });
      await setDoc(doc(db, 'users/pending'), { approved: false, role: 'member' });
      await setDoc(doc(db, 'users/admin'), { approved: true, role: 'admin' });
      await setDoc(doc(db, 'posts/post-1'), {
        userId: 'author',
        caption: 'テスト投稿',
        likeCount: 0,
      });
      // likeCount フィールドを持たない、フィールド追加前の投稿。
      await setDoc(doc(db, 'posts/post-legacy'), {
        userId: 'author',
        caption: '旧投稿',
      });
    });
  });

  describe('いいね（Issue #62）', () => {
    /// ReactionService.toggleReaction と同じ形のトランザクション。
    const toggle = (db, delta, write) =>
      runTransaction(db, async (transaction) => {
        write(transaction);
        transaction.update(doc(db, 'posts/post-1'), {
          likeCount: increment(delta),
        });
      });

    it('他人の投稿にいいねできる（reaction 作成 + likeCount +1）', async () => {
      const db = approved(testEnv, 'liker');
      await assertSucceeds(
        toggle(db, 1, (transaction) =>
          transaction.set(doc(db, 'posts/post-1/reactions/liker'), {
            userId: 'liker',
            type: 'like',
          }),
        ),
      );
    });

    it('他人の投稿のいいねを解除できる（reaction 削除 + likeCount -1）', async () => {
      const db = approved(testEnv, 'liker');
      await seed(testEnv, (adminDb) =>
        setDoc(doc(adminDb, 'posts/post-1/reactions/liker'), {
          userId: 'liker',
          type: 'like',
        }),
      );

      await assertSucceeds(
        toggle(db, -1, (transaction) =>
          transaction.delete(doc(db, 'posts/post-1/reactions/liker')),
        ),
      );
    });

    it('likeCount を持たない古い投稿にもいいねできる', async () => {
      const db = approved(testEnv, 'liker');
      await assertSucceeds(
        updateDoc(doc(db, 'posts/post-legacy'), { likeCount: increment(1) }),
      );
    });

    it('未承認ユーザーは likeCount を増やせない', async () => {
      const db = approved(testEnv, 'pending');
      await assertFails(
        updateDoc(doc(db, 'posts/post-1'), { likeCount: increment(1) }),
      );
    });
  });

  describe('likeCount の例外が他フィールドに波及しないこと', () => {
    it('他人の投稿の caption は書き換えられない', async () => {
      const db = approved(testEnv, 'liker');
      await assertFails(updateDoc(doc(db, 'posts/post-1'), { caption: '改ざん' }));
    });

    it('likeCount と一緒に他フィールドは書き換えられない', async () => {
      const db = approved(testEnv, 'liker');
      await assertFails(
        updateDoc(doc(db, 'posts/post-1'), {
          likeCount: increment(1),
          caption: '改ざん',
        }),
      );
    });

    it('likeCount を 2 以上まとめて増やせない', async () => {
      const db = approved(testEnv, 'liker');
      await assertFails(
        updateDoc(doc(db, 'posts/post-1'), { likeCount: increment(5) }),
      );
    });

    it('likeCount を任意の値に設定できない', async () => {
      const db = approved(testEnv, 'liker');
      await assertFails(updateDoc(doc(db, 'posts/post-1'), { likeCount: 999 }));
    });

    it('他人の投稿は削除できない', async () => {
      const db = approved(testEnv, 'liker');
      await assertFails(deleteDoc(doc(db, 'posts/post-1')));
    });
  });

  describe('投稿の基本操作', () => {
    it('承認済みユーザーは投稿を読める', async () => {
      const db = approved(testEnv, 'liker');
      await assertSucceeds(getDoc(doc(db, 'posts/post-1')));
    });

    it('未承認ユーザーは投稿を読めない', async () => {
      const db = approved(testEnv, 'pending');
      await assertFails(getDoc(doc(db, 'posts/post-1')));
    });

    it('投稿者は自分の投稿を編集・削除できる', async () => {
      const db = approved(testEnv, 'author');
      await assertSucceeds(updateDoc(doc(db, 'posts/post-1'), { caption: '編集後' }));
      await assertSucceeds(deleteDoc(doc(db, 'posts/post-1')));
    });

    it('管理者は他人の投稿を編集・削除できる', async () => {
      const db = approved(testEnv, 'admin');
      await assertSucceeds(updateDoc(doc(db, 'posts/post-1'), { caption: '編集後' }));
      await assertSucceeds(deleteDoc(doc(db, 'posts/post-1')));
    });

    it('他人の userId を騙って投稿を作成できない', async () => {
      const db = approved(testEnv, 'liker');
      await assertFails(
        setDoc(doc(db, 'posts/new-post'), { userId: 'author', caption: 'なりすまし' }),
      );
    });
  });

  describe('コメント（Issue #58 / #59）', () => {
    it('他人の投稿にもコメントできる', async () => {
      const db = approved(testEnv, 'liker');
      await assertSucceeds(
        setDoc(doc(db, 'posts/post-1/comments/c1'), {
          postId: 'post-1',
          userId: 'liker',
          text: 'いい写真ですね',
        }),
      );
    });

    it('コメント投稿者は commentCount を更新できない（実数表示にしている理由）', async () => {
      const db = approved(testEnv, 'liker');
      await assertFails(
        updateDoc(doc(db, 'posts/post-1'), { commentCount: increment(1) }),
      );
    });

    it('他人のコメントは編集・削除できない', async () => {
      const db = approved(testEnv, 'liker');
      await seed(testEnv, (adminDb) =>
        setDoc(doc(adminDb, 'posts/post-1/comments/c1'), {
          postId: 'post-1',
          userId: 'author',
          text: '投稿者のコメント',
        }),
      );

      await assertFails(
        updateDoc(doc(db, 'posts/post-1/comments/c1'), { text: '改ざん' }),
      );
      await assertFails(deleteDoc(doc(db, 'posts/post-1/comments/c1')));
    });
  });

  describe('リアクション（1ユーザー1ドキュメント・§3.5）', () => {
    it('自分の UID のリアクションドキュメントだけ書ける', async () => {
      const db = approved(testEnv, 'liker');
      await assertSucceeds(
        setDoc(doc(db, 'posts/post-1/reactions/liker'), {
          userId: 'liker',
          type: 'like',
        }),
      );
      await assertFails(
        setDoc(doc(db, 'posts/post-1/reactions/author'), {
          userId: 'author',
          type: 'like',
        }),
      );
    });
  });
});
