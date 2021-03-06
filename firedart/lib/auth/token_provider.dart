import 'dart:async';
import 'dart:convert';

import 'package:firedart/auth/client.dart';
import 'package:firedart/auth/token_store.dart';

const _tokenExpirationThreshold = Duration(minutes: 5);

class TokenProvider {
  final KeyClient client;
  final TokenStore _tokenStore;

  StreamController<bool> _signInStateStreamController;

  TokenProvider(this.client, this._tokenStore) {
    _signInStateStreamController = StreamController<bool>();

    Timer.periodic(Duration(minutes: 45), (t) {
      if (isSignedIn) {
        _refresh();
      } else {
        t.cancel();
      }
    });
  }

  String get userId => _tokenStore.userId;

  String get refreshToken => _tokenStore.refreshToken;

  bool get isSignedIn => _tokenStore.hasToken;

  Stream<bool> get signInState => _signInStateStreamController.stream;

  Future<String> get idToken async {
    if (_tokenStore.expiry
        .subtract(_tokenExpirationThreshold)
        .isBefore(DateTime.now().toUtc())) {
      await _refresh();
    }
    return _tokenStore.idToken;
  }

  void setToken(Map<String, dynamic> map) {
    _tokenStore.setToken(
      map['localId'],
      map['idToken'],
      map['refreshToken'],
      int.parse(map['expiresIn']),
    );
    _notifyState();
  }

  void signOut() {
    _tokenStore.clear();
    _notifyState();
  }

  Future _refresh() async {
    var response = await client.post(
      'https://securetoken.googleapis.com/v1/token',
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': _tokenStore.refreshToken,
      },
    );

    switch (response.statusCode) {
      case 200:
        var map = json.decode(response.body);
        _tokenStore.setToken(
          map['localId'],
          map['id_token'],
          map['refresh_token'],
          int.parse(map['expires_in']),
        );
        print('${DateTime.now()} Refreshing token ${map['refresh_token']}');
        break;
      default:
        Future.delayed(Duration(seconds: 10), () => _refresh());
    }
  }

  void _notifyState() => _signInStateStreamController.add(isSignedIn);
}
