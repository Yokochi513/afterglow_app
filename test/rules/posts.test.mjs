import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  increment,
  runTransaction,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
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
    testEnv = await createTestEnv('posts');
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

  describe('コンテスト投稿と投票', () => {
    const contestWindow = () => {
      const now = Date.now();
      return {
        entryDeadline: Timestamp.fromDate(new Date(now + 60 * 60 * 1000)),
        votingDeadline: Timestamp.fromDate(new Date(now + 2 * 60 * 60 * 1000)),
      };
    };

    it('エントリー期間中は userId が空のコンテスト投稿を作成できる', async () => {
      const db = approved(testEnv, 'author');
      const { entryDeadline, votingDeadline } = contestWindow();
      await seed(testEnv, (adminDb) =>
        setDoc(doc(adminDb, 'contests/contest-1'), {
          creatorId: 'author',
          title: 'contest',
          entryLimitVersion: 1,
          entryDeadline,
          votingDeadline,
        }),
      );

      const batch = writeBatch(db);
      batch.set(doc(db, 'posts/contest-post'), {
          userId: '',
          contestId: 'contest-1',
          stayAnonymous: false,
          voteCount: 0,
          caption: 'entry',
          imageUrls: ['photo.jpg'],
        });
      batch.set(doc(db, 'posts/contest-post/private/author'), {
          userId: 'author',
        });
      batch.set(doc(db, 'contests/contest-1/entries/author'), {postId: 'contest-post'});
      await assertSucceeds(batch.commit());

      const duplicate = writeBatch(db);
      duplicate.set(doc(db, 'posts/duplicate'), {
        userId: '', contestId: 'contest-1', voteCount: 0,
        imageUrls: ['photo.jpg'], stayAnonymous: false,
      });
      duplicate.set(doc(db, 'posts/duplicate/private/author'), {userId: 'author'});
      duplicate.set(doc(db, 'contests/contest-1/entries/author'), {postId: 'duplicate'});
      await assertFails(duplicate.commit());
      await assertFails(getDoc(doc(approved(testEnv, 'liker'), 'contests/contest-1/entries/author')));
    });

    it('エントリー締切後はコンテスト投稿を作成できない', async () => {
      const db = approved(testEnv, 'author');
      const now = Date.now();
      await seed(testEnv, (adminDb) =>
        setDoc(doc(adminDb, 'contests/contest-1'), {
          creatorId: 'author',
          title: 'contest',
          entryDeadline: Timestamp.fromDate(new Date(now - 60 * 1000)),
          votingDeadline: Timestamp.fromDate(new Date(now + 60 * 60 * 1000)),
        }),
      );

      await assertFails(
        setDoc(doc(db, 'posts/late-contest-post'), {
          userId: '',
          contestId: 'contest-1',
          stayAnonymous: false,
          voteCount: 0,
          caption: 'late',
        }),
      );
    });

    it('写真枚数と匿名維持を検証し、削除後は再エントリーできる', async () => {
      const db = approved(testEnv, 'author');
      await seed(testEnv, (adminDb) => setDoc(doc(adminDb, 'contests/limited'), {
        creatorId: 'author', title: 'limited', ...contestWindow(),
        maxImages: 2, entryLimitVersion: 1,
      }));
      const submit = (id, imageUrls, stayAnonymous = false) => {
        const batch = writeBatch(db);
        batch.set(doc(db, `posts/${id}`), {
          userId: '', contestId: 'limited', voteCount: 0, imageUrls, stayAnonymous,
        });
        batch.set(doc(db, `posts/${id}/private/author`), {userId: 'author'});
        batch.set(doc(db, 'contests/limited/entries/author'), {postId: id});
        return batch.commit();
      };
      await assertFails(submit('empty', []));
      await assertFails(submit('over', ['1.jpg', '2.jpg', '3.jpg']));
      await assertFails(submit('anonymous', ['1.jpg'], true));
      await assertSucceeds(submit('valid', ['1.jpg', '2.jpg']));
      await assertFails(updateDoc(doc(db, 'posts/valid'), {imageUrls: []}));
      await assertFails(updateDoc(doc(db, 'posts/valid'), {contestId: null, userId: 'author'}));
      await assertSucceeds(deleteDoc(doc(db, 'posts/valid')));
      await assertSucceeds(submit('replacement', ['1.jpg']));
    });

    it('主催者と管理者だけが削除でき、写真上限は1〜10枚に限定する', async () => {
      const authorDb = approved(testEnv, 'author');
      const otherDb = approved(testEnv, 'liker');
      const adminDb = approved(testEnv, 'admin');
      const ref = doc(authorDb, 'contests/manage');
      const contest = {creatorId: 'author', title: 'managed', ...contestWindow(), entryLimitVersion: 1};
      for (const maxImages of [0, 11, 1.5, '2']) {
        await assertFails(setDoc(ref, {...contest, maxImages}));
      }
      await assertSucceeds(setDoc(ref, {...contest, maxImages: 3}));
      await assertFails(updateDoc(doc(otherDb, 'contests/manage'), {maxImages: 2}));
      await assertSucceeds(updateDoc(ref, {maxImages: 5}));
      await assertFails(updateDoc(ref, {maxImages: 0}));
      await assertFails(deleteDoc(doc(otherDb, 'contests/manage')));
      await assertSucceeds(deleteDoc(doc(adminDb, 'contests/manage')));
      await assertSucceeds(setDoc(ref, contest));
      await assertSucceeds(deleteDoc(ref));
    });

    it('旧コンテストは参加履歴の移行完了まで新規エントリーを許可しない', async () => {
      const db = approved(testEnv, 'author');
      await seed(testEnv, (adminDb) => setDoc(doc(adminDb, 'contests/legacy'), {
        creatorId: 'author', ...contestWindow(),
      }));
      const batch = writeBatch(db);
      batch.set(doc(db, 'posts/legacy-new'), {
        userId: '', contestId: 'legacy', voteCount: 0, imageUrls: ['1.jpg'],
      });
      batch.set(doc(db, 'posts/legacy-new/private/author'), {userId: 'author'});
      batch.set(doc(db, 'contests/legacy/entries/author'), {postId: 'legacy-new'});
      await assertFails(batch.commit());
      await assertFails(updateDoc(doc(db, 'contests/legacy'), {entryLimitVersion: 1}));
    });

    it('匿名投稿の実投稿者は本人と管理者だけが読める', async () => {
      const authorDb = approved(testEnv, 'author');
      const likerDb = approved(testEnv, 'liker');
      const adminDb = approved(testEnv, 'admin');
      await seed(testEnv, (adminDb) =>
        setDoc(doc(adminDb, 'posts/contest-post/private/author'), {
          userId: 'author',
        }),
      );

      await assertSucceeds(getDoc(doc(authorDb, 'posts/contest-post/private/author')));
      await assertSucceeds(getDoc(doc(adminDb, 'posts/contest-post/private/author')));
      await assertFails(getDoc(doc(likerDb, 'posts/contest-post/private/author')));
    });

    it('投票期間中は他人のコンテスト投稿へ投票できる', async () => {
      const db = approved(testEnv, 'liker');
      const now = Date.now();
      await seed(testEnv, async (adminDb) => {
        await setDoc(doc(adminDb, 'contests/contest-1'), {
          creatorId: 'author',
          title: 'contest',
          entryDeadline: Timestamp.fromDate(new Date(now - 60 * 1000)),
          votingDeadline: Timestamp.fromDate(new Date(now + 60 * 60 * 1000)),
        });
        await setDoc(doc(adminDb, 'posts/contest-post'), {
          userId: '',
          contestId: 'contest-1',
          voteCount: 0,
        });
        await setDoc(doc(adminDb, 'posts/contest-post/private/author'), {
          userId: 'author',
        });
      });

      // voteCount 自体はクライアントから直接更新できない。投票の実体は
      // votes ドキュメントのみで、voteCount への反映は Cloud Functions
      // （onContestVoteChange）が Admin SDK 経由で行う。
      await assertSucceeds(
        setDoc(doc(db, 'contests/contest-1/votes/liker'), {
          postId: 'contest-post',
          updatedAt: Timestamp.fromDate(new Date()),
        }),
      );
    });

    it('投稿の voteCount をクライアントから直接書き換えられない', async () => {
      const db = approved(testEnv, 'liker');
      const now = Date.now();
      await seed(testEnv, async (adminDb) => {
        await setDoc(doc(adminDb, 'contests/contest-1'), {
          creatorId: 'author',
          title: 'contest',
          entryDeadline: Timestamp.fromDate(new Date(now - 60 * 1000)),
          votingDeadline: Timestamp.fromDate(new Date(now + 60 * 60 * 1000)),
        });
        await setDoc(doc(adminDb, 'posts/contest-post'), {
          userId: '',
          contestId: 'contest-1',
          voteCount: 0,
        });
        await setDoc(doc(adminDb, 'posts/contest-post/private/author'), {
          userId: 'author',
        });
      });

      await assertFails(
        updateDoc(doc(db, 'posts/contest-post'), { voteCount: increment(1) }),
      );
    });

    it('自分のコンテスト投稿には投票できない', async () => {
      const db = approved(testEnv, 'author');
      const now = Date.now();
      await seed(testEnv, async (adminDb) => {
        await setDoc(doc(adminDb, 'contests/contest-1'), {
          creatorId: 'author',
          title: 'contest',
          entryDeadline: Timestamp.fromDate(new Date(now - 60 * 1000)),
          votingDeadline: Timestamp.fromDate(new Date(now + 60 * 60 * 1000)),
        });
        await setDoc(doc(adminDb, 'posts/contest-post'), {
          userId: '',
          contestId: 'contest-1',
          voteCount: 0,
        });
        await setDoc(doc(adminDb, 'posts/contest-post/private/author'), {
          userId: 'author',
        });
      });

      await assertFails(
        setDoc(doc(db, 'contests/contest-1/votes/author'), {
          postId: 'contest-post',
          updatedAt: Timestamp.fromDate(new Date()),
        }),
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
