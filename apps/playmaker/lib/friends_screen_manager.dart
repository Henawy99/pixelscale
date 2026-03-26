import 'dart:async';
import 'package:flutter/material.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';

class FriendManager extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  
  List<PlayerProfile> _friendsProfiles = [];
  List<PlayerProfile> _openFriendRequestsProfiles = [];
  PlayerProfile? _searchResult;
  bool isLoading = false;
  String _currentUserId = '';
  
  StreamSubscription? _friendsSubscription;
  StreamSubscription? _requestsSubscription;
  
  bool _disposed = false;

  // Getters
  List<PlayerProfile> get friendsProfiles => _friendsProfiles;
  List<PlayerProfile> get openFriendRequestsProfiles => _openFriendRequestsProfiles;
  PlayerProfile? get searchResult => _searchResult;

  set searchResult(PlayerProfile? value) {
    _searchResult = value;
    notifyListeners();
  }

  void initialize(String userId) {
    _currentUserId = userId;
    _subscribeToStreams();
  }

  void _subscribeToStreams() {
    _friendsSubscription?.cancel();
    _friendsSubscription = _supabaseService
        .streamUserFriends(_currentUserId)
        .listen((friends) {
      _friendsProfiles = friends;
      _notifyListeners();
    });

    _requestsSubscription?.cancel();
    _requestsSubscription = _supabaseService
        .streamOpenFriendRequests(_currentUserId)
        .listen((requests) {
      _openFriendRequestsProfiles = requests;
      _notifyListeners();
    });
  }

  Future<void> searchPlayer(String playerId) async {
    if (playerId.length == 7) {
      _searchResult = await _supabaseService.fetchPlayerProfileByPlayerID(playerId);
      _notifyListeners();
    } else {
      _searchResult = null;
      _notifyListeners();
    }
  }

  // Keep existing methods but remove manual fetching
  Future<void> acceptFriendRequest(String receiverUserId, String senderUserId) async {
    await _supabaseService.acceptFriendRequest(receiverUserId, senderUserId);
  }

  Future<void> declineFriendRequest(String receiverUserId, String senderUserId) async {
    await _supabaseService.declineFriendRequest(receiverUserId, senderUserId);
  }

  Future<void> deleteFriend(String userId, String friendId) async {
    await _supabaseService.deleteFriend(userId, friendId);
  }

  @override
  void dispose() {
    _disposed = true;
    _friendsSubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

