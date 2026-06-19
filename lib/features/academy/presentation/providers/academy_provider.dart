import 'package:flutter/foundation.dart';

import '../../domain/entities/academy_player_entity.dart';
import '../../domain/entities/squad_entity.dart';
import '../../domain/repositories/academy_repository.dart';

enum AcademyState { initial, loading, loaded, error }

class AcademyProvider extends ChangeNotifier {
  final AcademyRepository _repository;
  AcademyProvider({required AcademyRepository repository})
      : _repository = repository;

  AcademyState _state = AcademyState.initial;
  AcademyState get state => _state;

  String? _error;
  String? get error => _error;

  bool _saving = false;
  bool get saving => _saving;

  String? _turfId;
  String? get turfId => _turfId;

  List<SquadEntity> _squads = [];
  List<SquadEntity> get squads => _squads;

  List<AcademyPlayerEntity> _players = [];
  List<AcademyPlayerEntity> get allPlayers => _players;

  String? _selectedSquadId;
  String? get selectedSquadId => _selectedSquadId;

  SquadEntity? get selectedSquad {
    if (_selectedSquadId == null) return null;
    for (final s in _squads) {
      if (s.id == _selectedSquadId) return s;
    }
    return null;
  }

  /// Players belonging to the currently selected squad.
  List<AcademyPlayerEntity> get playersForSelectedSquad {
    if (_selectedSquadId == null) return const [];
    return _players.where((p) => p.squadId == _selectedSquadId).toList();
  }

  /// Total active players across all squads.
  int get totalPlayers => _players.length;

  /// Current calendar month key (`YYYY-MM`).
  String get currentMonth => AcademyPlayerEntity.monthKey(DateTime.now());

  /// Fee collection summary for the *selected squad* for the current month.
  ({double collected, double expected, int paidCount, int totalCount})
      get feeSummary {
    final roster = playersForSelectedSquad;
    double collected = 0;
    double expected = 0;
    int paidCount = 0;
    for (final p in roster) {
      expected += p.monthlyFee;
      if (p.isPaidFor(currentMonth)) {
        collected += p.monthlyFee;
        paidCount++;
      }
    }
    return (
      collected: collected,
      expected: expected,
      paidCount: paidCount,
      totalCount: roster.length,
    );
  }

  void selectSquad(String? squadId) {
    if (_selectedSquadId == squadId) return;
    _selectedSquadId = squadId;
    notifyListeners();
  }

  Future<void> load(String turfId) async {
    _turfId = turfId;
    _state = AcademyState.loading;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.listSquads(turfId),
        _repository.listPlayers(turfId),
      ]);
      _squads = results[0] as List<SquadEntity>;
      _players = results[1] as List<AcademyPlayerEntity>;
      // Keep current selection if still valid; otherwise pick first.
      if (_selectedSquadId == null ||
          !_squads.any((s) => s.id == _selectedSquadId)) {
        _selectedSquadId = _squads.isNotEmpty ? _squads.first.id : null;
      }
      _state = AcademyState.loaded;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _state = AcademyState.error;
    }
    notifyListeners();
  }

  Future<bool> saveSquad(SquadEntity squad) async {
    if (_turfId == null) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final saved = await _repository.upsertSquad(_turfId!, squad);
      final idx = _squads.indexWhere((s) => s.id == saved.id);
      if (idx >= 0) {
        _squads[idx] = saved;
      } else {
        _squads.add(saved);
      }
      _squads.sort((a, b) => a.shortLabel.compareTo(b.shortLabel));
      _selectedSquadId ??= saved.id;
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> removeSquad(String squadId) async {
    if (_turfId == null) return false;
    try {
      await _repository.deleteSquad(_turfId!, squadId);
      _squads.removeWhere((s) => s.id == squadId);
      if (_selectedSquadId == squadId) {
        _selectedSquadId = _squads.isNotEmpty ? _squads.first.id : null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> savePlayer(AcademyPlayerEntity player) async {
    if (_turfId == null) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final saved = await _repository.upsertPlayer(_turfId!, player);
      final idx = _players.indexWhere((p) => p.id == saved.id);
      if (idx >= 0) {
        _players[idx] = saved;
      } else {
        _players.add(saved);
      }
      _players.sort((a, b) => a.name.compareTo(b.name));
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> removePlayer(String playerId) async {
    if (_turfId == null) return false;
    try {
      await _repository.deletePlayer(_turfId!, playerId);
      _players.removeWhere((p) => p.id == playerId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> markFeePaid({
    required String playerId,
    required double amount,
    required String markedBy,
    String? month,
  }) async {
    if (_turfId == null) return false;
    final m = month ?? currentMonth;
    try {
      await _repository.markFeePaid(
        turfId: _turfId!,
        playerId: playerId,
        month: m,
        amount: amount,
        markedBy: markedBy,
      );
      final idx = _players.indexWhere((p) => p.id == playerId);
      if (idx >= 0) {
        _players[idx] = _players[idx].copyWith(lastPaidMonth: m);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
