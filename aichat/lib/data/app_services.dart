import 'db.dart';
import 'repos/conversations_repo.dart';
import 'repos/models_repo.dart';
import 'repos/personas_repo.dart';
import 'repos/search_repo.dart';
import 'repos/settings_repo.dart';

/// Singleton bag of repos so UI doesn't have to thread them through
/// constructors. Initialised at boot via [boot].
class AppServices {
  AppServices._({
    required this.db,
    required this.settings,
    required this.personas,
    required this.models,
    required this.conversations,
    required this.search,
  });

  final AppDb db;
  final SettingsRepo settings;
  final PersonasRepo personas;
  final ModelsRepo models;
  final ConversationsRepo conversations;
  final SearchRepo search;

  static AppServices? _instance;
  static AppServices get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('AppServices.boot() must be called first');
    }
    return i;
  }

  static Future<AppServices> boot() async {
    if (_instance != null) return _instance!;
    final db = await AppDb.open();
    final settings = SettingsRepo(db);
    final personas = PersonasRepo(db);
    final models = ModelsRepo(db, settings);
    final conversations = ConversationsRepo(db);
    final search = SearchRepo(db);
    final svc = AppServices._(
      db: db,
      settings: settings,
      personas: personas,
      models: models,
      conversations: conversations,
      search: search,
    );
    _instance = svc;
    return svc;
  }
}
