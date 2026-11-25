import 'dart:io';
import 'package:relay/ai.dart';
import 'package:relay/auth.dart';
import 'package:relay/middleware/rate_limit.dart';
import 'package:relay/server.dart';
import 'package:relay/store.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final env = Platform.environment;
  final store = Store(env['DATA_FILE'] ?? 'data.json')
    ..load(adminUser: env['ADMIN_USER'] ?? 'admin', adminPass: env['ADMIN_PASS'] ?? 'admin123');
  final auth = Auth(env['TOKEN_SECRET'] ?? 'dev-secret-change-me');
  final limiter = RateLimiter(limit: int.parse(env['RATE_LIMIT'] ?? '120'));
  final handler = buildHandler(store, auth, AiProxy(env['OPENAI_API_KEY']), limiter: limiter);
  final server = await io.serve(handler, InternetAddress.anyIPv4, int.parse(env['PORT'] ?? '8080'));
  print('Relay $apiVersion listening on :${server.port}');
}
