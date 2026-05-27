import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/turf_entity.dart';
import 'venue_google_map.dart';

class ShareSheet extends StatelessWidget {
  final TurfEntity turf;
  const ShareSheet({super.key, required this.turf});

  /// Direct Google Maps URL. We combine `q=` (drop a pin), `ll=` (camera
  /// centre) and `z=` (zoom level) — the mobile Maps app respects all three
  /// only when they all appear in this older-style URL.
  String? get _mapsUrl {
    if (turf.hasLocation) {
      final lat = turf.latitude!;
      final lng = turf.longitude!;
      return 'https://maps.google.com/maps?q=$lat,$lng&ll=$lat,$lng&z=18';
    }
    final addr = turf.oneLineAddress;
    if (addr.isEmpty) return null;
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}';
  }

  String get _shareText {
    final lines = <String>[turf.displayName];
    if (turf.oneLineAddress.isNotEmpty) lines.add(turf.oneLineAddress);
    // Only share the Google Maps URL — tapping it opens Maps directly.
    if (_mapsUrl != null) lines.add(_mapsUrl!);
    return lines.join('\n');
  }

  Future<void> _launch(BuildContext context, Uri uri, String app) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        _snack(context, '$app not installed');
      }
    } catch (_) {
      if (context.mounted) _snack(context, "Couldn't open $app");
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _shareViaSystem(BuildContext context) {
    // ignore: deprecated_member_use
    Share.share(_shareText);
  }

  Future<void> _openInMaps(BuildContext context) async {
    if (!turf.hasLocation) {
      // Fallback: query by name + address.
      final q = Uri.encodeComponent(
          '${turf.displayName} ${turf.oneLineAddress}'.trim());
      await _launch(context, Uri.parse('https://maps.google.com/?q=$q'),
          'Maps');
      return;
    }
    final lat = turf.latitude!;
    final lng = turf.longitude!;
    await _launch(
      context,
      Uri.parse('https://maps.google.com/maps?q=$lat,$lng&ll=$lat,$lng&z=18'),
      'Maps',
    );
  }

  void _showQr(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                turf.displayName,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _mapsUrl ?? turf.oneLineAddress,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: QrImageView(
                  data: _mapsUrl ?? 'https://maps.google.com',
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 14),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header: SHARING / venue / link / X ─────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SHARING',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.brightness == Brightness.dark
                                  ? AppColors.limeAccent
                                  : AppColors.brandGreen,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            turf.displayName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _mapsUrl ?? turf.oneLineAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded,
                          size: 22, color: cs.onSurface),
                    ),
                  ],
                ),
              ),

              // ── Preview card ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _PreviewCard(turf: turf),
              ),

              const SizedBox(height: 22),

              // ── App row ───────────────────────────────────────────────
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _ShareAppIcon(
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      icon: Icons.call_rounded,
                      onTap: () => _launch(
                        context,
                        Uri.parse(
                            'whatsapp://send?text=${Uri.encodeComponent(_shareText)}'),
                        'WhatsApp',
                      ),
                    ),
                    _ShareAppIcon(
                      label: 'Viber',
                      color: const Color(0xFF7360F2),
                      icon: Icons.phone_in_talk_rounded,
                      onTap: () => _launch(
                        context,
                        Uri.parse(
                            'viber://forward?text=${Uri.encodeComponent(_shareText)}'),
                        'Viber',
                      ),
                    ),
                    _ShareAppIcon(
                      label: 'Messenger',
                      color: const Color(0xFF0084FF),
                      icon: Icons.chat_bubble_rounded,
                      onTap: () => _launch(
                        context,
                        Uri.parse(
                            'fb-messenger://share/?link=${Uri.encodeComponent(_mapsUrl ?? '')}'),
                        'Messenger',
                      ),
                    ),
                    _ShareAppIcon(
                      label: 'SMS',
                      color: cs.surfaceContainerHighest,
                      iconColor: cs.onSurface,
                      icon: Icons.sms_rounded,
                      onTap: () => _launch(
                        context,
                        Uri.parse(
                            'sms:?body=${Uri.encodeComponent(_shareText)}'),
                        'SMS',
                      ),
                    ),
                    _ShareAppIcon(
                      label: 'Maps',
                      color: const Color(0xFFEA4335),
                      icon: Icons.location_on_rounded,
                      isSquare: true,
                      onTap: () => _openInMaps(context),
                    ),
                    _ShareAppIcon(
                      label: 'More',
                      color: cs.surfaceContainerHighest,
                      iconColor: cs.onSurface,
                      icon: Icons.more_horiz_rounded,
                      onTap: () => _shareViaSystem(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Divider(color: cs.outlineVariant.withValues(alpha: 0.5), height: 1),

              // ── Action rows ───────────────────────────────────────────
              _ActionRow(
                icon: Icons.content_copy_rounded,
                title: 'Copy link',
                subtitle: _mapsUrl ?? turf.oneLineAddress,
                onTap: () {
                  final url = _mapsUrl;
                  if (url == null) {
                    _snack(context, 'No location to copy yet');
                    return;
                  }
                  Clipboard.setData(ClipboardData(text: url));
                  _snack(context, 'Maps link copied');
                },
              ),
              _ActionRow(
                icon: Icons.qr_code_2_rounded,
                title: 'Show QR code',
                subtitle: 'Print or show at counter',
                onTap: () => _showQr(context),
              ),
              _ActionRow(
                icon: Icons.navigation_rounded,
                title: 'Open in maps',
                subtitle: turf.hasLocation
                    ? '${turf.latitude!.toStringAsFixed(4)}° N, '
                        '${turf.longitude!.toStringAsFixed(4)}° E'
                    : turf.oneLineAddress,
                onTap: () => _openInMaps(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final TurfEntity turf;
  const _PreviewCard({required this.turf});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VenueGoogleMap(
            latitude: turf.latitude,
            longitude: turf.longitude,
            height: 130,
            interactive: false,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  turf.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  turf.oneLineAddress,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (turf.hasLocation) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${turf.latitude!.toStringAsFixed(4)}°, '
                    '${turf.longitude!.toStringAsFixed(4)}°',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.brightness == Brightness.dark
                          ? AppColors.limeAccent
                          : AppColors.brandGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareAppIcon extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color? iconColor;
  final VoidCallback onTap;
  final bool isSquare;
  const _ShareAppIcon({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.iconColor,
    this.isSquare = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(isSquare ? 14 : 28),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor ?? Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: cs.onSurface),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                subtitle,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
