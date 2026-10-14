const assert = require('node:assert/strict');
const {beforeEach, after, describe, it} = require('node:test');

// 実環境への接続を防ぎ、他のルールテストとは別のプロジェクトで検証する。
if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Firestore エミュレータ上で実行してください');
}
process.env.GCLOUD_PROJECT = 'demo-afterglow-contest-functions';
const handlers = require('../lib/index.js');
const admin = require('firebase-admin');
const db = admin.firestore();
const timestamp = (offset) => admin.firestore.Timestamp.fromMillis(Date.now() + offset);

describe('コンテストのバックエンド処理', () => {
  beforeEach(async () => {
    for (const collection of await db.listCollections()) {
      await db.recursiveDelete(collection);
    }
  });
  after(async () => admin.app().delete());

  it('終了前は匿名を維持し、終了後は旧匿名維持フラグも解除する', async () => {
    await db.doc('contests/ended').set({votingDeadline: timestamp(-1000), entryLimitVersion: 1});
    await db.doc('contests/open').set({votingDeadline: timestamp(60000), entryLimitVersion: 1});
    for (const [id, contestId] of [['old', 'ended'], ['current', 'open']]) {
      await db.doc(`posts/${id}`).set({userId: '', contestId, stayAnonymous: true});
      await db.doc(`posts/${id}/private/author`).set({userId: `author-${id}`});
    }
    await handlers.revealContestAuthors.run();
    assert.equal((await db.doc('posts/old').get()).data().userId, 'author-old');
    assert.equal((await db.doc('posts/old').get()).data().stayAnonymous, false);
    assert.equal((await db.doc('posts/current').get()).data().userId, '');
    await handlers.revealContestAuthors.run();
    assert.equal((await db.doc('posts/old').get()).data().userId, 'author-old');
  });

  it('旧投稿を参加履歴へ移行し、再実行しても履歴を上書きしない', async () => {
    await db.doc('contests/legacy').set({votingDeadline: timestamp(60000)});
    await db.doc('posts/legacy-entry').set({userId: '', contestId: 'legacy'});
    await db.doc('posts/legacy-entry/private/author').set({userId: 'author'});
    await handlers.revealContestAuthors.run();
    assert.equal((await db.doc('contests/legacy/entries/author').get()).data().postId, 'legacy-entry');
    assert.equal((await db.doc('contests/legacy').get()).data().entryLimitVersion, 1);
    assert.equal((await db.doc('posts/legacy-entry').get()).data().userId, '');
    await handlers.revealContestAuthors.run();
    assert.equal((await db.doc('contests/legacy/entries/author').get()).data().postId, 'legacy-entry');
  });

  it('コンテスト削除で投稿を復元し、写真・コメントを保って投票・履歴を掃除する', async () => {
    const contestRef = db.doc('contests/deleted');
    await contestRef.set({entryLimitVersion: 1});
    const deleted = await contestRef.get();
    await db.doc('posts/entry').set({
      userId: '', contestId: 'deleted', stayAnonymous: true, voteCount: 3,
      caption: '作品', imageUrls: ['photo.jpg'],
    });
    await db.doc('posts/entry/private/author').set({userId: 'author'});
    await db.doc('posts/entry/comments/comment').set({text: 'コメント'});
    await db.doc('contests/deleted/votes/voter').set({postId: 'entry'});
    await db.doc('contests/deleted/entries/author').set({postId: 'entry'});
    await contestRef.delete();
    const context = {params: {contestId: 'deleted'}};
    await handlers.onContestDeleted.run(deleted, context);
    assert.deepEqual((await db.doc('posts/entry').get()).data(), {
      userId: 'author', caption: '作品', imageUrls: ['photo.jpg'],
    });
    assert.equal((await db.doc('posts/entry/comments/comment').get()).exists, true);
    assert.equal((await contestRef.collection('votes').get()).empty, true);
    assert.equal((await contestRef.collection('entries').get()).empty, true);
    await handlers.onContestVoteChange.run({
      before: {exists: true, data: () => ({postId: 'entry'})},
      after: {exists: false},
    }, context);
    assert.equal((await db.doc('posts/entry').get()).data().voteCount, undefined);
    await handlers.onContestDeleted.run(deleted, context);
    assert.equal((await db.doc('posts/entry').get()).data().userId, 'author');
  });
});
