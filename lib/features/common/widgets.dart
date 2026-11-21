import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../data/net/http.dart';
import '../../services/location_service.dart';

/// Rounded translucent panel used over the map.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 18,
    this.color = AppColors.panel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.stroke),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Round icon button used for floating map controls.
class MapIconButton extends StatelessWidget {
  const MapIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? AppColors.accent : AppColors.panel,
        shape: const CircleBorder(side: BorderSide(color: AppColors.stroke)),
        elevation: 4,
        shadowColor: Colors.black54,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, size: 22, color: active ? AppColors.navy : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child, this.padding});

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: AppColors.textSecondary, letterSpacing: 0.4),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Friendly error message with a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final message = describeError(error, s);
    final offline = error is ApiException && (error as ApiException).isOffline;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(offline ? Icons.cloud_off : Icons.error_outline,
            size: compact ? 28 : 44, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        if (onRetry != null) ...[
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(s.retry),
          ),
        ],
      ],
    );
    if (compact) return Padding(padding: const EdgeInsets.all(16), child: content);
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: content));
  }
}

String describeError(Object error, AppStrings s) {
  if (error is String) return error;
  if (error is ApiException) return error.describe(s);
  if (error is LocationException) return error.describe(s);
  return toApiException(error).describe(s);
}

/// Small "Updated 10:05 · Source" line.
class SourceLine extends StatelessWidget {
  const SourceLine({super.key, required this.text, this.stale = false, this.onTap});

  final String text;
  final bool stale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(stale ? Icons.cloud_off : Icons.schedule,
                size: 14, color: stale ? AppColors.amber : AppColors.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11.5,
                  color: stale ? AppColors.amber : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openExternal(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(url)));
    }
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
