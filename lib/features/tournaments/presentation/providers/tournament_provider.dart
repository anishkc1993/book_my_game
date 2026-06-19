import 'package:flutter/foundation.dart';

import '../../domain/entities/tournament_entity.dart';
import '../../domain/repositories/tournament_repository.dart';

enum TournamentState { initial, loading, loaded, error }

class TournamentProvider extends ChangeNotifier {
  final TournamentRepository _repository;
  TournamentProvider({required TournamentRepository repository})
      : _repository = repository;

  String? _turfId;
  String? get turfId => _turfId;

  void setTurfId(String? newTurfId) {
    if (newTurfId == _turfId) return;
    _turfId = newTurfId;
    _tournaments = [];
    _state = TournamentState.initial;
    notifyListeners();
  }

  bool get _hasTurf => _turfId != null && _turfId!.isNotEmpty;

  TournamentState _state = TournamentState.initial;
  TournamentState get state => _state;

  String? _error;
  String? get error => _error;

  bool _saving = false;
  bool get saving => _saving;

  List<TournamentEntity> _tournaments = [];
  List<TournamentEntity> get tournaments => _tournaments;

  /// Bumped when payments are recorded — analytics listens so dashboard
  /// revenue refreshes automatically.
  final ValueNotifier<int> mutations = ValueNotifier<int>(0);
  void _bumpMutation() => mutations.value = mutations.value + 1;

  Future<void> load() async {
    if (!_hasTurf) return;
    _state = TournamentState.loading;
    _error = null;
    notifyListeners();
    try {
      _tournaments = await _repository.list(_turfId!);
      _state = TournamentState.loaded;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _state = TournamentState.error;
    }
    notifyListeners();
  }

  Future<bool> save(TournamentEntity t) async {
    if (!_hasTurf) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final scoped = t.copyWith(turfId: _turfId);
      final saved = await _repository.upsert(scoped);
      final idx = _tournaments.indexWhere((x) => x.id == saved.id);
      if (idx >= 0) {
        _tournaments[idx] = saved;
      } else {
        _tournaments.add(saved);
      }
      _tournaments.sort((a, b) {
        final aFirst = a.dates.isEmpty ? DateTime(2100) : a.dates.first;
        final bFirst = b.dates.isEmpty ? DateTime(2100) : b.dates.first;
        return aFirst.compareTo(bFirst);
      });
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> delete(String id) async {
    if (!_hasTurf) return false;
    try {
      await _repository.delete(_turfId!, id);
      _tournaments.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> markPaid({
    required String tournamentId,
    required double amount,
    required String markedBy,
  }) async {
    if (!_hasTurf) return false;
    try {
      await _repository.markPaid(
        turfId: _turfId!,
        tournamentId: tournamentId,
        amount: amount,
        markedBy: markedBy,
      );
      final idx = _tournaments.indexWhere((t) => t.id == tournamentId);
      if (idx >= 0) {
        _tournaments[idx] = _tournaments[idx].copyWith(
          isPaid: true,
          amountPaid: amount,
          paidAt: DateTime.now(),
        );
      }
      _bumpMutation();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
