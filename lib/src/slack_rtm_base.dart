import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

// TODO: Put public facing types in this file.

/// Slack Team
class Team {
  final String id;
  final String name;
  final String domain;
  Team(this.id, this.name, this.domain);
}

/// Slack User
class User {
  final String id;
  final String name;
  User(this.id, this.name);
}

/// Slack RTM handler
typedef void RtmHandler(Map<String, dynamic> msg, RtmSession sess);

/// Slack RTM controller
class Rtm {
  final String _token;
  final bool _dumpUnhandle;
  final Map<String, RtmHandler> _handlers;

  Rtm(this._token, {bool dumpUnhandle = false})
      : this._handlers = new Map<String, RtmHandler>(),
        this._dumpUnhandle = dumpUnhandle;

  /// Register message handler
  void on(String type, RtmHandler handler) {
    _handlers[type] = handler;
  }

  Timer _pingTimer(RtmSession sess) =>
      new Timer(const Duration(seconds: 12), () {
        sess._ws.add(JSON.encode({
          'type': 'ping',
          'ping': new DateTime.now().millisecondsSinceEpoch,
        }));
      });

  String _clean(String s) => s.replaceAll(new RegExp(r'[\000-\008]+$'), '');

  /// Connect to Slack.
  void connect() {
    RtmSession._connect(_token).then((sess) {
      var timer = _pingTimer(sess);
      sess._ws.listen((String msg) {
        timer.cancel();
        timer = _pingTimer(sess);

        final json = JSON.decode(_clean(msg)) as Map<String, dynamic>;
        final type = json['type'] as String;
        final hand = _handlers[type];
        if (hand != null) {
          hand(json, sess);
        } else if (_dumpUnhandle) {
          print('$json');
        }
      });
    });
  }
}

/// Slack RTM connected session.
class RtmSession {
  final Team team;
  final User bot;
  final WebSocket _ws;
  RtmSession(this.team, this.bot, this._ws);

  static Future<RtmSession> _connect(String token) {
    final url = 'https://slack.com/api/rtm.connect';

    return http.post(url, body: {
      'token': token,
    }).then((response) {
      final json = JSON.decode(response.body) as Map<String, dynamic>;
      if (json['ok'] == true) {
        final url = json['url'] as String;
        final team = json['team'] as Map<String, dynamic>;
        final self = json['self'] as Map<String, dynamic>;

        final team_id = team['id'] as String;
        final team_name = team['name'] as String;
        final team_domain = team['domain'] as String;
        final user_id = self['id'] as String;
        final user_name = self['name'] as String;

        return WebSocket.connect(url).then((ws) => new RtmSession(
              new Team(team_id, team_name, team_domain),
              new User(user_id, user_name),
              ws,
            ));
      } else {
        final err = json['error'] as String ?? 'error';
        print(err);
        throw err;
      }
    });
  }
}
