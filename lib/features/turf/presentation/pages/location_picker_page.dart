import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';

/// Fullscreen map (OpenStreetMap) for picking a location.
///
/// - Map shows a fixed center crosshair; whatever's at the centre when the
///   user taps Confirm becomes the chosen lat/lng.
/// - A search bar uses Nominatim (free, no key) to find addresses/venues.
///
/// Pop result: `({double lat, double lng})?` — null if cancelled.
class LocationPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerPage({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const LatLng _kathmandu = LatLng(27.6688, 85.3247);

  late final MapController _controller = MapController();
  late LatLng _center;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  bool _searching = false;
  List<_NominatimResult> _results = [];

  @override
  void initState() {
    super.initState();
    _center = LatLng(
      widget.initialLat ?? _kathmandu.latitude,
      widget.initialLng ?? _kathmandu.longitude,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _center = camera.center;
    setState(() {});
  }

  void _confirm() {
    Navigator.of(context).pop((lat: _center.latitude, lng: _center.longitude));
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    if (!mounted) return;
    setState(() => _searching = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'json',
        'limit': '6',
        // Limit to Nepal by default. Remove `countrycodes` for global search.
        // 'countrycodes': 'np',
        'addressdetails': '1',
      });
      final response = await http.get(uri, headers: {
        // Nominatim requires a unique User-Agent per app.
        'User-Agent': 'book_my_game/1.0 (com.example.book_my_game)',
      });
      if (response.statusCode != 200 || !mounted) return;
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _results = data.map((e) {
          final m = e as Map<String, dynamic>;
          return _NominatimResult(
            name: m['display_name'] as String,
            lat: double.parse(m['lat'] as String),
            lng: double.parse(m['lon'] as String),
          );
        }).toList();
      });
    } catch (_) {
      // Network/parse errors → just clear results silently.
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectResult(_NominatimResult r) {
    final pos = LatLng(r.lat, r.lng);
    _center = pos;
    _controller.move(pos, 17);
    setState(() {
      _results = [];
      _searchCtrl.text = r.shortLabel;
    });
    _searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16,
              minZoom: 3,
              maxZoom: 19,
              onPositionChanged: _onPositionChanged,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.book_my_game',
              ),
            ],
          ),

          // Center crosshair
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.brandGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 14,
                      color: AppColors.brandGreen,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top row: back + search + my-location
          Positioned(
            top: topInset + 8,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SearchField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        searching: _searching,
                        onChanged: _onSearchChanged,
                        onClear: () {
                          _searchCtrl.clear();
                          setState(() => _results = []);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoundIconButton(
                      icon: Icons.my_location_rounded,
                      onTap: () {
                        final initial = LatLng(
                          widget.initialLat ?? _kathmandu.latitude,
                          widget.initialLng ?? _kathmandu.longitude,
                        );
                        _controller.move(initial, _controller.camera.zoom);
                      },
                    ),
                  ],
                ),
                // Suggestions
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8, left: 52, right: 52),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemBuilder: (_, i) {
                        final r = _results[i];
                        return InkWell(
                          onTap: () => _selectResult(r),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.place_outlined,
                                    size: 18,
                                    color: AppColors.brandGreen),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.shortLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        r.subLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                      itemCount: _results.length,
                    ),
                  ),
              ],
            ),
          ),

          // Attribution
          Positioned(
            right: 10,
            bottom: MediaQuery.of(context).padding.bottom + 88,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Bottom: coord pill + confirm button
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 18, color: AppColors.brandGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_center.latitude.toStringAsFixed(5)}°, '
                          '${_center.longitude.toStringAsFixed(5)}°',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        'centre of map',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    'Use this location',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _NominatimResult {
  final String name;
  final double lat;
  final double lng;
  _NominatimResult({required this.name, required this.lat, required this.lng});

  /// First chunk of the display_name (before the first comma).
  String get shortLabel {
    final i = name.indexOf(',');
    return i == -1 ? name : name.substring(0, i);
  }

  /// Everything after the first comma — the rest of the address.
  String get subLabel {
    final i = name.indexOf(',');
    return i == -1 ? '' : name.substring(i + 1).trim();
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          searching
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandGreen,
                  ),
                )
              : Icon(Icons.search_rounded,
                  size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Search address or venue',
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 0, vertical: 13),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              onPressed: onClear,
              icon: Icon(Icons.close_rounded,
                  size: 18, color: cs.onSurfaceVariant),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 6,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: cs.onSurface),
        ),
      ),
    );
  }
}
