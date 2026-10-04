/// 标签与特征的简体中文显示辅助。
///
/// 词典数据见 [tag_zh.dart] 与 [trait_zh.dart],均为人工翻译并保持
/// 视觉小说术语一致。未收录的条目回退显示英文原名。
library;

import 'tag_zh.dart';
import 'trait_zh.dart';

class VndbZh {
  VndbZh._();

  /// 标签的中文译名;未收录时返回 null。
  static String? tag(String? id) {
    if (id == null) return null;
    return kTagZh[id];
  }

  /// 特征的中文译名;未收录时返回 null。
  static String? trait(String? id) {
    if (id == null) return null;
    return kTraitZh[id];
  }

  /// 特征分组名的中文译名;未收录时返回原文。
  static String traitGroup(String? name) {
    if (name == null || name.isEmpty) return '';
    return kTraitGroupZh[name] ?? name;
  }

  /// 标签分类的中文译名。
  static String tagCategory(String? category) {
    switch (category) {
      case 'cont':
        return '内容';
      case 'ero':
        return '成人内容';
      case 'tech':
        return '技术';
      default:
        return category ?? '其他';
    }
  }

  /// 列表条目的主标题:有译名时显示「中文 (English)」,否则显示英文。
  static String tagTitle(String id, String english) {
    final zh = kTagZh[id];
    if (zh == null || zh == english) return english;
    return '$zh ($english)';
  }

  /// 特征条目的主标题,同 [tagTitle]。
  static String traitTitle(String id, String english) {
    final zh = kTraitZh[id];
    if (zh == null || zh == english) return english;
    return '$zh ($english)';
  }

  /// 紧凑场景(标签小徽章、对话框)使用的短标题:优先中文,回退英文。
  static String tagShort(String id, String english) {
    return kTagZh[id] ?? english;
  }

  /// 特征小徽章短标题:优先中文,回退英文。
  static String traitShort(String id, String english) {
    return kTraitZh[id] ?? english;
  }

  /// 制作方类型的中文译名。
  static String producerType(String? type) {
    switch (type) {
      case 'co':
        return '公司';
      case 'in':
        return '个人';
      case 'ng':
        return '同人社团';
      default:
        return type ?? '未知';
    }
  }

  /// 角色 steam 身份(role)的中文译名。
  static String characterRole(String? role) {
    switch (role) {
      case 'main':
        return '主人公';
      case 'primary':
        return '主要角色';
      case 'side':
        return '次要角色';
      case 'appears':
        return '客串登场';
      default:
        return role ?? '';
    }
  }

  /// 发行版在用户列表中的状态(rlist status)。
  static String releaseListStatus(int status) {
    switch (status) {
      case 1:
        return '待入手';
      case 2:
        return '已入手';
      case 3:
        return '外借中';
      case 4:
        return '已删除';
      default:
        return '未知';
    }
  }

  /// 制作人员职务(staff role)的中文译名。
  static String staffRole(String role) {
    const map = {
      'scenario': '剧本',
      'script': '剧本',
      'director': '导演',
      'art': '美术',
      'music': '音乐',
      'songs': '音乐',
      'staff': '制作人员',
      'seiyuu': '配音',
      'producer': '制作人',
      'character design': '角色设计',
      'chardesign': '角色设计',
      'cg': 'CG',
      'graphics': '图像',
      'vocals': '演唱',
      'voice actor': '配音',
    };
    return map[role.toLowerCase()] ?? role;
  }
}
