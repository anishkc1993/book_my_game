import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

/// Aggregated weekly figures for one period (this week / last week).
class _WeekStats {
  final DateTime start; // Sunday, midnight
  final DateTime end;   // exclusive upper bound (next Sunday OR tomorrow for partial)
  final int bookings;
  final double revenue;     // confirmed/completed booking revenue (basePrice sums)
  final double cafeRevenue;
  final int cafeSales;
  final int topHour;        // 0..23, -1 if no bookings
  final int topHourCount;
  final String? topCustomerName;
  final String? topCustomerPhone;
  final int topCustomerCount;

  _WeekStats({
    required this.start,
    required this.end,
    required this.bookings,
    required this.revenue,
    required this.cafeRevenue,
    required this.cafeSales,
    required this.topHour,
    required this.topHourCount,
    required this.topCustomerName,
    required this.topCustomerPhone,
    required this.topCustomerCount,
  });
}

class WeeklyInsights {
  final String narrative;
  final DateTime generatedAt;
  final String weekKey; // e.g. "2026-W25" (Sunday-anchored)
  WeeklyInsights({
    required this.narrative,
    required this.generatedAt,
    required this.weekKey,
  });
}

/// Generates a 3-bullet weekly narrative via Gemini 2.5 Flash. Caches the
/// result per-turf per-week in Firestore so opening the analytics page
/// doesn't re-bill on every view.
class InsightsService {
  final FirebaseFirestore _firestore;
  InsightsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Public: returns cached narrative if present + fresh, otherwise
  /// regenerates. Set [forceRefresh] to skip the cache.
  Future<WeeklyInsights> getOrGenerate(String turfId,
      {bool forceRefresh = false}) async {
    final now = DateTime.now();
    final weekKey = _weekKey(now);
    final docRef = _firestore
        .collection('turfs')
        .doc(turfId)
        .collection('insights')
        .doc(weekKey);

    if (!forceRefresh) {
      try {
        final snap = await docRef.get();
        if (snap.exists) {
          final data = snap.data() ?? const <String, dynamic>{};
          final narrative = data['narrative'] as String?;
          final ts = (data['generatedAt'] as Timestamp?)?.toDate();
          if (narrative != null && narrative.isNotEmpty && ts != null) {
            // Refresh stale entries older than 6 hours so the admin sees
            // up-to-date numbers if they open the page later in the day.
            if (now.difference(ts).inHours < 6) {
              return WeeklyInsights(
                narrative: narrative,
                generatedAt: ts,
                weekKey: weekKey,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ insights cache read failed: $e');
      }
    }

    final thisWeek = await _aggregate(turfId, _weekStart(now), _endOfToday(now));
    final lastWeekStart = _weekStart(now).subtract(const Duration(days: 7));
    final lastWeekEnd = _weekStart(now); // exclusive
    final lastWeek = await _aggregate(turfId, lastWeekStart, lastWeekEnd);

    final narrative = await _askGemini(thisWeek, lastWeek);

    try {
      await docRef.set({
        'narrative': narrative,
        'generatedAt': FieldValue.serverTimestamp(),
        'weekKey': weekKey,
      });
    } catch (e) {
      debugPrint('⚠️ insights cache write failed: $e');
    }

    return WeeklyInsights(
      narrative: narrative,
      generatedAt: DateTime.now(),
      weekKey: weekKey,
    );
  }

  // ── Aggregation ────────────────────────────────────────────────────────

  Future<_WeekStats> _aggregate(
      String turfId, DateTime start, DateTime end) async {
    int bookings = 0;
    double revenue = 0;
    final hourCounts = <int, int>{};
    final customerCounts = <String, int>{};
    final customerNames = <String, String>{};

    try {
      final snap = await _firestore
          .collection('bookings')
          .where('turfId', isEqualTo: turfId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .get();
      for (final d in snap.docs) {
        final data = d.data();
        final status = data['status'] as String?;
        if (status == 'CANCELLED') continue;
        bookings++;
        final price = (data['basePrice'] as num?)?.toDouble() ?? 0;
        revenue += price;
        final startTime = (data['startTime'] as Timestamp?)?.toDate();
        if (startTime != null) {
          hourCounts[startTime.hour] = (hourCounts[startTime.hour] ?? 0) + 1;
        }
        final phone = data['userPhone'] as String?;
        if (phone != null && phone.isNotEmpty) {
          customerCounts[phone] = (customerCounts[phone] ?? 0) + 1;
          final name = data['customerName'] as String?;
          if (name != null && name.isNotEmpty) customerNames[phone] = name;
        }
      }
    } catch (e) {
      debugPrint('⚠️ insights aggregate (bookings) failed: $e');
    }

    double cafeRevenue = 0;
    int cafeSales = 0;
    try {
      final snap = await _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('concession_sales')
          .where('soldAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('soldAt', isLessThan: Timestamp.fromDate(end))
          .get();
      cafeSales = snap.docs.length;
      for (final d in snap.docs) {
        cafeRevenue += (d.data()['amount'] as num?)?.toDouble() ?? 0;
      }
    } catch (e) {
      debugPrint('⚠️ insights aggregate (cafe) failed: $e');
    }

    int topHour = -1, topHourCount = 0;
    hourCounts.forEach((h, c) {
      if (c > topHourCount) {
        topHour = h;
        topHourCount = c;
      }
    });

    String? topCustomerPhone;
    int topCustomerCount = 0;
    customerCounts.forEach((p, c) {
      if (c > topCustomerCount) {
        topCustomerPhone = p;
        topCustomerCount = c;
      }
    });

    return _WeekStats(
      start: start,
      end: end,
      bookings: bookings,
      revenue: revenue,
      cafeRevenue: cafeRevenue,
      cafeSales: cafeSales,
      topHour: topHour,
      topHourCount: topHourCount,
      topCustomerName: topCustomerPhone == null ? null : customerNames[topCustomerPhone],
      topCustomerPhone: topCustomerPhone,
      topCustomerCount: topCustomerCount,
    );
  }

  // ── Gemini call ────────────────────────────────────────────────────────

  Future<String> _askGemini(_WeekStats now, _WeekStats prev) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      generationConfig: GenerationConfig(
        temperature: 0.6,
        maxOutputTokens: 220,
      ),
      systemInstruction: Content.system(
        'You are an analytics assistant for a futsal turf in Nepal. '
        'Write a SHORT 3-bullet weekly insight. Each bullet ≤ 18 words. '
        'Compare this week vs last week. Use Rs. for amounts. '
        'End with ONE concrete actionable suggestion as the 3rd bullet. '
        'No greetings. No headings. Just the 3 bullets, dash-prefixed.',
      ),
    );

    final prompt = _formatPrompt(now, prev);
    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return _fallback(now, prev);
      }
      return text;
    } catch (e) {
      debugPrint('⚠️ Gemini call failed, falling back: $e');
      return _fallback(now, prev);
    }
  }

  String _formatPrompt(_WeekStats now, _WeekStats prev) {
    String fmtRange(_WeekStats s) {
      return '${_d(s.start)} → ${_d(s.end.subtract(const Duration(days: 1)))}';
    }

    String hourLabel(int h) {
      if (h < 0) return 'n/a';
      final next = (h + 1) % 24;
      String name(int x) {
        if (x == 0) return '12am';
        if (x < 12) return '${x}am';
        if (x == 12) return '12pm';
        return '${x - 12}pm';
      }
      return '${name(h)}–${name(next)}';
    }

    return '''
THIS WEEK (Sun → today) — ${fmtRange(now)}
- Bookings: ${now.bookings}
- Booking revenue: Rs. ${now.revenue.toInt()}
- Cafe: Rs. ${now.cafeRevenue.toInt()} across ${now.cafeSales} sales
- Top slot: ${hourLabel(now.topHour)} (${now.topHourCount} bookings)
- Top customer: ${now.topCustomerName ?? now.topCustomerPhone ?? 'n/a'} (${now.topCustomerCount} bookings)

LAST WEEK (full Sun → Sat) — ${fmtRange(prev)}
- Bookings: ${prev.bookings}
- Booking revenue: Rs. ${prev.revenue.toInt()}
- Cafe: Rs. ${prev.cafeRevenue.toInt()} across ${prev.cafeSales} sales
- Top slot: ${hourLabel(prev.topHour)} (${prev.topHourCount} bookings)
- Top customer: ${prev.topCustomerName ?? prev.topCustomerPhone ?? 'n/a'} (${prev.topCustomerCount} bookings)

Now write the 3 bullets.''';
  }

  /// Deterministic backup used when Gemini fails — keeps the card useful
  /// instead of showing an error.
  String _fallback(_WeekStats now, _WeekStats prev) {
    final dB = now.bookings - prev.bookings;
    final dR = now.revenue - prev.revenue;
    String pct(double a, double b) {
      if (b == 0) return a == 0 ? '0%' : '+∞%';
      return '${((a - b) / b * 100).toStringAsFixed(0)}%';
    }
    return [
      '- Bookings ${dB >= 0 ? 'up' : 'down'} ${dB.abs()} vs last week '
          '(${pct(now.bookings.toDouble(), prev.bookings.toDouble())}).',
      '- Booking revenue ${dR >= 0 ? 'up' : 'down'} Rs. ${dR.abs().toInt()} '
          '(${pct(now.revenue, prev.revenue)}); cafe Rs. ${now.cafeRevenue.toInt()}.',
      '- Try a midweek promo on the quietest slot to lift bookings further.',
    ].join('\n');
  }

  // ── Date helpers ───────────────────────────────────────────────────────

  DateTime _weekStart(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final daysSinceSunday = (today.weekday - DateTime.sunday + 7) % 7;
    return today.subtract(Duration(days: daysSinceSunday));
  }

  DateTime _endOfToday(DateTime now) =>
      DateTime(now.year, now.month, now.day + 1);

  String _weekKey(DateTime now) {
    final ws = _weekStart(now);
    return '${ws.year}-${_two(ws.month)}-${_two(ws.day)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _d(DateTime d) => '${_two(d.day)}/${_two(d.month)}';
}
