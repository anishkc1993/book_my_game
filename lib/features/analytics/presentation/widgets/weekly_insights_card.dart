import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/insights_service.dart';

/// Gemini-powered "Weekly insights" card. Shown above analytics. Hits
/// the per-turf-per-week Firestore cache first; refreshable on demand.
class WeeklyInsightsCard extends StatefulWidget {
  final String turfId;
  const WeeklyInsightsCard({super.key, required this.turfId});

  @override
  State<WeeklyInsightsCard> createState() => _WeeklyInsightsCardState();
}

class _WeeklyInsightsCardState extends State<WeeklyInsightsCard> {
  final InsightsService _service = InsightsService();
  Future<WeeklyInsights>? _future;

  @override
  void initState() {
    super.initState();
    _load(force: false);
  }

  void _load({required bool force}) {
    _future = _service.getOrGenerate(widget.turfId, forceRefresh: force);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.limeAccent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.limeAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.limeAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 12, color: AppColors.limeAccent),
                    SizedBox(width: 4),
                    Text(
                      'AI',
                      style: TextStyle(
                        color: AppColors.limeAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Weekly insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              FutureBuilder<WeeklyInsights>(
                future: _future,
                builder: (_, snap) {
                  final loading =
                      snap.connectionState == ConnectionState.waiting;
                  return IconButton(
                    onPressed: loading ? null : () => _load(force: true),
                    tooltip: 'Refresh',
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    icon: loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.limeAccent),
                            ),
                          )
                        : const Icon(Icons.refresh_rounded,
                            size: 18, color: AppColors.limeAccent),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<WeeklyInsights>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Reading the room…',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }
              if (snap.hasError) {
                return Text(
                  'Could not load insights right now.',
                  style: TextStyle(
                    color: cs.error.withValues(alpha: 0.9),
                  ),
                );
              }
              final narrative = snap.data?.narrative ?? '';
              return Text(
                narrative,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.45,
                  fontSize: 13.5,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
