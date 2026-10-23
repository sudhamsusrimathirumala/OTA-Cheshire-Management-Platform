import 'package:flutter/material.dart';

import '../theme/ota_colors.dart';
import 'privacy_policy_link.dart';

class AppIssueReportNotice extends StatelessWidget {
  const AppIssueReportNotice({this.launcher, super.key});

  static const message =
      'Please report any app errors using our Google Form. '
      'Tap here to report an issue.';

  final ExternalLinkLauncher? launcher;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => openFeedbackForm(context, launcher: launcher),
    style: TextButton.styleFrom(
      foregroundColor: OtaColors.actionRed,
      backgroundColor: OtaColors.softRed,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(14),
      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: const Text(message),
  );
}
