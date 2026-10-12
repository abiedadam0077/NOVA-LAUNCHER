import 'dart:async';
import 'dart:convert';

import '../domain/models.dart';
import 'http.dart';

/// Microsoft OAuth2 Device Code flow (no password ever enters the app),
/// chained to Xbox Live -> XSTS -> Minecraft services -> profile.
///
/// HONEST CONSTRAINT: completing this chain against Minecraft requires an
/// Azure app registration with Xbox Live sign-in permission. NOVA ships with
/// a configurable client id; when none is configured the UI explains the
/// requirement and local profiles remain available.
class MicrosoftAuth {
  MicrosoftAuth(this.http);

  final NovaHttp http;

  static const String tenants = 'consumers';
  static const String scope = 'XboxLive.signin offline_access';

  bool hasClientId(String? clientId) =>
      clientId != null && clientId.trim().isNotEmpty;

  Future<DeviceCode?> startDeviceCode(String clientId) async {
    final res = await http.post(
      'https://login.microsoftonline.com/$tenants/oauth2/v2.0/devicecode',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'client_id=${Uri.encodeComponent(clientId)}'
          '&scope=${Uri.encodeComponent(scope)}',
    );
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return DeviceCode(
      deviceCode: j['device_code'] as String,
      userCode: j['user_code'] as String? ?? '',
      verificationUri: j['verification_uri'] as String? ?? 'https://www.microsoft.com/link',
      interval: (j['interval'] as num?)?.toInt() ?? 5,
      expiresIn: (j['expires_in'] as num?)?.toInt() ?? 900,
    );
  }

  /// Polls until a token is granted, times out, or is cancelled.
  Future<String?> pollToken({
    required String clientId,
    required DeviceCode code,
    required FutureOr<bool> Function() isCancelled,
    Duration? maxWait,
  }) async {
    final deadline = DateTime.now().add(maxWait ?? Duration(seconds: code.expiresIn));
    while (DateTime.now().isBefore(deadline)) {
      if (await isCancelled()) return null;
      await Future<void>.delayed(Duration(seconds: code.interval));
      final res = await http.post(
        'https://login.microsoftonline.com/$tenants/oauth2/v2.0/token',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=urn:ietf:params:oauth:grant-type:device_code'
            '&client_id=${Uri.encodeComponent(clientId)}'
            '&device_code=${Uri.encodeComponent(code.deviceCode)}',
      );
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        return j['access_token'] as String?;
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>?;
      final err = j?['error'] as String?;
      if (err != null && err != 'authorization_pending' && err != 'slow_down') {
        return null;
      }
    }
    return null;
  }

  /// Full chain to a Minecraft profile. Returns null on any failed step.
  Future<MinecraftProfile?> completeChain(String accessToken) async {
    // 1) Xbox Live
    final xbl = await http.post(
      'https://user.auth.xboxlive.com/user/authenticate',
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'Properties': {
          'AuthMethod': 'RPS',
          'SiteName': 'user.auth.xboxlive.com',
          'RpsTicket': 'd=$accessToken',
        },
        'RelyingParty': 'http://auth.xboxlive.com',
        'TokenType': 'JWT',
      }),
    );
    if (xbl.statusCode != 200) return null;
    final xblJ = jsonDecode(xbl.body) as Map<String, dynamic>;
    final xblToken = xblJ['Token'] as String?;
    final uhs = ((xblJ['DisplayClaims'] as Map<String, dynamic>?)?['xui']
            as List?)?.first?['uhs'] as String?;
    if (xblToken == null || uhs == null) return null;

    // 2) XSTS
    final xsts = await http.post(
      'https://xsts.auth.xboxlive.com/xsts/authorize',
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'Properties': {
          'SandboxId': 'RETAIL',
          'UserTokens': [xblToken],
        },
        'RelyingParty': 'rp://api.minecraftservices.com/',
        'TokenType': 'JWT',
      }),
    );
    if (xsts.statusCode != 200) return null;
    final xstsToken =
        (jsonDecode(xsts.body) as Map<String, dynamic>)['Token'] as String?;
    if (xstsToken == null) return null;

    // 3) Minecraft login
    final mc = await http.post(
      'https://api.minecraftservices.com/authentication/login_with_xbox',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identityToken': 'XBL3.0 x=$uhs;$xstsToken'}),
    );
    if (mc.statusCode != 200) return null;
    final mcToken =
        (jsonDecode(mc.body) as Map<String, dynamic>)['access_token'] as String?;
    if (mcToken == null) return null;

    // 4) Profile (requires game ownership)
    final prof = await http.get(
      'https://api.minecraftservices.com/minecraft/profile',
      headers: {'Authorization': 'Bearer $mcToken'},
    );
    if (prof.statusCode != 200) return null;
    final pj = jsonDecode(prof.body) as Map<String, dynamic>;
    String? skinUrl;
    for (final s in (pj['skins'] as List? ?? [])) {
      final sm = s as Map<String, dynamic>;
      if (sm['state'] == 'ACTIVE') skinUrl = sm['url'] as String?;
    }
    return MinecraftProfile(
      uuid: pj['id'] as String? ?? '',
      name: pj['name'] as String? ?? '',
      skinUrl: skinUrl,
    );
  }
}

class DeviceCode {
  const DeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.interval,
    required this.expiresIn,
  });
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int interval;
  final int expiresIn;
}

class MinecraftProfile {
  const MinecraftProfile({required this.uuid, required this.name, this.skinUrl});
  final String uuid;
  final String name;
  final String? skinUrl;
}
