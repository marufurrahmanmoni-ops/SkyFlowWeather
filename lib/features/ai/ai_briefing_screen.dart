import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../data/models/place.dart';
import '../../services/weather_ai.dart';
import '../../state/providers.dart';
import '../common/widgets.dart';

/// Reads a bulletin aloud (Bengali voice when the phone has one).
class BriefingSpeaker {
  final FlutterTts _tts = FlutterTts();
  bool speaking = false;

  Future<void> speak(String text, {required bool bengali, String? english}) async {
    try {
      var lang = bengali ? 'bn-BD' : 'en-US';
      var say = text;
      if (bengali && (await _tts.isLanguageAvailable('bn-BD')) != true) {
        if ((await _tts.isLanguageAvailable('bn-IN')) == true) {
          lang = 'bn-IN';
        } else if (english != null) {
          lang = 'en-US';
          say = english;
        }
      }
      await _tts.setLanguage(lang);
      await _tts.setSpeechRate(0.45);
      speaking = true;
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(say);
    } finally {
      speaking = false;
    }
  }

  Future<void> stop() async {
    speaking = false;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

String _aiTitle(bool bn) => bn ? 'AI আবহাওয়া বার্তা' : 'AI weather update';

/// Short version on the Forecast overview.
class AiBriefingCard extends ConsumerWidget {
  const AiBriefingCard({super.key, required this.place});
  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final async = ref.watch(aiBriefingProvider(place));
    final b = async.value;
    if (b == null) {
      if (async.hasError) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassPanel(
          child: Row(children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(s.isBengali ? '🤖 আবহাওয়া বিশ্লেষণ করা হচ্ছে…' : '🤖 Analysing the weather…'),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => AiBriefingScreen(place: place))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF243B7A), Color(0xFF13203F)],
            ),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('🤖', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(_aiTitle(s.isBengali),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent)),
                const Spacer(),
                Text(s.isBengali ? 'পুরো বিশ্লেষণ ›' : 'Full analysis ›',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 8),
              Text(b.headline, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The full bulletin with every section, confidence, sources and read-aloud.
class AiBriefingScreen extends ConsumerStatefulWidget {
  const AiBriefingScreen({super.key, required this.place});
  final Place place;

  @override
  ConsumerState<AiBriefingScreen> createState() => _AiBriefingScreenState();
}

class _AiBriefingScreenState extends ConsumerState<AiBriefingScreen> {
  final _speaker = BriefingSpeaker();
  bool _speaking = false;

  @override
  void dispose() {
    _speaker.stop();
    super.dispose();
  }

  Future<void> _toggleSpeak(AiBriefing b, bool bn) async {
    if (_speaking) {
      await _speaker.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    final full = [b.spoken, for (final sec in b.sections.skip(1)) ...sec.lines.take(2)].join(' ');
    var clean = full;
    for (final e in const ['⚠️', '🌀', '🤖']) {
      clean = clean.replaceAll(e, '');
    }
    await _speaker.speak(clean, bengali: bn);
    if (mounted) setState(() => _speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bn = s.isBengali;
    final async = ref.watch(aiBriefingProvider(widget.place));
    return Scaffold(
      appBar: AppBar(title: Text('🤖 ${_aiTitle(bn)} · ${widget.place.name}')),
      floatingActionButton: async.value == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _toggleSpeak(async.value!, bn),
              icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
              label: Text(_speaking ? (bn ? 'থামান' : 'Stop') : (bn ? 'শুনুন' : 'Listen')),
            ),
      body: async.when(
        loading: () => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(bn ? 'সব উৎস মিলিয়ে বিশ্লেষণ করা হচ্ছে…' : 'Combining all sources…'),
          ]),
        ),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(aiBriefingProvider(widget.place))),
        data: (b) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(radarAnalysisProvider);
            ref.invalidate(aiBriefingProvider(widget.place));
            await ref.read(aiBriefingProvider(widget.place).future).catchError((Object _) => b);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              GlassPanel(
                child: Text(b.headline,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.35)),
              ),
              if (b.confidence != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: Icon(Icons.verified_outlined,
                        color: [AppColors.danger, AppColors.amber, AppColors.success][b.confidence!], size: 18),
                    label: Text(bn
                        ? 'আস্থা: ${['কম', 'মাঝারি', 'উচ্চ'][b.confidence!]}'
                        : 'Confidence: ${['low', 'medium', 'high'][b.confidence!]}'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              for (final sec in b.sections) ...[
                SectionCard(
                  title: '${sec.emoji}  ${sec.title}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in sec.lines)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(line, style: const TextStyle(fontSize: 14.5, height: 1.45)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                '${bn ? 'উৎস' : 'Sources'}: ${b.sources.join(' · ')}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                bn
                    ? 'এই বিশ্লেষণ পুরোটাই আপনার ফোনে হয় — কোনো অনলাইন AI সার্ভিসে তথ্য পাঠানো হয় না। '
                        'নতুন ডেটা আনতে ইন্টারনেট লাগে; ইন্টারনেট না থাকলে শেষ সেভ করা ডেটা দিয়ে বিশ্লেষণ করে। '
                        'উপগ্রহ-বৃষ্টি চিত্র কয়েক ঘণ্টা পুরোনো হয়; অফিশিয়াল সতর্কতার জন্য BMD দেখুন।'
                    : 'This analysis runs entirely on your phone — nothing is sent to an online AI service. '
                        'New data needs the internet; offline it uses the last saved data. '
                        'Satellite rain images are a few hours old; for official warnings follow BMD.',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
