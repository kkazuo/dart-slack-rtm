# slack_rtm

A library for Slack RTM client developers.

## Usage

A simple usage example:

    import 'package:slack_rtm/slack_rtm.dart';

    void main() {
      final token = 'xoxb-your-slacktoken';

      final rtm = new Rtm(token, dumpUnhandle: true)
        ..on(RtmEvent.hello, (msg, sess) {
          print('>> $msg');
        });
      rtm.connect();
    }

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/kkazuo/dart-slack-rtm/issues
