import '../network/api.dart';

class UsersRepository {
  Future<Map<String, dynamic>> getUserProfile(String userId, int ndcId) async {
    final res = await Api.get('/${(ndcId == 0) ? 'g' : 'x$ndcId'}/s/user-profile/${userId}');
    return (res['userProfile'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getAltTeam() async {
    final res = await Api.get('/g/s/altteam');
    final list = res['userProfileList'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }


Future<Map<String, dynamic>> banUser({
    String? userId,
    int? ndcId,
    String? reason,
    int? banType,
  }) async {

    final Map<String, dynamic> data = {
      if (banType != null) "reasonType": banType,
      "note": {
        "content": reason ?? "No reason provided.",
      },
    };

    final res = await Api.post(
      '/${(ndcId == 0) ? 'g' : 'x$ndcId'}/s/user-profile/$userId/ban',
      body: data,
    );
    
    return (res as Map<String, dynamic>?) ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> unbanUser({
    String? userId,
    int? ndcId,
    String? reason,
  }) async {

    
    final Map<String, dynamic> data = {
      "note": {
        "content": reason ?? "No reason provided.",
      },
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    };

    final res = await Api.post(
      '/${(ndcId == 0) ? 'g' : 'x$ndcId'}/s/user-profile/$userId/unban',
      body: data,
    );

    return (res as Map<String, dynamic>?) ?? <String, dynamic>{};
  }

Future<Map<String, dynamic>> hideUser({
    String? userId,
    int? ndcId,
    String? reason,
  }) async {

    final Map<String, dynamic> data = {
      if (reason != null) "adminOpNote": {
        "content": reason,
      },
      "uid": userId,
      "adminOpName": 18
    };

    final res = await Api.post(
      '/${(ndcId == 0) ? 'g' : 'x$ndcId'}/s/user-profile/$userId/admin',
      body: data,
    );
    
    return (res as Map<String, dynamic>?) ?? <String, dynamic>{};
  }
Future<Map<String, dynamic>> unhideUser({
    String? userId,
    int? ndcId,
    String? reason,
  }) async {

    final Map<String, dynamic> data = {
      if (reason != null) "adminOpNote": {
        "content": reason,
      },
      "uid": userId,
      "adminOpName": 19
    };

    final res = await Api.post(
      '/${(ndcId == 0) ? 'g' : 'x$ndcId'}/s/user-profile/$userId/admin',
      body: data,
    );
    
    return (res as Map<String, dynamic>?) ?? <String, dynamic>{};
  }





Future<Map<String, dynamic>> _sendNotice({
  required int ndcId,
  required String userId,
  required String title,
  required String content,
  required int noticeType,
  required int penaltyType,
  int? penaltyValue,
  String? reason,
  String? objectId,
  int objectType = 0,
  String? moderatorUid,
}) async {
  final data = <String, dynamic>{
    "uid": userId,
    "title": title,
    "content": content,
    "attachedObject": {
      "objectId": objectId ?? userId,
      "objectType": objectType,
    },
    "penaltyType": penaltyType,
    if (penaltyValue != null) "penaltyValue": penaltyValue,
    "adminOpNote":
        (reason != null && reason.isNotEmpty) ? {"content": reason} : {},
    "noticeType": noticeType,
    "timestamp": DateTime.now().millisecondsSinceEpoch,
  };

  final res = await Api.post(
    '/${(ndcId == 0) ? 'g' : 'x$ndcId'}/s/notice',
    body: data,
  );
  return (res as Map<String, dynamic>?) ?? <String, dynamic>{};
}

Future<Map<String, dynamic>> warnUser({
  required String userId,
  required int ndcId,
  required String title,
  required String content,
  String? reason,
  String? objectId,
  int objectType = 0,
  String? moderatorUid,
}) {
  return _sendNotice(
    ndcId: ndcId,
    userId: userId,
    title: title,
    content: content,
    noticeType: 7,
    penaltyType: 0,
    reason: reason,
    objectId: objectId,
    objectType: objectType,
    moderatorUid: moderatorUid,
  );
}

Future<Map<String, dynamic>> strikeUser({
  required String userId,
  required int ndcId,
  required String title,
  required String content,
  required int durationSeconds,
  String? reason,
  String? objectId,
  int objectType = 0,
  String? moderatorUid,
}) {
  return _sendNotice(
    ndcId: ndcId,
    userId: userId,
    title: title,
    content: content,
    noticeType: 4,
    penaltyType: 1,
    penaltyValue: durationSeconds,
    reason: reason,
    objectId: objectId,
    objectType: objectType,
    moderatorUid: moderatorUid,
  );
}


  Future<Map<String, dynamic>> getWarningTemplate(int ndcId) async {
    return await Api.get('/x$ndcId/s/notice/message-template/warning');
  }

  Future<Map<String, dynamic>> getStrikeTemplate(int ndcId) async {
    return await Api.get('/x$ndcId/s/notice/message-template/strike');
  }


}

