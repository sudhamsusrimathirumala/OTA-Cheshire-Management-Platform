import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/services/firebase/apple_authentication.dart';

void main() {
  test('Apple raw nonces are secure-sized and unique', () {
    final first = createAppleRawNonce();
    final second = createAppleRawNonce();

    expect(first, hasLength(32));
    expect(second, hasLength(32));
    expect(second, isNot(first));
  });

  test(
    'Apple request hashes the raw nonce and retains authorization code',
    () async {
      final gateway = _FakeAppleGateway();
      final coordinator = AppleAuthenticationCoordinator(
        gateway: gateway,
        nonceGenerator: () => 'fixed-raw-nonce',
      );

      final request = await coordinator.createRequest();

      expect(gateway.hashedNonce, hashAppleNonce('fixed-raw-nonce'));
      expect(request.credential.providerId, 'apple.com');
      expect(request.credential.appleFullPersonName?.givenName, 'OTA');
      expect(request.credential.appleFullPersonName?.familyName, 'Member');
      expect(request.authorizationCode, 'authorization-code');
    },
  );

  test('missing first-time Apple name stays absent', () async {
    final coordinator = AppleAuthenticationCoordinator(
      gateway: _FakeAppleGateway(includeName: false),
      nonceGenerator: () => 'fixed-raw-nonce',
    );

    final request = await coordinator.createRequest();

    expect(request.credential.appleFullPersonName?.givenName, isNull);
    expect(request.credential.appleFullPersonName?.familyName, isNull);
  });

  test('Apple cancellation remains distinct', () async {
    final coordinator = AppleAuthenticationCoordinator(
      gateway: _CancelledAppleGateway(),
      nonceGenerator: () => 'fixed-raw-nonce',
    );

    await expectLater(
      coordinator.createRequest(),
      throwsA(isA<AppleAuthorizationCancelled>()),
    );
  });
}

class _FakeAppleGateway implements AppleAuthorizationGateway {
  _FakeAppleGateway({this.includeName = true});

  final bool includeName;
  String? hashedNonce;

  @override
  Future<AppleAuthorizationResult> authorize({
    required String hashedNonce,
  }) async {
    this.hashedNonce = hashedNonce;
    return AppleAuthorizationResult(
      identityToken: 'identity-token',
      authorizationCode: 'authorization-code',
      givenName: includeName ? 'OTA' : '   ',
      familyName: includeName ? 'Member' : null,
      email: 'private-relay@example.com',
    );
  }
}

class _CancelledAppleGateway implements AppleAuthorizationGateway {
  @override
  Future<AppleAuthorizationResult> authorize({required String hashedNonce}) {
    throw const AppleAuthorizationCancelled();
  }
}
