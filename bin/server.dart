import 'dart:io';
import 'package:relay/ai.dart';
import 'package:relay/auth.dart';
import 'package:relay/server.dart';
import 'package:relay/store.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final env = Platform.environment;
  final store = Store(env['DATA_FILE'] ?? 'data.json')..load();
  final auth = Auth(env['TOKEN_SECRET'] ?? 'dev-secret-change-me', env['ADMIN_USER'] ?? 'admin', env['ADMIN_PASS'] ?? 'admin123');
  final handler = buildHandler(store, auth, AiProxy(env['OPENAI_API_KEY']));
  final server = await io.serve(handler, InternetAddress.anyIPv4, int.parse(env['PORT'] ?? '8080'));
  print('Relay listening on :${server.port}');
}
