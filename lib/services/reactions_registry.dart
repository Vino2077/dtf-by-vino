import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/api_config.dart';
import '../util/json_safe.dart';

/// Registry mapping DTF reaction id → image uuid (served from leonardo CDN).
/// Hardcoded fallback from /v2.9/assets, refreshed at runtime when possible.
class ReactionsRegistry {
  // id -> staticUuid (from https://api.dtf.ru/v2.9/assets)
  static final Map<int, String> _static = {
    1: '5c63be49-162a-5e4e-adca-9b9c3f76314c',
    2: 'b9e9a5d6-cfbc-5d11-9b31-edad6bb6fbf0',
    3: '3f5c49f9-22bc-521d-915a-a292f6210c67',
    4: '15ad35e5-1708-58a5-a25a-d419cdd2d46a',
    5: '0f3a998f-1441-5f0f-8a5b-549bbf170c65',
    6: '2d62d1ab-8ec6-5f17-81f8-6f6f3312d283',
    7: 'ec72865d-ec4e-5299-b763-628cfd2539af',
    8: 'f8f6d0eb-8e72-50b1-af8e-c5a863a0c3b0',
    9: '080e8489-f354-52f3-b495-d3901aa329b3',
    10: '362a7194-57ee-5417-835e-bdc54d5394d4',
    11: 'b09f4923-5520-5ef9-b86d-668027a98d08',
    12: '5862140b-90b1-5c28-b0f0-8bab45beb587',
    13: '9368c0d2-e9e3-55c8-b633-c44c82095226',
    14: '6aa490dc-b161-57ac-ad47-1f6a4946b513',
    15: '898d07e7-06ea-5ff7-9ad6-8f74eb4e6f04',
    16: '825e5ec2-bd20-5d7b-a681-f0fd66de0c21',
    17: 'f8001ccc-dbc1-5c00-8991-d864aad61ef3',
    18: '55b61666-fa06-55cb-90d2-2a53ee2bf386',
    19: 'ba93fedc-c5b7-5cf6-82c4-7cdb0fa6a6a2',
    20: 'ded55fdc-8ecf-5de9-9912-13e748bdc30f',
    21: 'd9935395-45e1-5930-93cf-44581c2ce294',
    22: '7f766c9a-3720-5eaf-9a1a-3d0038876af7',
    23: '88faa3a8-281d-5f0d-8e9f-bd23d541d33b',
    24: '36cfdc28-ced9-5e6f-8195-e75975bc9f31',
    25: 'cdbfe605-aad2-57e6-abe3-df621c6b1efc',
    26: '4f273793-7fbe-5b4f-9818-1d62885511b3',
    28: '79146d35-4e27-50ac-be61-134925bb8c28',
    29: '8c0b9c07-6fe0-55f1-b485-c62d41484e57',
    31: '49d316f2-0509-563f-9061-35fd33b3aa5e',
    33: '0d857be0-89c8-5be7-a249-362169b87b17',
    34: '16998ee5-fad8-5f8b-ba97-e055c92c4192',
    35: '67c34adc-843c-586c-9058-bc39acc39e82',
    36: '6169ffa8-feb6-53ba-ba1c-f5aef99c94d0',
    37: '2e83eb55-73ea-5578-b192-f3f9875cc819',
    38: 'b86bdd6e-9266-5a7b-8d33-e3daa7b384ed',
    39: 'e03bb7ba-5bc9-58bb-8187-161d8a5faa1f',
    40: 'ba0e3326-e5ea-5d2b-9578-0ceee0c89e8d',
    41: 'd9129c05-752c-5ffc-a84f-7b4ea060333a',
    42: '4beec4a0-bf55-533f-8038-7025f3ef8f92',
    43: '8aadf75b-8379-5594-88b0-c75335964842',
    44: '290b809e-97d2-53fc-beb8-4cce58a57f63',
    45: '60674a94-589e-5e23-b6d8-7146979059e2',
    46: '54dbc6e7-ff34-5b33-916d-a85eba29490d',
    47: 'e9ca0e22-64e8-5ea2-aa08-76c1d449f762',
    48: '289ac805-d268-5f73-b1bd-22df665ab32f',
    49: '5692c883-47dc-5fed-9f35-8e9117e13608',
    50: '59d77ded-3da2-5a9f-bde7-32ecc1bb627f',
    51: '05adc583-5a04-5121-98a2-41ecfab09a6b',
    52: '05643808-db3c-5de1-999a-f24c4c65c811',
    53: '83e328b4-2192-5e20-8c2e-e1d8f301020e',
  };

  // Order shown in the reaction picker (real DTF ids, common set first).
  static const pickerOrder = [
    1, 2, 4, 3, 5, 16, 24, 22, 9, 36, 6, 25, 39, 28, 26, 34, 14, 21,
  ];

  // id → animatedUuid (only ~21 reactions are animated).
  static final Map<int, String> _animated = {};

  // DTF's CDN `-/format/gif/` for these does not actually animate (source is
  // effectively static webp) — bundled locally as real GIFs instead. id set
  // confirmed by visually matching each converted GIF against the live
  // /v2.9/assets staticUuid thumbnail for every animated id (2026-06-28).
  static const _localAnimatedIds = {
    8, 25, 34, 35, 36, 37, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53,
  };

  static String? localAnimatedAsset(int id) =>
      _localAnimatedIds.contains(id) ? 'assets/reactions/$id.gif' : null;

  static List<int> get allIds => _static.keys.toList()..sort();

  static String imageUrl(int id, {int size = 48}) {
    final uuid = _static[id];
    if (uuid == null) return '';
    return 'https://leonardo.osnova.io/$uuid/-/preview/$size/-/format/webp/';
  }

  /// Animated reaction as a looping GIF (the CDN `preview` op returns a STATIC
  /// frame, so animated reactions must use /format/gif/ without preview).
  /// Falls back to the static webp for non-animated reactions.
  static String animatedUrl(int id, {int size = 48}) {
    final anim = _animated[id];
    if (anim != null) {
      return 'https://leonardo.osnova.io/$anim/-/format/gif/';
    }
    final uuid = _static[id];
    if (uuid == null) return '';
    return 'https://leonardo.osnova.io/$uuid/-/preview/$size/-/format/webp/';
  }

  // ── Plus badges (id is a UUID string) ──────────────────────────────────────
  // id → staticUuid, loaded from /assets at runtime.
  static final Map<String, String> badges = {};
  static List<String> get badgeIds => badges.keys.toList();

  static String badgeImageUrl(String staticUuid, {int size = 48}) =>
      'https://leonardo.osnova.io/$staticUuid/-/preview/$size/-/format/webp/';

  /// Refresh reactions + badges from the live assets endpoint (best-effort).
  static Future<void> refresh() async {
    try {
      final res = await http.get(
        ApiConfig.url('assets', version: ApiConfig.vAssets),
        headers: {'User-Agent': ApiConfig.userAgent},
      ).timeout(ApiConfig.timeout);
      if (res.statusCode == 200) {
        final root = jsonDecode(res.body);
        for (final r in asList(dig(root, ['result', 'reactions']))) {
          final id = asInt(dig(r, ['id']));
          final uuid = dig(r, ['staticUuid']);
          final anim = dig(r, ['animatedUuid']);
          if (id != null && uuid is String) _static[id] = uuid;
          if (id != null && anim is String) _animated[id] = anim;
        }
        for (final b in asList(dig(root, ['result', 'badges']))) {
          final id = dig(b, ['id']);
          final uuid = dig(b, ['staticUuid']);
          if (id is String && uuid is String) badges[id] = uuid;
        }
      }
    } catch (_) {}
  }
}
