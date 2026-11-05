import 'package:afterglow_app/data/repositories/album_repository.dart';
import 'package:afterglow_app/data/repositories/auth_repository.dart';
import 'package:afterglow_app/data/repositories/comment_repository.dart';
import 'package:afterglow_app/data/repositories/contest_repository.dart';
import 'package:afterglow_app/data/repositories/event_repository.dart';
import 'package:afterglow_app/data/repositories/notification_repository.dart';
import 'package:afterglow_app/data/repositories/post_repository.dart';
import 'package:afterglow_app/data/repositories/reaction_repository.dart';
import 'package:afterglow_app/data/repositories/release_note_repository.dart';
import 'package:afterglow_app/data/repositories/usage_guide_repository.dart';
import 'package:afterglow_app/data/repositories/user_repository.dart';
import 'package:afterglow_app/data/services/geocoding_service.dart';
import 'package:afterglow_app/data/services/image_service.dart';
import 'package:afterglow_app/data/services/location_service.dart';
import 'package:afterglow_app/data/services/push_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// アプリが使う Repository / Service の組み立て（依存の注入元）。
///
/// UI は Repository / Service を自分で生成せず、[DependencyScope] が提供する
/// インスタンスを `context.read` / `context.watch` で受け取る。
///
/// 各インスタンスは初回アクセス時に生成する（`late final`）。Firebase
/// インスタンスを省略すると各 Repository が既定の `.instance` を使う。
/// テストでは Firebase のモックや個別の Repository を渡して差し替える。
class AppDependencies {
  AppDependencies({
    this.firestore,
    this.storage,
    this.auth,
    AuthRepository? authRepository,
    UserRepository? userRepository,
    PostRepository? postRepository,
    ContestRepository? contestRepository,
    CommentRepository? commentRepository,
    ReactionRepository? reactionRepository,
    AlbumRepository? albumRepository,
    EventRepository? eventRepository,
    NotificationRepository? notificationRepository,
    ReleaseNoteRepository? releaseNoteRepository,
    UsageGuideRepository? usageGuideRepository,
    ImageService? imageService,
    LocationService? locationService,
    GeocodingService? geocodingService,
    PushNotificationService? pushNotificationService,
  }) : _authRepository = authRepository,
       _userRepository = userRepository,
       _postRepository = postRepository,
       _contestRepository = contestRepository,
       _commentRepository = commentRepository,
       _reactionRepository = reactionRepository,
       _albumRepository = albumRepository,
       _eventRepository = eventRepository,
       _notificationRepository = notificationRepository,
       _releaseNoteRepository = releaseNoteRepository,
       _usageGuideRepository = usageGuideRepository,
       _imageService = imageService,
       _locationService = locationService,
       _geocodingService = geocodingService,
       _pushNotificationService = pushNotificationService;

  final FirebaseFirestore? firestore;
  final FirebaseStorage? storage;
  final FirebaseAuth? auth;

  final AuthRepository? _authRepository;
  final UserRepository? _userRepository;
  final PostRepository? _postRepository;
  final ContestRepository? _contestRepository;
  final CommentRepository? _commentRepository;
  final ReactionRepository? _reactionRepository;
  final AlbumRepository? _albumRepository;
  final EventRepository? _eventRepository;
  final NotificationRepository? _notificationRepository;
  final ReleaseNoteRepository? _releaseNoteRepository;
  final UsageGuideRepository? _usageGuideRepository;
  final ImageService? _imageService;
  final LocationService? _locationService;
  final GeocodingService? _geocodingService;
  final PushNotificationService? _pushNotificationService;

  // ---- Service（外部 API・端末機能） ----
  late final ImageService imageService = _imageService ?? ImageService();
  late final LocationService locationService =
      _locationService ?? LocationService();
  late final GeocodingService geocodingService =
      _geocodingService ?? GeocodingService();
  late final PushNotificationService pushNotificationService =
      _pushNotificationService ?? PushNotificationService(firestore: firestore);

  // ---- Repository ----
  late final AuthRepository authRepository =
      _authRepository ?? AuthRepository(auth: auth, firestore: firestore);
  late final UserRepository userRepository =
      _userRepository ?? UserRepository(firestore: firestore, storage: storage);
  late final PostRepository postRepository =
      _postRepository ??
      PostRepository(
        firestore: firestore,
        storage: storage,
        imageService: imageService,
      );
  late final ContestRepository contestRepository =
      _contestRepository ??
      ContestRepository(firestore: firestore, postRepository: postRepository);
  late final CommentRepository commentRepository =
      _commentRepository ?? CommentRepository(firestore: firestore);
  late final ReactionRepository reactionRepository =
      _reactionRepository ?? ReactionRepository(firestore: firestore);
  late final AlbumRepository albumRepository =
      _albumRepository ?? AlbumRepository(firestore: firestore);
  late final EventRepository eventRepository =
      _eventRepository ?? EventRepository(firestore: firestore);
  late final NotificationRepository notificationRepository =
      _notificationRepository ?? NotificationRepository(firestore: firestore);
  late final ReleaseNoteRepository releaseNoteRepository =
      _releaseNoteRepository ?? ReleaseNoteRepository();
  late final UsageGuideRepository usageGuideRepository =
      _usageGuideRepository ?? UsageGuideRepository();
}

/// [AppDependencies] の各インスタンスを配下のウィジェットへ提供する。
///
/// `Provider` の `create` は遅延評価のため、使われない依存は生成されない。
class DependencyScope extends StatelessWidget {
  const DependencyScope({
    super.key,
    required this.dependencies,
    required this.child,
  });

  final AppDependencies dependencies;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = dependencies;
    return MultiProvider(
      providers: [
        Provider<ImageService>(create: (_) => d.imageService),
        Provider<LocationService>(create: (_) => d.locationService),
        Provider<GeocodingService>(create: (_) => d.geocodingService),
        Provider<PushNotificationService>(
          create: (_) => d.pushNotificationService,
        ),
        Provider<AuthRepository>(create: (_) => d.authRepository),
        Provider<UserRepository>(create: (_) => d.userRepository),
        Provider<PostRepository>(create: (_) => d.postRepository),
        Provider<ContestRepository>(create: (_) => d.contestRepository),
        Provider<CommentRepository>(create: (_) => d.commentRepository),
        Provider<ReactionRepository>(create: (_) => d.reactionRepository),
        Provider<AlbumRepository>(create: (_) => d.albumRepository),
        Provider<EventRepository>(create: (_) => d.eventRepository),
        Provider<NotificationRepository>(
          create: (_) => d.notificationRepository,
        ),
        Provider<ReleaseNoteRepository>(create: (_) => d.releaseNoteRepository),
        Provider<UsageGuideRepository>(create: (_) => d.usageGuideRepository),
      ],
      child: child,
    );
  }
}
