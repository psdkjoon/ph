import 'package:ph/meet/create_meet.dart';
import 'package:ptgb/ptgb.dart';

Future<void> main() async {
  final bot = Bot();
  await for (Update update in bot.poll()) {
    if(update.text=='meet'){
      bot.sendMessage(chatId: update.chatId!, text: await createGoogleMeet(), replyToMessageId: update.messageId);
    }
  }
}
