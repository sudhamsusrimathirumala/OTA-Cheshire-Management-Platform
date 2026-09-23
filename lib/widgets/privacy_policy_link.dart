import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const privacyPolicyUrl =
    'https://docs.google.com/document/d/e/'
    '2PACX-1vQNJ9fGPhLxG9lkE8RXoMwdOXIFh9wc19rJXgCqefbEnE-c3nFnK9VpVhRMK-SLR7sPFuWQl3ZDMQy-/pub';

const accountDeletionRequestUrl =
    'https://docs.google.com/forms/d/e/'
    '1FAIpQLScLct1c2cEmJMjEt-vXNJUOjOMuWZiB5uyLMYyV0agFolYWMQ/viewform';

typedef ExternalLinkLauncher = Future<bool> Function(Uri uri);

Future<void> openPrivacyPolicy(
  BuildContext context, {
  ExternalLinkLauncher? launcher,
}) => _openExternalLink(
  context,
  privacyPolicyUrl,
  failureMessage: 'The privacy policy could not be opened.',
  launcher: launcher,
);

Future<void> openAccountDeletionRequest(
  BuildContext context, {
  ExternalLinkLauncher? launcher,
}) => _openExternalLink(
  context,
  accountDeletionRequestUrl,
  failureMessage: 'The account deletion request page could not be opened.',
  launcher: launcher,
);

Future<void> _openExternalLink(
  BuildContext context,
  String url, {
  required String failureMessage,
  ExternalLinkLauncher? launcher,
}) async {
  final uri = Uri.parse(url);
  final opened =
      await (launcher?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failureMessage)));
  }
}

class PrivacyPolicyButton extends StatelessWidget {
  const PrivacyPolicyButton({this.launcher, this.foregroundColor, super.key});

  final ExternalLinkLauncher? launcher;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => openPrivacyPolicy(context, launcher: launcher),
    style: foregroundColor == null
        ? null
        : TextButton.styleFrom(foregroundColor: foregroundColor),
    icon: const Icon(Icons.privacy_tip_outlined, size: 18),
    label: const Text('Privacy Policy'),
  );
}
