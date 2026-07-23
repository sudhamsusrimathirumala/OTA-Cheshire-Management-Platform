import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/curriculum_requirement.dart';
import '../routes.dart';
import '../services/app_data_service.dart';
import '../services/app_data_service_provider.dart';
import '../theme/ota_colors.dart';
import '../widgets/admin/admin_bottom_nav_bar.dart';
import '../widgets/ota_bottom_nav_bar.dart';

typedef CurriculumVideoBuilder =
    Widget Function(BuildContext context, String videoId);

String? initialCurriculumBelt({
  required String? selectedStudentBelt,
  required List<String> beltOrder,
  required Map<String, CurriculumRequirement> curriculum,
}) {
  if (selectedStudentBelt != null &&
      curriculum.containsKey(selectedStudentBelt)) {
    return selectedStudentBelt;
  }
  if (curriculum.containsKey('No Belt')) return 'No Belt';
  for (final belt in beltOrder) {
    if (curriculum.containsKey(belt)) return belt;
  }
  return curriculum.keys.firstOrNull;
}

String? youtubeVideoId(String? source) {
  final value = source?.trim();
  if (value == null || value.isEmpty) return null;
  final idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
  if (idPattern.hasMatch(value)) return value;

  final uri = Uri.tryParse(value);
  if (uri == null || !uri.isAbsolute) return null;
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  String? candidate;
  if (host == 'youtu.be') {
    candidate = uri.pathSegments.firstOrNull;
  } else if (host == 'youtube.com' || host == 'm.youtube.com') {
    candidate = uri.queryParameters['v'];
    if (candidate == null && uri.pathSegments.length >= 2) {
      if (const {'embed', 'shorts', 'live'}.contains(uri.pathSegments.first)) {
        candidate = uri.pathSegments[1];
      }
    }
  }
  return candidate != null && idPattern.hasMatch(candidate) ? candidate : null;
}

class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({
    this.isAdmin = false,
    this.dataService,
    this.videoBuilder,
    super.key,
  });

  final bool isAdmin;
  final AppDataService? dataService;
  final CurriculumVideoBuilder? videoBuilder;

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  String? _selectedBelt;

  AppDataService get _service => widget.dataService ?? appDataService;

  @override
  void initState() {
    super.initState();
    _selectedBelt = initialCurriculumBelt(
      selectedStudentBelt: widget.isAdmin
          ? null
          : _service.selectedStudentProfile.belt,
      beltOrder: _service.curriculumBeltOrder,
      curriculum: _service.curriculum,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedBelt = _selectedBelt;
    final curriculum = selectedBelt == null
        ? null
        : _service.curriculum[selectedBelt];
    final availableBelts = <String>[
      for (final belt in _service.curriculumBeltOrder)
        if (_service.curriculum.containsKey(belt)) belt,
      for (final belt in _service.curriculum.keys)
        if (!_service.curriculumBeltOrder.contains(belt)) belt,
    ];
    final content = _CurriculumContent(
      curriculum: curriculum,
      beltOrder: availableBelts,
      selectedBelt: selectedBelt,
      beltDisplayLabel: _service.beltDisplayLabel,
      videoBuilder: widget.videoBuilder,
      backLabel: widget.isAdmin ? 'Back to Events & Resources' : null,
      onBeltChanged: (belt) {
        if (belt != null && _service.curriculum.containsKey(belt)) {
          setState(() => _selectedBelt = belt);
        }
      },
      onBack: widget.isAdmin
          ? () => returnToAdminResourcesLanding(context)
          : () =>
                Navigator.of(context).pushReplacementNamed(OtaRoutes.resources),
    );

    if (widget.isAdmin) {
      return AdminPageShell(
        selectedDestination: AdminNavDestination.resources,
        title: 'Curriculum',
        subtitle: 'Read-only curriculum content used by students and families.',
        onSelectedDestinationTap: () => returnToAdminResourcesLanding(context),
        child: content,
      );
    }

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pushReplacementNamed(OtaRoutes.resources);
        }
      },
      child: Scaffold(
        backgroundColor: OtaColors.blush,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: content,
              ),
            ),
          ),
        ),
        bottomNavigationBar: OtaBottomNavBar(
          selectedDestination: OtaBottomNavDestination.resources,
          onSelectedDestinationTap: () =>
              Navigator.of(context).pushReplacementNamed(OtaRoutes.resources),
        ),
      ),
    );
  }
}

class _CurriculumContent extends StatelessWidget {
  const _CurriculumContent({
    required this.curriculum,
    required this.beltOrder,
    required this.selectedBelt,
    required this.beltDisplayLabel,
    required this.onBeltChanged,
    this.videoBuilder,
    this.onBack,
    this.backLabel,
  });

  final CurriculumRequirement? curriculum;
  final List<String> beltOrder;
  final String? selectedBelt;
  final String Function(String) beltDisplayLabel;
  final ValueChanged<String?> onBeltChanged;
  final CurriculumVideoBuilder? videoBuilder;
  final VoidCallback? onBack;
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    final sections = curriculum?.sortedSections ?? const <CurriculumSection>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CurriculumHeader(
          beltOrder: beltOrder,
          selectedBelt: selectedBelt,
          beltDisplayLabel: beltDisplayLabel,
          onBeltChanged: onBeltChanged,
          onBack: onBack,
          backLabel: backLabel,
        ),
        const SizedBox(height: 18),
        if (curriculum == null)
          const _Surface(child: Text('Curriculum is not available.'))
        else
          for (var index = 0; index < sections.length; index++) ...[
            CurriculumSectionCard(
              section: sections[index],
              videoBuilder: videoBuilder,
            ),
            if (index != sections.length - 1) const SizedBox(height: 14),
          ],
      ],
    );
  }
}

class _CurriculumHeader extends StatelessWidget {
  const _CurriculumHeader({
    required this.beltOrder,
    required this.selectedBelt,
    required this.beltDisplayLabel,
    required this.onBeltChanged,
    this.onBack,
    this.backLabel,
  });

  final List<String> beltOrder;
  final String? selectedBelt;
  final String Function(String) beltDisplayLabel;
  final ValueChanged<String?> onBeltChanged;
  final VoidCallback? onBack;
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (backLabel == null)
                IconButton.filledTonal(
                  onPressed: onBack ?? () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back',
                )
              else
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(backLabel!),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Curriculum',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: OtaColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Review belt curriculum and training material.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OtaColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedBelt,
            decoration: const InputDecoration(
              labelText: 'Select Belt Level',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final belt in beltOrder)
                DropdownMenuItem(
                  value: belt,
                  child: Text(beltDisplayLabel(belt)),
                ),
            ],
            onChanged: beltOrder.isEmpty ? null : onBeltChanged,
          ),
        ],
      ),
    );
  }
}

class CurriculumSectionCard extends StatelessWidget {
  const CurriculumSectionCard({
    required this.section,
    this.videoBuilder,
    super.key,
  });

  final CurriculumSection section;
  final CurriculumVideoBuilder? videoBuilder;

  @override
  Widget build(BuildContext context) {
    final items = section.sortedItems;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text('None for this belt')
          else
            for (var index = 0; index < items.length; index++) ...[
              _CurriculumItemView(
                item: items[index],
                videoBuilder: videoBuilder,
              ),
              if (index != items.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _CurriculumItemView extends StatelessWidget {
  const _CurriculumItemView({required this.item, this.videoBuilder});

  final CurriculumItem item;
  final CurriculumVideoBuilder? videoBuilder;

  @override
  Widget build(BuildContext context) {
    final videoId = item.contentType == CurriculumContentType.video
        ? youtubeVideoId(item.videoUrl)
        : null;
    final text = item.textContent?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.contentType == CurriculumContentType.video
            ? OtaColors.softRed
            : const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (item.contentType == CurriculumContentType.text &&
              text != null &&
              text.isNotEmpty &&
              text != item.title) ...[
            const SizedBox(height: 6),
            Text(text),
          ],
          if (item.contentType == CurriculumContentType.video) ...[
            const SizedBox(height: 10),
            if (videoId == null)
              const _VideoUnavailable()
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: KeyedSubtree(
                  key: ValueKey<String>('youtube-player-$videoId'),
                  child:
                      videoBuilder?.call(context, videoId) ??
                      _EmbeddedYoutubePlayer(videoId: videoId),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _EmbeddedYoutubePlayer extends StatefulWidget {
  const _EmbeddedYoutubePlayer({required this.videoId});

  final String videoId;

  @override
  State<_EmbeddedYoutubePlayer> createState() => _EmbeddedYoutubePlayerState();
}

class _EmbeddedYoutubePlayerState extends State<_EmbeddedYoutubePlayer> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(showFullscreenButton: true),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(controller: _controller, aspectRatio: 16 / 9);
  }
}

class _VideoUnavailable extends StatelessWidget {
  const _VideoUnavailable();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: OtaColors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, color: OtaColors.mutedText),
          SizedBox(width: 8),
          Flexible(child: Text('Video coming soon')),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OtaColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E4EA)),
        boxShadow: [
          BoxShadow(
            color: OtaColors.navy.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
