import 'dart:math';
import 'package:shelf/shelf.dart';

/// Tags each response with an x-request-id (reuses the caller's when present) for log correlation.
Middleware requestId() => (inner) => (req) async {
      final id = req.headers['x-request-id'] ?? _rand();
      final res = await inner(req);
      return res.change(headers: {'x-request-id': id});
    };

String _rand() {
  final r = Random();
  return List.generate(8, (_) => r.nextInt(16).toRadixString(16)).join();
}
