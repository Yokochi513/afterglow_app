import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';
import { approved, createTestEnv, seed } from './helpers.mjs';

/// notifications コレクションのルール（§3.9 / Issue #16）。
///
/// 受信者本人は読み取りと既読化（isRead: true）だけができる。作成・削除と
/// それ以外の更新は Cloud Functions（Admin SDK）専用。
describe('notifications のルール', () => {
  let testEnv;

  before(async () => {
    testEnv = await createTestEnv('notifications');
  });

  after(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await seed(testEnv, async (db) => {
      await setDoc(doc(db, 'users/recipient'), { approved: true, role: 'member' });
      await setDoc(doc(db, 'users/other'), { approved: true, role: 'member' });
      await setDoc(doc(db, 'notifications/n-1'), {
        recipientId: 'recipient',
        actorId: 'other',
        type: 'reaction',
        sourceId: 'post-1',
        isRead: false,
      });
    });
  });

  it('受信者本人は自分宛ての通知を読める', async () => {
    const db = approved(testEnv, 'recipient');
    await assertSucceeds(getDoc(doc(db, 'notifications/n-1')));
    await assertSucceeds(
      getDocs(
        query(collection(db, 'notifications'), where('recipientId', '==', 'recipient')),
      ),
    );
  });

  it('他人宛ての通知は読めない', async () => {
    const db = approved(testEnv, 'other');
    await assertFails(getDoc(doc(db, 'notifications/n-1')));
  });

  it('受信者本人は既読にできる', async () => {
    const db = approved(testEnv, 'recipient');
    await assertSucceeds(updateDoc(doc(db, 'notifications/n-1'), { isRead: true }));
  });

  it('既読以外のフィールドは変更できない', async () => {
    const db = approved(testEnv, 'recipient');
    await assertFails(
      updateDoc(doc(db, 'notifications/n-1'), { isRead: true, type: 'comment' }),
    );
    await assertFails(updateDoc(doc(db, 'notifications/n-1'), { recipientId: 'other' }));
  });

  it('他人宛ての通知は既読にできない', async () => {
    const db = approved(testEnv, 'other');
    await assertFails(updateDoc(doc(db, 'notifications/n-1'), { isRead: true }));
  });

  it('クライアントからは作成・削除できない', async () => {
    const db = approved(testEnv, 'recipient');
    await assertFails(
      setDoc(doc(db, 'notifications/n-2'), {
        recipientId: 'recipient',
        actorId: 'recipient',
        type: 'comment',
        sourceId: 'post-1',
        isRead: false,
      }),
    );
    await assertFails(deleteDoc(doc(db, 'notifications/n-1')));
  });
});
