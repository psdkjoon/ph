import 'package:ph/load.dart';
import 'package:ph/meet/create_meet.dart';
import 'package:ph/math/solve.dart';
import 'package:ptgb/ptgb.dart';

Future<void> main() async {
  final bot = Bot();
  List<int> allowedChats = getAllowedChats();
  bot.setMyCommands(
    commands: [
      {'command': 'help', 'description': 'Sends help page'},
    ],
  );
  await for (Update update in bot.poll()) {
    final chatId = update.chatId;
    final text = update.text;
    if (chatId == null || text == null) continue;

    if (text.toLowerCase() == 'meet' && allowedChats.contains(chatId)) {
      bot.sendMessage(
        chatId: chatId,
        text: await createGoogleMeet(),
        replyToMessageId: update.messageId,
      );
    } else if (RegExp(
      r'^(?=.*\d.*(?:[-+*/%^<>]|//))\s*[-+]?\s*\(*\s*[-+]?\s*\d+\.?\d*\s*\)*(?:\s*(?:[-+*/%^<>]|//)\s*[-+]?\s*\(*\s*[-+]?\s*\)*)*$',
    ).hasMatch(text)) {
      final equation = RegExp(r'\d+\.?\d*|//|[-+*/%^()]')
          .allMatches(text)
          .map((m) => m[0]!)
          .toList();
      bot.sendMessage(
        chatId: chatId,
        text: solve(equation)
            .toStringAsFixed(10)
            .replaceFirst(RegExp(r'\.?0+$'), ''),
        replyToMessageId: update.messageId,
      );
    } else if (text.startsWith('/help')) {
      if (update.entities != null &&
          update.entities?[0]['type'] == 'bot_command') {
        bot.sendMessage(
          chatId: 8995144898,
          text: '''
*Calculator Help*

Supports basic arithmetic expressions with numbers, decimals, and parentheses\.

*Operators:*
`+` `-` `*` `/` `//` \(integer division\) `%` \(remainder\) `^` \(power\)

*Examples:*
`5+5`
`\(80+90\)-10`
`2^3*4`
        ''',
          parseMode: ParseMode.markdown,
        );
      }
    }
  }
}
