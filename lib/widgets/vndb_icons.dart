import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Helpers for rendering the bundled VNDB icon assets:
/// - `assets/images/lang/<code>.png` — language flag icons
/// - `assets/images/plat/<code>.svg`  — platform icons
/// - `assets/images/list/<code>.svg`  — user-list status icons
class VndbIcons {
  VndbIcons._();

  /// Returns the asset path for a language flag, or null when no flag is
  /// bundled for the given language code.
  static String? langAsset(String? lang) {
    if (lang == null || lang.isEmpty) return null;
    final path = 'assets/images/lang/$lang.png';
    if (_langCodes.contains(lang)) return path;
    return null;
  }

  /// Returns the asset path for a platform icon, or null when unknown.
  static String? platAsset(String? plat) {
    if (plat == null || plat.isEmpty) return null;
    if (_platCodes.contains(plat)) return 'assets/images/plat/$plat.svg';
    return null;
  }

  /// Returns the asset path for a user-list status icon.
  ///
  /// Map: 1=Playing, 2=Finished, 3=Stalled, 4=Dropped, 5=Wishlist,
  /// 6=Blacklist. `add` and `unknown` are also available.
  static String listAsset(int labelId) {
    const map = {
      1: 'l1',
      2: 'l2',
      3: 'l3',
      4: 'l4',
      5: 'l5',
      6: 'l6',
    };
    final name = map[labelId];
    if (name == null) return 'assets/images/list/unknown.svg';
    return 'assets/images/list/$name.svg';
  }

  /// A small flag [Image] for the given language code.
  static Widget? langImage(String? lang, {double size = 16}) {
    final path = langAsset(lang);
    if (path == null) return null;
    return Image.asset(path, width: size, height: size, fit: BoxFit.contain);
  }

  /// A small platform [SvgPicture] for the given platform code.
  static Widget? platImage(String? plat, {double size = 16}) {
    final path = platAsset(plat);
    if (path == null) return null;
    return SvgPicture.asset(path, width: size, height: size);
  }

  /// A small list-status [SvgPicture] for the given label id.
  static Widget listImage(int labelId, {double size = 18}) {
    return SvgPicture.asset(listAsset(labelId), width: size, height: size);
  }

  /// A row of language flags for a list of language codes.
  static Widget langRow(List<String> langs, {double size = 14}) {
    final children = <Widget>[];
    for (final l in langs) {
      final img = langImage(l, size: size);
      if (img != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(right: 2),
          child: img,
        ));
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  /// A row of platform icons for a list of platform codes.
  static Widget platRow(List<String> plats, {double size = 14}) {
    final children = <Widget>[];
    for (final p in plats) {
      final img = platImage(p, size: size);
      if (img != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(right: 2),
          child: img,
        ));
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  /// Language codes that have a bundled flag icon.
  static const _langCodes = <String>{
    'ar', 'be', 'bg', 'bs', 'ca', 'ck', 'cs', 'da', 'de', 'el', 'en', 'eo',
    'es', 'et', 'eu', 'fa', 'fi', 'fr', 'ga', 'gd', 'gl', 'he', 'hi', 'hr',
    'hu', 'id', 'it', 'iu', 'ja', 'kk', 'ko', 'la', 'lt', 'lv', 'ms', 'nl',
    'no', 'pl', 'pt', 'ro', 'ru', 'sk', 'sl', 'sq', 'sr', 'sv', 'ta', 'th',
    'tr', 'uk', 'vi', 'zh',
  };

  /// Platform codes that have a bundled icon.
  static const _platCodes = <String>{
    'and', 'bdp', 'dos', 'drc', 'dvd', 'fm7', 'fm8', 'fmt', 'gba', 'gbc',
    'ios', 'lin', 'mac', 'mob', 'msx', 'n3d', 'nds', 'nes', 'oth', 'p88',
    'p98', 'pce', 'pcf', 'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'psp', 'psv',
    'sat', 'scd', 'sfc', 'smd', 'sw2', 'swi', 'tdo', 'vnd', 'web', 'wii',
    'win', 'wiu', 'x1s', 'x68', 'xb1', 'xb3', 'xbo', 'xxs',
  };
}
