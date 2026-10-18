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

  test('Web updates revalidate all cached Flutter assets on normal reload', () {
    final config =
        jsonDecode(File('firebase.json').readAsStringSync())
            as Map<String, dynamic>;
    final hosting = config['hosting'] as Map<String, dynamic>;
    final rules =
        (hosting['headers'] as List<dynamic>).cast<Map<String, dynamic>>();

    String cacheControlFor(String source) {
      final rule = rules.singleWhere((rule) => rule['source'] == source);
      final headers =
          (rule['headers'] as List<dynamic>).cast<Map<String, dynamic>>();
      return headers.singleWhere(
            (header) => header['key'] == 'Cache-Control',
          )['value']
          as String;
    }

    // Covers root routes, bootstrap, main.dart.js, fonts, and assets.
    expect(cacheControlFor('**'), 'max-age=0, must-revalidate');
    expect(
      cacheControlFor('**/index.html'),
      'no-cache, no-store, must-revalidate',
    );
    expect(
      cacheControlFor('**/flutter_service_worker.js'),
      'no-cache, no-store, must-revalidate',
    );
    expect(cacheControlFor('404.html'), 'max-age=0, must-revalidate');

    // An overlapping Firebase Hosting rule must not restore a stale TTL.
    for (final rule in rules) {
      final headers =
          (rule['headers'] as List<dynamic>).cast<Map<String, dynamic>>();
      for (final header in headers.where(
        (header) => header['key'] == 'Cache-Control',
      )) {
        expect(
          header['value'],
          anyOf(
            'max-age=0, must-revalidate',
            'no-cache, no-store, must-revalidate',
          ),
          reason: 'Unsafe cache policy for ${rule['source']}',
        );
      }
    }
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
