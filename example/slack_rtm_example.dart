import 'package:slack_rtm/slack_rtm.dart';

void main() {
  final token = 'xoxb-your-slacktoken';

  final rtm = new Rtm(token, dumpUnhandle: true)
    ..on(RtmEvent.hello, (msg, sess) {
      print('>> $msg');
    });
  rtm.connect();
}
