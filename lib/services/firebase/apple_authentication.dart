import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

bool get appleSignInSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

String createAppleRawNonce() => generateNonce();

String hashAppleNonce(String rawNonce) =>
    sha256.convert(utf8.encode(rawNonce)).toString();

class AppleAuthorizationCancelled implements Exception {
  const AppleAuthorizationCancelled();
}

class AppleAuthorizationResult {
  const AppleAuthorizationResult({
    required this.identityToken,
    required this.authorizationCode,
    this.givenName,
    this.familyName,
    this.email,
  });

  final String identityToken;
  final String authorizationCode;
  final String? givenName;
  final String? familyName;
  final String? email;
}

abstract interface class AppleAuthorizationGateway {
  Future<AppleAuthorizationResult> authorize({required String hashedNonce});
}

class NativeAppleAuthorizationGateway implements AppleAuthorizationGateway {
  const NativeAppleAuthorizationGateway();

  @override
  Future<AppleAuthorizationResult> authorize({
    required String hashedNonce,
  }) async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw StateError('Apple identity verification was unavailable.');
      }
      return AppleAuthorizationResult(
        identityToken: identityToken,
        authorizationCode: credential.authorizationCode,
        givenName: credential.givenName,
        familyName: credential.familyName,
        email: credential.email,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AppleAuthorizationCancelled();
      }
      rethrow;
    }
  }
}

class AppleAuthenticationRequest {
  const AppleAuthenticationRequest({
    required this.credential,
    required this.authorizationCode,
  });

  final OAuthCredential credential;
  final String authorizationCode;
}

class AppleAuthenticationCoordinator {
  AppleAuthenticationCoordinator({
    AppleAuthorizationGateway? gateway,
    String Function()? nonceGenerator,
  }) : _gateway = gateway ?? const NativeAppleAuthorizationGateway(),
       _nonceGenerator = nonceGenerator ?? createAppleRawNonce;

  final AppleAuthorizationGateway _gateway;
  final String Function() _nonceGenerator;

  Future<AppleAuthenticationRequest> createRequest() async {
    final rawNonce = _nonceGenerator();
    if (rawNonce.isEmpty) {
      throw StateError('Apple sign-in could not be started.');
    }
    final authorization = await _gateway.authorize(
      hashedNonce: hashAppleNonce(rawNonce),
    );
    if (authorization.authorizationCode.isEmpty) {
      throw StateError('Apple account authorization was unavailable.');
    }
    return AppleAuthenticationRequest(
      credential: AppleAuthProvider.credentialWithIDToken(
        authorization.identityToken,
        rawNonce,
        AppleFullPersonName(
          givenName: _nonBlank(authorization.givenName),
          familyName: _nonBlank(authorization.familyName),
        ),
      ),
      authorizationCode: authorization.authorizationCode,
    );
  }
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
