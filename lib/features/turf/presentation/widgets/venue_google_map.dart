import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';

/// Interactive map (OpenStreetMap tiles via flutter_map) for the venue
/// location editor.
///
/// - Shows a pin at [latitude]/[longitude] (or at a default center if null).
/// - Tapping the map calls [onTap] with the new coordinates.
/// - When [interactive] is false, gestures are disabled (used in previews).
class VenueGoogleMap extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final double height;
  final bool interactive;
  final void Function(double lat, double lng)? onTap;

  const VenueGoogleMap({
    super.key,
    this.latitude,
    this.longitude,
    this.height = 170,
    this.interactive = true,
    this.onTap,
  });

  @override
  State<VenueGoogleMap> createState() => _VenueGoogleMapState();
}

class _VenueGoogleMapState extends State<VenueGoogleMap> {
  // Default to Kathmandu (Patan area) when no coords saved yet.
  static const LatLng _defaultCenter = LatLng(27.6688, 85.3247);

  final MapController _controller = MapController();

  LatLng get _markerPos => LatLng(
        widget.latitude ?? _defaultCenter.latitude,
        widget.longitude ?? _defaultCenter.longitude,
      );

  @override
  void didUpdateWidget(covariant VenueGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _controller.move(_markerPos, _controller.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableGestures = !widget.interactive;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: _markerPos,
                initialZoom: 16,
                minZoom: 3,
                maxZoom: 19,
                interactionOptions: InteractionOptions(
                  flags: disableGestures
                      ? InteractiveFlag.none
                      : InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: widget.interactive
                    ? (tapPos, point) =>
                        widget.onTap?.call(point.latitude, point.longitude)
                    : null,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.book_my_game',
                  // Be polite to OSM's tile server with a small retry backoff.
                  tileProvider: NetworkTileProvider(),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _markerPos,
                      width: 36,
                      height: 36,
                      alignment: Alignment.topCenter,
                      child: _VenuePin(),
                    ),
                  ],
                ),
              ],
            ),
            // Subtle attribution overlay (required by OSM).
            Positioned(
              right: 10,
              bottom: 8,
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
          ],
        ),
      ),
    );
  }
}

class _VenuePin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Soft glow
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.brandGreen.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
        ),
        // Pin body
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.brandGreen,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
