import 'dart:convert';
import 'dart:typed_data';

/// 后端 login 返回的 p_token 是用户信息经 XOR 混淆（key 见下）后 base64 打包而成。
/// 混淆实现与 worker.js 的 obfuscateLogin 对应，这里做逆运算解码。
const _loginObfKey = 'PHANTOM_LOGIN_OBF_KEY_2024';

String _deobfuscateLogin(String b64) {
  final key = utf8.encode(_loginObfKey);
  final bytes = base64.decode(b64);
  final out = Uint8List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    out[i] = bytes[i] ^ key[i % key.length];
  }
  return utf8.decode(out);
}

/// 解码 p_token，还原出 {u: userInfo, p: pricePlan, e: expMs}。
/// 兼容旧格式 token（<uuid>.<expMs> 形式）时返回 null，调用方需自行降级处理。
Map<String, dynamic>? decodePToken(String pToken) {
  try {
    final jsonStr = _deobfuscateLogin(pToken);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  } catch (e) {
    return null;
  }
}
