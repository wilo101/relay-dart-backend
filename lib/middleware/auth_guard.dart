import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../auth.dart';

const claimsKey = 'relay.claims';

Response jsonResponse(Object body, [int status = 200, Map<String, String>? headers]) => Response(status,
    body: jsonEncode(body), headers: {'content-type': 'application/json', ...?headers});

/// Verifies the bearer token on every route except the open ones and stores the claims on the request.
Middleware authGuard(Auth auth, {Set<String> open = const {'/health', '/auth/login'}}) => (inner) => (req) {
      if (open.contains('/${req.url.path}')) return inner(req);
      final claims = auth.verify(req.headers['authorization']);
      if (claims == null) return jsonResponse({'error': 'unauthorized'}, 401);
      return inner(req.change(context: {claimsKey: claims}));
    };

Claims claimsOf(Request r) => r.context[claimsKey] as Claims;

/// Writes need the admin role; viewers get read-only access.
Middleware requireAdminForWrites() => (inner) => (req) {
      final writes = req.method != 'GET' && req.method != 'HEAD' && req.method != 'OPTIONS';
      final c = req.context[claimsKey] as Claims?;
      if (writes && c != null && !c.isAdmin) return jsonResponse({'error': 'admin role required'}, 403);
      return inner(req);
    };
