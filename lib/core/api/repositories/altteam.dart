import '../network/api.dart';
import 'dart:typed_data';

class AltTemRepository {

  Future<void> resetPasswordByEmail(String email) async {
    await Api.post('/g/s/altteam/reset-password', body: {
      "email": email
    });
  }

  Future<Map<String, dynamic>> getReports({
    required String segment,
    required int start,
    required int size,
    required String pageToken,
  }) async {
    final resolvedSegment = segment.isEmpty ? 'all' : segment;

    final path = '/g/s/altteam/reports'
        '?segment=${Uri.encodeComponent(resolvedSegment)}'
        '&start=$start'
        '&size=$size'
        '&pageToken=${Uri.encodeComponent(pageToken)}';

    return await Api.get(path);
  }

  Future<Map<String, dynamic>> getTeam() async {
    return await Api.get('/g/s/altteam');
  }


  Future<void> editTeamMember({
    required String userId,
    int? role,
    List<String>? tagList,
    bool? isMemberOfTeamAmino,
    bool? isVerified,
  }) async {
    await Api.post('/g/s/altteam/$userId/edit', body: {
      if (role != null) "role": role,
      if (tagList != null) "tagList": tagList,
      if (isMemberOfTeamAmino != null) "isMemberOfTeamAmino": isMemberOfTeamAmino,
      if (isVerified != null) "isVerified": isVerified,
    });
  }

  Future<void> setUserStatus({required String userId, required int status}) async {
    await Api.post('/g/s/altteam/user-profile/$userId/status', body: {
      "status": status,
    });
  }

  Future<Map<String, dynamic>> getUserCommunities(String userId) async {
    return await Api.get('/g/s/altteam/user-profile/$userId/communities');
  }


  Future<void> setModerationStatus({
    required String type, // 'user' or 'community' ect
    required String objId,
    required bool disable,
  }) async {
    final action = disable ? 'disable' : 'enable';
    await Api.post('/g/s/altteam/mod/$type/$action/$objId');
  }


  Future<Map<String, dynamic>> getOnlineUsers({
    int start = 0,
    int size = 30,
  }) async {
    return await Api.get('/g/s/altteam/online?start=$start&size=$size');
  }




  // DISCOVER

  Future<Map<String, dynamic>> getDiscoverBanners() async {
    return await Api.get('/g/s/altteam/discover/banners');
  }

  Future<void> createDiscoverBanner({
    required String imageUrl,
    String? landingUrl,
    String? deepLink,
    String? segment,
  }) async {
    await Api.post('/g/s/altteam/discover/banners/create', body: {
      "imageUrl": imageUrl,
      "landingUrl": landingUrl,
      "deepLink": deepLink,
      "segment": segment,
    });
  }

  Future<void> editDiscoverBanner(
    String id, {
    String? imageUrl,
    String? landingUrl,
    String? deepLink,
    String? segment,
    bool? enabled,
  }) async {
    await Api.post('/g/s/altteam/discover/banners/$id/edit', body: {
      if (imageUrl != null) "imageUrl": imageUrl,
      if (landingUrl != null) "landingUrl": landingUrl,
      if (enabled != null) "enabled": enabled,
      if (deepLink != null) "deepLink": deepLink,
      if (segment != null) "segment": segment,
    });
  }

  Future<void> deleteDiscoverBanner(String id) async {
    await Api.post('/g/s/altteam/discover/banners/$id/delete');
  }

  Future<void> reorderDiscoverBanners(List<String> ids) async {
    await Api.post('/g/s/altteam/discover/banners/reorder', body: {"ids": ids});
  }

  Future<Map<String, dynamic>> getDiscoverPicks() async {
    return await Api.get('/g/s/altteam/discover/picks');
  }

  Future<Map<String, dynamic>> searchDiscoverCommunities({
    required String query,
    int start = 0,
    int size = 20,
  }) async {
    return await Api.get(
      '/g/s/altteam/discover/communities/search'
      '?query=${Uri.encodeComponent(query)}&start=$start&size=$size',
    );
  }

  Future<void> setDiscoverPick(int ndcId, {required bool selected}) async {
    await Api.post('/g/s/altteam/discover/picks/$ndcId/set', body: {
      "selected": selected,
    });
  }

  Future<void> reorderDiscoverTeamPicks(List<String> ids) async {
    await Api.post('/g/s/altteam/discover/picks/reorder', body: {"picks": ids});
  }



  // STORE

  Future<Map<String, dynamic>> getAvatarFrames() async {
    return await Api.get('/g/s/altteam/altstore/avatar-frame');
  }

  Future<Map<String, dynamic>> createAvatarFrame({
    required String resourceUrl,
    String? icon,
    int frameType = 1,
    String description = '',
    int price = 0,
    int? restrictType,
    int? discountStatus,
    int? discountValue,
    int? availableDuration,
    List<int>? availableNdcIds,
  }) async {
    return await Api.post('/g/s/altteam/altstore/avatar-frame', body: {
      "resourceUrl": resourceUrl,
      if (icon != null) "icon": icon,
      "frameType": frameType,
      "description": description,
      "price": price,
      if (restrictType != null) "restrictType": restrictType,
      if (discountStatus != null) "discountStatus": discountStatus,
      if (discountValue != null) "discountValue": discountValue,
      if (availableDuration != null) "availableDuration": availableDuration,
      if (availableNdcIds != null) "availableNdcIds": availableNdcIds,
    });
  }

  Future<void> editAvatarFrame(String frameId, Map<String, dynamic> changes) async {
    await Api.post('/g/s/altteam/altstore/avatar-frame/$frameId/edit',
        body: changes);
  }

  Future<void> deleteAvatarFrame(String frameId) async {
    await Api.post('/g/s/altteam/altstore/avatar-frame/$frameId/delete');
  }

  Future<Map<String, dynamic>> getChatBubbles() async {
    return await Api.get('/g/s/altteam/altstore/chat-bubble');
  }

  Future<Map<String, dynamic>> createChatBubble({
    required String resourceUrl,
    String? backgroundImage,
    String? bannerImage,
    int price = 0,
    int? restrictType,
    int? discountStatus,
    int? discountValue,
    int? availableDuration,
    List<int>? availableNdcIds,
  }) async {
    return await Api.post('/g/s/altteam/altstore/chat-bubble', body: {
      "resourceUrl": resourceUrl,
      if (backgroundImage != null) "backgroundImage": backgroundImage,
      if (bannerImage != null) "bannerImage": bannerImage,
      "price": price,
      if (restrictType != null) "restrictType": restrictType,
      if (discountStatus != null) "discountStatus": discountStatus,
      if (discountValue != null) "discountValue": discountValue,
      if (availableDuration != null) "availableDuration": availableDuration,
      if (availableNdcIds != null) "availableNdcIds": availableNdcIds,
    });
  }

  Future<void> editChatBubble(String bubbleId, Map<String, dynamic> changes) async {
    await Api.post('/g/s/altteam/altstore/chat-bubble/$bubbleId/edit',
        body: changes);
  }

  Future<void> deleteChatBubble(String bubbleId) async {
    await Api.post('/g/s/altteam/altstore/chat-bubble/$bubbleId/delete');
  }


  Future<Map<String, dynamic>> uploadStoreArchive(
    Uint8List zipBytes, {
    required String target, // 'avatar-frame' | 'chat-bubble' |
  }) async {
    return await Api.post(
      '/g/s/media/upload/target/$target',
      body: zipBytes,
      headers: {'Content-Type': 'application/octet-stream'},
    );
  }


}


