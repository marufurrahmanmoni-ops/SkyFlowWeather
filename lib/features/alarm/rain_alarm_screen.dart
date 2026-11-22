import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../data/models/place.dart';
import '../../data/models/settings.dart';
import '../../data/sources/rain_nowcast.dart';
import '../../services/background_worker.dart';
import '../../services/notification_service.dart';
import '../../services/rain_alarm.dart';
import '../../state/providers.dart';
import '../common/widgets.dart';

Place placeFromCity(BdCity c, bool bn) => Place(
      id: 'bd:${c.nameEn.toLowerCase()}',
      name: c.name(bn),
      lat: c.lat,
      lon: c.lon,
      country: 'Bangladesh',
      countryCode: 'BD',
    );

/// Settings for the rain & storm alarm of one chosen area.
class RainAlarmScreen extends ConsumerStatefulWidget {
  const RainAlarmScreen({super.key});

  @override
  ConsumerState<RainAlarmScreen> createState() => _RainAlarmScreenState();
}

class _RainAlarmScreenState extends ConsumerState<RainAlarmScreen> {
  String? _checkResult;
  bool _checking = false;

  bool get _bn => S.of(context).isBengali;
  String t(String en, String bn) => _bn ? bn : en;

  Future<void> _update(AppSettings Function(AppSettings) change) async {
    ref.read(settingsProvider.notifier).update(change);
    await BackgroundWorker.sync(ref.read(settingsProvider));
  }

  Future<void> _toggle(bool on) async {
    if (on) {
      final ok = await NotificationService.instance.requestPermission();
      if (!ok && mounted) showMessage(context, S.of(context).notificationPermissionDenied);
    }
    final settings = ref.read(settingsProvider);
    final place = settings.rainAlarmPlace ??
        ref.read(selectedPlaceProvider) ??
        placeFromCity(bdCities.first, _bn);
    await _update((s) => s.copyWith(rainAlarmEnabled: on, rainAlarmPlace: place));
  }

  Future<void> _pickPlace() async {
    final bn = _bn;
    final selected = ref.read(selectedPlaceProvider);
    final favorites = ref.read(favoritesProvider).value ?? const [];
    final options = <Place>[
      if (selected != null) selected,
      for (final f in favorites) f.place,
      for (final c in bdCities) placeFromCity(c, bn),
    ];
    final seen = <String>{};
    final unique = [for (final p in options) if (seen.add(p.id)) p];
    final chosen = await showModalBottomSheet<Place>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            for (final p in unique)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(p.name),
                subtitle: p.country == null ? null : Text(p.country!),
                onTap: () => Navigator.of(ctx).pop(p),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) await _update((s) => s.copyWith(rainAlarmPlace: chosen));
  }

  Future<void> _checkNow() async {
    final settings = ref.read(settingsProvider);
    final place = settings.rainAlarmPlace ?? placeFromCity(bdCities.first, _bn);
    setState(() {
      _checking = true;
      _checkResult = null;
    });
    String result;
    try {
      final data = await RainAlarmService.fetch(ref.read(fetcherProvider), place);
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final event = data == null ? null : evaluateRainAlarm(data, settings, nowSec);
      if (data != null && (data.currentMm >= 0.1)) {
        result = t('It is raining in ${place.name} now.', '${place.name}-এ এখন বৃষ্টি হচ্ছে।');
      } else if (event == null) {
        result = t(
          'No rain or storm expected in ${place.name} ${formatLead(settings.rainAlarmLeadMinutes, false)}.',
          'আগামী ${formatLead(settings.rainAlarmLeadMinutes, true).replaceAll(' পর', '')}-এ ${place.name}-এ বৃষ্টি বা ঝড়ের সম্ভাবনা নেই।',
        );
      } else {
        result = rainAlarmText(event, place.name, _bn).$2;
      }
    } catch (e) {
      result = t('Could not check: $e', 'চেক করা যায়নি: $e');
    }
    if (mounted) {
      setState(() {
        _checking = false;
        _checkResult = result;
      });
    }
  }

  Future<void> _test() async {
    final settings = ref.read(settingsProvider);
    final place = settings.rainAlarmPlace ?? placeFromCity(bdCities.first, _bn);
    await NotificationService.instance.requestPermission();
    await RainAlarmService.ring(
      RainAlarmEvent(
        kind: RainAlarmKind.rain,
        startSec: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 45 * 60,
        minutesUntil: 45,
        probability: 80,
      ),
      place.name,
      _bn ? 'bn' : 'en',
      voice: settings.rainAlarmVoice,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final on = settings.rainAlarmEnabled;
    final place = settings.rainAlarmPlace;
    return Scaffold(
      appBar: AppBar(title: Text(t('Rain & storm alarm', 'বৃষ্টি ও ঝড় অ্যালার্ম'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          GlassPanel(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(on ? Icons.alarm_on : Icons.alarm_off,
                  color: on ? AppColors.accent : AppColors.textSecondary, size: 32),
              title: Text(on ? t('Alarm on', 'অ্যালার্ম চালু') : t('Alarm off', 'অ্যালার্ম বন্ধ'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              subtitle: Text(t(
                'Rings and tells you how many minutes or hours until rain or a storm reaches your area.',
                'আপনার এলাকায় বৃষ্টি বা ঝড় আসার আগে অ্যালার্ম বাজবে আর বলবে কত মিনিট বা ঘণ্টা পর আসবে।',
              )),
              value: on,
              onChanged: _toggle,
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: t('Area', 'এলাকা'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place, color: AppColors.accent),
              title: Text(place?.name ?? t('Choose an area', 'এলাকা বাছাই করুন'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.edit_location_alt_outlined),
              onTap: _pickPlace,
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: t('Warn me up to', 'কত আগে জানাবে'),
            child: SegmentedButton<int>(
              segments: [
                for (final m in const [30, 60, 120, 180])
                  ButtonSegment(
                    value: m,
                    label: Text(m < 60
                        ? t('$m min', '${m == 30 ? '৩০' : m} মি.')
                        : t('${m ~/ 60} h', '${['', '১', '২', '৩'][m ~/ 60]} ঘ.')),
                  ),
              ],
              selected: {settings.rainAlarmLeadMinutes},
              onSelectionChanged: (v) => _update((s) => s.copyWith(rainAlarmLeadMinutes: v.first)),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: t('Sensitivity', 'সংবেদনশীলতা'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 40, label: Text(t('High', 'বেশি'))),
                    ButtonSegment(value: 60, label: Text(t('Normal', 'স্বাভাবিক'))),
                    ButtonSegment(value: 80, label: Text(t('Only sure', 'নিশ্চিত হলে'))),
                  ],
                  selected: {settings.rainAlarmMinProbability},
                  onSelectionChanged: (v) => _update((s) => s.copyWith(rainAlarmMinProbability: v.first)),
                ),
                const SizedBox(height: 6),
                Text(
                  t('Rings when the rain chance is at least ${settings.rainAlarmMinProbability}%.',
                      'বৃষ্টির সম্ভাবনা অন্তত ${settings.rainAlarmMinProbability}% হলে বাজবে।'),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: t('How often to ring', 'কতবার বাজবে'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RadioGroup<int>(
                  groupValue: settings.rainAlarmRepeatMinutes == 0 ? 0 : 1,
                  onChanged: (v) => _update((s) => s.copyWith(
                      rainAlarmRepeatMinutes: v == 0 ? 0 : (s.rainAlarmRepeatMinutes == 0 ? 15 : s.rainAlarmRepeatMinutes))),
                  child: Column(
                    children: [
                      RadioListTile<int>(
                        contentPadding: EdgeInsets.zero,
                        value: 0,
                        title: Text(t('Once per rain', 'একই বৃষ্টির জন্য একবার')),
                        subtitle: Text(t('One alarm for each coming rain spell', 'প্রতিটি আসন্ন বৃষ্টির জন্য একটাই অ্যালার্ম')),
                      ),
                      RadioListTile<int>(
                        contentPadding: EdgeInsets.zero,
                        value: 1,
                        title: Text(t('Repeat until it rains', 'বৃষ্টি না আসা পর্যন্ত বারবার')),
                        subtitle: Text(t('Rings again with the updated time until the rain arrives',
                            'বৃষ্টি না আসা পর্যন্ত নতুন সময় জানিয়ে আবার বাজবে')),
                      ),
                    ],
                  ),
                ),
                if (settings.rainAlarmRepeatMinutes > 0) ...[
                  const SizedBox(height: 4),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 15, label: Text(t('15 min', '১৫ মি.'))),
                      ButtonSegment(value: 30, label: Text(t('30 min', '৩০ মি.'))),
                      ButtonSegment(value: 60, label: Text(t('1 h', '১ ঘ.'))),
                    ],
                    selected: {settings.rainAlarmRepeatMinutes},
                    onSelectionChanged: (v) => _update((s) => s.copyWith(rainAlarmRepeatMinutes: v.first)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t('Every ${settings.rainAlarmRepeatMinutes} minutes (Android may stretch this a little).',
                        'প্রতি ${settings.rainAlarmRepeatMinutes == 60 ? '৬০' : settings.rainAlarmRepeatMinutes == 30 ? '৩০' : '১৫'} মিনিট পরপর (Android সামান্য দেরি করাতে পারে)।'),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.thunderstorm_outlined),
                  title: Text(t('Thunderstorms & strong wind', 'বজ্রঝড় ও ঝোড়ো হাওয়া')),
                  subtitle: Text(t('Also ring for thunder or gusts over ${stormGustKmh.round()} km/h',
                      'বজ্রপাত বা ঘণ্টায় ${stormGustKmh.round()} কিমির বেশি দমকা হাওয়াতেও বাজবে')),
                  value: settings.rainAlarmStorms,
                  onChanged: (v) => _update((s) => s.copyWith(rainAlarmStorms: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.record_voice_over_outlined),
                  title: Text(t('Speak the warning', 'কণ্ঠে বলবে')),
                  subtitle: Text(t('Reads the warning aloud after the alarm',
                      'অ্যালার্মের পর সতর্কবার্তা পড়ে শোনাবে')),
                  value: settings.rainAlarmVoice,
                  onChanged: (v) => _update((s) => s.copyWith(rainAlarmVoice: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _checking ? null : _checkNow,
                  icon: _checking
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: Text(t('Check now', 'এখনই চেক করুন')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _test,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(t('Test alarm', 'টেস্ট অ্যালার্ম')),
                ),
              ),
            ],
          ),
          if (_checkResult != null) ...[
            const SizedBox(height: 10),
            GlassPanel(child: Text(_checkResult!, style: const TextStyle(fontSize: 15))),
          ],
          const SizedBox(height: 16),
          SectionCard(
            title: t('For it to ring reliably', 'ঠিকমতো বাজার জন্য'),
            child: Text(
              t(
                'The forecast is checked about every 15 minutes in the background; Android can delay this '
                'when the battery saver is on. On realme phones: Settings → Apps → SkyFlow Weather → '
                'Battery usage → allow background activity (and "Auto launch"). Keep alarm volume up. '
                'Timing comes from weather models, so treat minutes as approximate.',
                'ব্যাকগ্রাউন্ডে প্রায় ১৫ মিনিট পরপর পূর্বাভাস চেক হয়; ব্যাটারি সেভার চালু থাকলে Android দেরি করাতে পারে। '
                'realme ফোনে: Settings → Apps → SkyFlow Weather → Battery usage → ব্যাকগ্রাউন্ডে চলার অনুমতি '
                '(আর "Auto launch") চালু করুন। অ্যালার্মের ভলিউম বাড়িয়ে রাখুন। '
                'সময়ের হিসাব আবহাওয়া মডেল থেকে, তাই মিনিট আনুমানিক।',
              ),
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
