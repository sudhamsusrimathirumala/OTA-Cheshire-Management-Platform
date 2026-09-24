import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firebase Hosting serves the Web build as an SPA safely', () {
    final config =
        jsonDecode(File('firebase.json').readAsStringSync())
            as Map<String, dynamic>;
    final hosting = config['hosting'] as Map<String, dynamic>;

    expect(hosting['site'], 'ota-management-platform-e4847');
    expect(hosting['public'], 'build/web');
    expect(hosting['ignore'], contains('**/*.map'));
    final rewrites = (hosting['rewrites'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      rewrites.any(
        (rewrite) =>
            rewrite['source'] == '**' &&
            rewrite['destination'] == '/index.html',
      ),
      isTrue,
    );

    final headers = hosting['headers'] as List<dynamic>;
    expect(
      headers,
      contains(
        isA<Map<String, dynamic>>().having(
          (entry) => entry['source'],
          'index cache source',
          '**/index.html',
        ),
      ),
    );
    final allResponses = headers.cast<Map<String, dynamic>>().singleWhere(
      (entry) => entry['source'] == '**',
    );
    final securityHeaderNames = (allResponses['headers'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((header) => header['key'])
        .toSet();
    expect(
      securityHeaderNames,
      containsAll({
        'X-Content-Type-Options',
        'X-Frame-Options',
        'Referrer-Policy',
        'Permissions-Policy',
      }),
    );
  });

  test('Web metadata is OTA branded and installable at the site root', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final index = File('web/index.html').readAsStringSync();

    expect(manifest['id'], '/');
    expect(manifest['start_url'], '/');
    expect(manifest['scope'], '/');
    expect(manifest['name'], 'OTA - Cheshire');
    expect(manifest['theme_color'], '#8B1E2D');
    expect(index, contains('<title>OTA - Cheshire</title>'));
    expect(index, contains('viewport-fit=cover'));
    expect(index, contains('name="apple-mobile-web-app-title"'));
  });
}
