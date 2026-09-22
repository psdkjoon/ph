import 'package:penv/penv.dart';

List<int> getAllowedChats() {
  List<int> res = [];
  String list = penvload('.env')['ALLOWED_CHATS']!;
  for (String part in list.split(',')) {
    res.add(int.parse(part));
  }
  return res;
}
