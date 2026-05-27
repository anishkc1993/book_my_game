import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/turf_provider.dart';
import '../widgets/share_sheet.dart';
import '../widgets/venue_google_map.dart';
import 'location_picker_page.dart';

class VenueLocationPage extends StatefulWidget {
  const VenueLocationPage({super.key});

  @override
  State<VenueLocationPage> createState() => _VenueLocationPageState();
}

class _VenueLocationPageState extends State<VenueLocationPage> {
  final _venueCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();

  double? _lat;
  double? _lng;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final turfId = auth.user?.turfId;
      if (turfId != null) {
        await context.read<TurfProvider>().loadTurf(turfId);
        _hydrateForm();
      }
    });
  }

  void _hydrateForm() {
    final turf = context.read<TurfProvider>().currentTurf;
    if (turf == null) return;
    _venueCtrl.text = turf.venueName ?? turf.name;
    _streetCtrl.text = turf.street ?? '';
    _cityCtrl.text = turf.cityArea ?? '';
    _landmarkCtrl.text = turf.landmark ?? '';
    _slugCtrl.text = turf.shareSlug ?? '';
    _lat = turf.latitude;
    _lng = turf.longitude;
    setState(() => _hydrated = true);
  }

  @override
  void dispose() {
    _venueCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _landmarkCtrl.dispose();
    _slugCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<TurfProvider>();
    final turfId = auth.user?.turfId;
    if (turfId == null) return;

    final ok = await provider.saveVenueDetails(
      turfId: turfId,
      venueName: _venueCtrl.text.trim(),
      street: _streetCtrl.text.trim(),
      cityArea: _cityCtrl.text.trim(),
      landmark: _landmarkCtrl.text.trim(),
      latitude: _lat,
      longitude: _lng,
      shareSlug: _slugCtrl.text.trim().isEmpty ? null : _slugCtrl.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Venue saved' : 'Failed to save'),
      behavior: SnackBarBehavior.floating,
    ));
    if (ok) context.pop();
  }

  Future<void> _editCoordinates() async {
    final result = await Navigator.of(context).push<({double lat, double lng})>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLat: _lat,
          initialLng: _lng,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _lat = result.lat;
        _lng = result.lng;
      });
    }
  }

  void _openShareSheet() {
    final turf = context.read<TurfProvider>().currentTurf;
    if (turf == null) return;
    final preview = turf.copyWith(
      venueName: _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
      street: _streetCtrl.text.trim().isEmpty ? null : _streetCtrl.text.trim(),
      cityArea: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      latitude: _lat,
      longitude: _lng,
      shareSlug: _slugCtrl.text.trim().isEmpty ? null : _slugCtrl.text.trim(),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => ShareSheet(turf: preview),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final saving = context.watch<TurfProvider>().saving;
    final loading = context.watch<TurfProvider>().currentTurfLoading;

    if (loading && !_hydrated) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(Icons.arrow_back_rounded,
                          size: 26, color: cs.onSurface),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Venue location',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Where players will find you',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: saving ? null : _save,
                      icon: saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.brandGreen),
                            )
                          : Icon(Icons.check_rounded,
                              size: 26, color: cs.onSurface),
                      tooltip: 'Save',
                    ),
                  ],
                ),
              ),
            ),

            // ── Map preview ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: VenueGoogleMap(
                  latitude: _lat,
                  longitude: _lng,
                  height: 200,
                  onTap: (lat, lng) {
                    setState(() {
                      _lat = lat;
                      _lng = lng;
                    });
                  },
                ),
              ),
            ),

            // ── Coordinates strip ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _LatLngBlock(label: 'LAT', value: _lat),
                            const SizedBox(width: 22),
                            _LatLngBlock(label: 'LNG', value: _lng),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _editCoordinates,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.brandGreen
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14,
                                  color: cs.onSurface),
                              const SizedBox(width: 6),
                              Text(
                                'Drop pin',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Address section ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Address',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: 'VENUE NAME',
                      controller: _venueCtrl,
                      hint: 'Patan Futsal Arena',
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: 'STREET',
                      controller: _streetCtrl,
                      hint: 'Lagankhel Marg',
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: 'CITY / AREA',
                      controller: _cityCtrl,
                      hint: 'Lalitpur 44700, Patan',
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: 'LANDMARK',
                      labelSuffix: 'optional',
                      controller: _landmarkCtrl,
                      hint: 'Opposite Lagankhel Bus Park',
                    ),
                  ],
                ),
              ),
            ),

            // ── Shareable link ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shareable link',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ShareLinkCard(
                      url: _shareUrlPreview(),
                      onCopy: () {
                        Clipboard.setData(
                            ClipboardData(text: _shareUrlPreview()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copied'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Share to ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Share to',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _openShareSheet,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 18),
                        minimumSize: const Size(0, 42),
                      ),
                      icon: const Icon(Icons.ios_share_rounded, size: 16),
                      label: const Text('Open'),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  String _shareUrlPreview() {
    final slug = _slugCtrl.text.trim().isNotEmpty
        ? _slugCtrl.text.trim()
        : _venueCtrl.text
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');
    final safe = slug.isEmpty ? 'venue' : slug;
    return 'bmg.com.np/v/$safe';
  }
}

// ── Small bits ────────────────────────────────────────────────────────────────

class _LatLngBlock extends StatelessWidget {
  final String label;
  final double? value;
  const _LatLngBlock({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value != null ? '${value!.toStringAsFixed(4)}°' : '—',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String? labelSuffix;
  final TextEditingController controller;
  final String? hint;
  const _LabeledField({
    required this.label,
    required this.controller,
    this.labelSuffix,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            if (labelSuffix != null) ...[
              const SizedBox(width: 6),
              Text(
                '(${labelSuffix!})',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: cs.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _ShareLinkCard extends StatelessWidget {
  final String url;
  final VoidCallback onCopy;
  const _ShareLinkCard({required this.url, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.brandGreen.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.link_rounded,
                color: AppColors.brandGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  url,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Opens directions in any maps app',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: Icon(Icons.content_copy_rounded,
                size: 18, color: cs.onSurface),
            tooltip: 'Copy',
          ),
        ],
      ),
    );
  }
}

// ── Custom painted map preview ───────────────────────────────────────────────

class MapPreviewCard extends StatelessWidget {
  final double height;
  final bool showPin;
  const MapPreviewCard({super.key, this.height = 170, this.showPin = true});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _MapPainter(showPin: showPin),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final bool showPin;
  _MapPainter({required this.showPin});

  @override
  void paint(Canvas canvas, Size size) {
    // Background: deep forest green
    final bgPaint = Paint()..color = const Color(0xFF0F2309);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Grid lines (subtle vertical + horizontal)
    final gridPaint = Paint()
      ..color = AppColors.limeAccent.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // A few subtly tinted blocks
    final blockPaint = Paint()
      ..color = AppColors.limeAccent.withValues(alpha: 0.06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.18,
            size.width * 0.18, size.height * 0.20),
        const Radius.circular(6),
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.10,
            size.width * 0.22, size.height * 0.16),
        const Radius.circular(6),
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.72, size.height * 0.68,
            size.width * 0.18, size.height * 0.22),
        const Radius.circular(6),
      ),
      blockPaint,
    );

    // Roads — two crossing curves
    final roadPaint = Paint()
      ..color = AppColors.brandGreen.withValues(alpha: 0.65)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path1 = Path()
      ..moveTo(-10, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.30, size.height * 0.50,
          size.width * 0.55, size.height * 0.60)
      ..quadraticBezierTo(size.width * 0.78, size.height * 0.66,
          size.width + 10, size.height * 0.55);
    canvas.drawPath(path1, roadPaint);

    final path2 = Path()
      ..moveTo(size.width * 0.18, -10)
      ..quadraticBezierTo(size.width * 0.32, size.height * 0.40,
          size.width * 0.46, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.55, size.height * 0.78,
          size.width * 0.72, size.height + 10);
    canvas.drawPath(path2, roadPaint);

    // Pin at center-ish
    if (showPin) {
      final center = Offset(size.width * 0.46, size.height * 0.46);
      // Outer glow
      final glow = Paint()
        ..color = AppColors.limeAccent.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(center, 28, glow);

      // Outer ring
      final ring = Paint()
        ..color = AppColors.limeAccent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, 16, ring);

      // Inner filled rounded square (target)
      final inner = Paint()..color = AppColors.limeAccent;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 18, height: 18),
          const Radius.circular(4),
        ),
        inner,
      );
      // Dot inside
      final dot = Paint()..color = const Color(0xFF0F2309);
      canvas.drawCircle(center, 3, dot);

      // Stem (small triangle below the pin)
      final stem = Paint()..color = AppColors.limeAccent;
      final stemPath = Path()
        ..moveTo(center.dx - 4, center.dy + 10)
        ..lineTo(center.dx, center.dy + 26)
        ..lineTo(center.dx + 4, center.dy + 10)
        ..close();
      canvas.drawPath(stemPath, stem);
    }

    // Attribution
    const tp = TextStyle(
      color: Color(0xFF6FA85A),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );
    final attr = TextPainter(
      text: const TextSpan(text: '© bmg · maps', style: tp),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    attr.paint(
      canvas,
      Offset(size.width - attr.width - 10, size.height - attr.height - 8),
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.showPin != showPin;
}

