import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Slack Team
class Team {
  final String id;
  final String name;
  final String domain;

  const Team(this.id, this.name, this.domain);

  factory Team.fromJson(Map<String, dynamic> j) => Team(
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

  factory User.fromJson(Map<String, dynamic> j) => User(
        j['id'] as String,
        j['name'] as String,
      );

  Map toJson() => <String, dynamic>{
        'id': id,
        'name': name,
      };
}

/// Slack RTM handler
typedef RtmHandler = void Function(Map<String, dynamic> msg, RtmSession sess);

/// Slack RTM controller
class Rtm {
  final String _token;
  final bool _dumpUnhandle;
  final Duration _pingDuration;
  final Map<String, RtmHandler> _handlers;
  RtmSession? sess;
  Rtm(
    this._token, {
    bool dumpUnhandle = false,
    Duration pingDuration = const Duration(seconds: 12),
  })  : _handlers = <String, RtmHandler>{},
        _dumpUnhandle = dumpUnhandle,
        _pingDuration = pingDuration;

  /// Register message handler
  void on(String type, RtmHandler handler) {
    _handlers[type] = handler;
  }

  Timer _pingTimer(RtmSession sess) => Timer(_pingDuration, () {
        sess._ws.add(
          jsonEncode({
            'type': 'ping',
            'ping': (DateTime.now().microsecondsSinceEpoch / 1000000.0)
                .toStringAsFixed(6),
          }),
        );
      });

  String _clean(String s) => s.replaceAll(RegExp(r'[\000-\008]+$'), '');

  Future send(Map<String, dynamic> message, String response) async {
    final channel = message['channel'] as String;
    final data = {"type": "message", "channel": channel, "text": response};
    sess?._ws.add(jsonEncode(data));
  }

  /// Connect to Slack.
  Future connect() async {
    final dumpExcludes = ['reconnect_url', 'pong'];

    final sess = await RtmSession._connect(_token);
    this.sess = sess;

    var timer = _pingTimer(sess);
    await for (final msg in sess._ws) {
      timer.cancel();
      timer = _pingTimer(sess);

      final str = msg as String;
      final json = jsonDecode(_clean(str)) as Map<String, dynamic>;
      final type = json['type'] as String;
      final hand = _handlers[type];
      if (hand != null) {
        hand(json, sess);
      } else if (_dumpUnhandle && !dumpExcludes.contains(type)) {
        print(msg);
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

  void dispose() {
    _ws.close();
  }

  static Future<RtmSession> _connect(String token) async {
    final url = Uri.parse('https://slack.com/api/rtm.connect');

    final response = await http.post(url, body: {'token': token});
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['ok'] == true) {
      final url = json['url'] as String;
      final team = json['team'] as Map<String, dynamic>;
      final self = json['self'] as Map<String, dynamic>;

      return RtmSession(
        Team.fromJson(team),
        User.fromJson(self),
        await WebSocket.connect(url),
      );
    } else {
      final err = json['error'];
      throw Exception('RTM connect error: $err');
    }
  }
}
