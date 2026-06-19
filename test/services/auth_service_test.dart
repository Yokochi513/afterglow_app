import 'package:afterglow_app/services/auth_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late AuthService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth();
      service = AuthService(auth: auth, firestore: firestore);
    });

    test('register creates an unapproved member user document', () async {
      final credential = await service.register(
        'newcomer@example.com',
        'password123',
        'Newcomer',
      );

      final uid = credential.user!.uid;
      expect(service.currentUserId, uid);

      final snapshot = await firestore
          .collection(AuthService.usersCollection)
          .doc(uid)
          .get();

      expect(snapshot.exists, isTrue);
      final data = snapshot.data()!;
      expect(data['username'], 'Newcomer');
      expect(data['email'], 'newcomer@example.com');
      expect(data['approved'], isFalse);
      expect(data['role'], 'member');
    });

    test('signOut clears the current user', () async {
      await service.register('a@example.com', 'password123', 'A');
      expect(service.currentUserId, isNotNull);

      await service.signOut();
      expect(service.currentUserId, isNull);
    });
  });
}
