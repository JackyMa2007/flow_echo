import 'dart:convert';

// ignore: unintended_html_in_doc_comment
/// 将 Map<String, Object?> 对象序列化为 JSON 字符串
String encodeObjectMap(Map<String, Object?> value) {
  return jsonEncode(value);
}

// ignore: unintended_html_in_doc_comment
/// 将 JSON 字符串反序列化为 Map<String, Object?>
/// 异常兜底：输入不是字符串、空字符串、解析结果不是Map时，返回空Map
Map<String, Object?> decodeObjectMap(Object? value) {
  if (value is! String || value.isEmpty) {
    return <String, Object?>{};
  }

  final decoded = jsonDecode(value);
  if (decoded is! Map) {
    return <String, Object?>{};
  }

// 统一把key转为字符串，保证类型符合 Map<String, Object?>
  return decoded.map((key, item) => MapEntry(key.toString(), item as Object?));
}
