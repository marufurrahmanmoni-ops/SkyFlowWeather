import 'package:material_ui/material_ui.dart';

import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../services/home_widget_service.dart';
import '../common/widgets.dart';

/// Lets the user add the large or small home-screen widget. Uses the
/// launcher's "pin widget" dialog where supported (realme UI does), and
/// shows the manual steps otherwise.
Future<void> showAddWidgetSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _AddWidgetSheet(),
    );

class _AddWidgetSheet extends StatefulWidget {
  const _AddWidgetSheet();

  @override
  State<_AddWidgetSheet> createState() => _AddWidgetSheetState();
}

class _AddWidgetSheetState extends State<_AddWidgetSheet> {
  bool? _canPin;

  @override
  void initState() {
    super.initState();
    HomeWidgetService.canPin().then((v) {
      if (mounted) setState(() => _canPin = v);
    });
  }

  Future<void> _add(bool large) async {
    final bn = S.of(context).isBengali;
    try {
      await HomeWidgetService.pin(large: large);
      if (mounted) {
        showMessage(
            context,
            bn
                ? 'হোম স্ক্রিনে যে বার্তা আসবে তাতে "Add" চাপুন'
                : 'Tap "Add" in the home-screen prompt');
      }
    } catch (_) {
      if (mounted) setState(() => _canPin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bn = S.of(context).isBengali;
    String t(String en, String b) => bn ? b : en;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('Home-screen widget', 'হোম স্ক্রিন উইজেট'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _Option(
              title: t('Large (4×4) — everything', 'বড় (৪×৪) — সব আপডেট'),
              detail: t(
                'Now, feels-like, humidity, wind, UV, AQI, next rain, next 5 hours, 3 days, sunrise/sunset and BMD warnings.',
                'এখনকার আবহাওয়া, অনুভূত তাপমাত্রা, আর্দ্রতা, বাতাস, UV, AQI, পরের বৃষ্টি, আগামী ৫ ঘণ্টা, ৩ দিন, সূর্যোদয়/সূর্যাস্ত ও BMD সতর্কবার্তা।',
              ),
              icon: Icons.dashboard_outlined,
              onAdd: _canPin == false ? null : () => _add(true),
              addLabel: t('Add', 'যোগ করুন'),
            ),
            const SizedBox(height: 10),
            _Option(
              title: t('Small (4×2)', 'ছোট (৪×২)'),
              detail: t('Temperature, condition, high/low and next rain.',
                  'তাপমাত্রা, অবস্থা, সর্বোচ্চ/সর্বনিম্ন ও পরের বৃষ্টি।'),
              icon: Icons.crop_7_5,
              onAdd: _canPin == false ? null : () => _add(false),
              addLabel: t('Add', 'যোগ করুন'),
            ),
            const SizedBox(height: 16),
            Text(t('Or add it by hand (realme UI):', 'অথবা নিজে যোগ করুন (realme UI):'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              t(
                '1. Touch and hold an empty spot on the home screen.\n'
                '2. Tap "Widgets".\n'
                '3. Search or scroll to "SkyFlow Weather".\n'
                '4. Drag "SkyFlow Weather (large)" or the small one onto the home screen.\n'
                'The widget updates about every 15–30 minutes and whenever you open the app. '
                'If it stops updating, allow background activity for SkyFlow Weather in Settings → Apps → Battery usage.',
                '১. হোম স্ক্রিনের ফাঁকা জায়গায় চেপে ধরুন।\n'
                '২. "Widgets" চাপুন।\n'
                '৩. "SkyFlow Weather" খুঁজুন বা স্ক্রল করুন।\n'
                '৪. "SkyFlow Weather (large)" বা ছোটটা টেনে হোম স্ক্রিনে রাখুন।\n'
                'উইজেট প্রায় ১৫–৩০ মিনিট পরপর আর অ্যাপ খুললেই আপডেট হয়। আপডেট বন্ধ হয়ে গেলে '
                'Settings → Apps → SkyFlow Weather → Battery usage-এ ব্যাকগ্রাউন্ডে চলার অনুমতি দিন।',
              ),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.title,
    required this.detail,
    required this.icon,
    required this.onAdd,
    required this.addLabel,
  });

  final String title;
  final String detail;
  final IconData icon;
  final VoidCallback? onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E6FD9), Color(0xFF0F2342)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(detail, style: const TextStyle(fontSize: 12, color: Color(0xDDFFFFFF))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: onAdd, child: Text(addLabel)),
          ],
        ),
      );
}
