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

  const Team(this.id, this.name, this.domain);

  factory Team.fromJson(Map<String, dynamic> j) => new Team(
        j['id'] as String,
        j['name'] as String,
        j['domain'] as String,
      );

  Map toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'domain': domain,
      };
}

/// Slack User
class User {
  final String id;
  final String name;

  const User(this.id, this.name);

  factory User.fromJson(Map<String, dynamic> j) => new User(
        j['id'] as String,
        j['name'] as String,
      );

  Map toJson() => <String, dynamic>{
        'id': id,
        'name': name,
      };
}

/// Slack RTM handler
typedef void RtmHandler(Map<String, dynamic> msg, RtmSession sess);

/// Slack RTM controller
class Rtm {
  final String _token;
  final bool _dumpUnhandle;
  final Duration _pingDuration;
  final Map<String, RtmHandler> _handlers;
  RtmSession sess;
  Rtm(
    this._token, {
    bool dumpUnhandle = false,
    Duration pingDuration = const Duration(seconds: 12),
  })
      : this._handlers = new Map<String, RtmHandler>(),
        this._dumpUnhandle = dumpUnhandle,
        this._pingDuration = pingDuration;

  /// Register message handler
  void on(String type, RtmHandler handler) {
    _handlers[type] = handler;
  }

  Timer _pingTimer(RtmSession sess) => new Timer(_pingDuration, () {
        sess._ws.add(JSON.encode({
          'type': 'ping',
          'ping': (new DateTime.now().microsecondsSinceEpoch / 1000000.0)
              .toStringAsFixed(6),
        }));
      });

  String _clean(String s) => s.replaceAll(new RegExp(r'[\000-\008]+$'), '');

  Future send(message, response) async {
    var channel = message['channel'];
    var data = {
      "type": "message",
      "channel": channel,
      "text": response
    };
    sess._ws.add(JSON.encode(data));
  }

  /// Connect to Slack.
  Future connect() async {
    final dumpExcludes = ['reconnect_url', 'pong'];

    sess = await RtmSession._connect(_token);

    var timer = _pingTimer(sess);
    await for (final msg in sess._ws) {
      timer.cancel();
      timer = _pingTimer(sess);

      final str = msg as String;
      final json = JSON.decode(_clean(str)) as Map<String, dynamic>;
      final type = json['type'] as String;
      final hand = _handlers[type];
      if (hand != null) {
        hand(json, sess);
      } else if (_dumpUnhandle && !dumpExcludes.contains(type)) {
        print('$msg');
      }
    }
  }
}

/// Slack RTM connected session.
class RtmSession {
  final Team team;
  final User bot;
  final WebSocket _ws;
  RtmSession(this.team, this.bot, this._ws);

  static Future<RtmSession> _connect(String token) async {
    final url = 'https://slack.com/api/rtm.connect';

    final response = await http.post(url, body: {'token': token});
    final json = JSON.decode(response.body) as Map<String, dynamic>;
    if (json['ok'] == true) {
      final url = json['url'] as String;
      final team = json['team'] as Map<String, dynamic>;
      final self = json['self'] as Map<String, dynamic>;

      final ws = await WebSocket.connect(url);
      return new RtmSession(
        new Team.fromJson(team),
        new User.fromJson(self),
        ws,
      );
    } else {
      final err = json['error'] as String ?? 'error';
      print(err);
      throw err;
    }
  }
}
