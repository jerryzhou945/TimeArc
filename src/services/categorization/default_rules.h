// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_CATEGORIZATION_DEFAULT_RULES_H
#define TIMEARC_SERVICES_CATEGORIZATION_DEFAULT_RULES_H

#include "services/categorization/rule.h"

// GENERATED TABLE - the shipped default categorization.
//
// English-first: every label carries "en"; other locales are optional and
// fall back to it. Non-ASCII uses \uXXXX escapes because the build sets no
// /utf-8 flag (see normalize.h).
//
// This is data, not logic. Adding an app is one entry here - no registry, no
// second table, no keyword ladder. Regenerate with
// scratchpad/gen_rules.py if you prefer editing the readable source.
namespace TimeArc::Categorization {

inline constexpr int kDefaultTableVersion = 1;

namespace detail {

inline Rule makeRule(const QString& id, const QString& category,
                     const QString& labelEn, const QStringList& app,
                     const QStringList& title) {
  Rule rule;
  rule.id = id;
  rule.category = category;
  rule.label.insert(QStringLiteral("en"), labelEn);
  rule.app = app;
  rule.title = title;
  return rule;
}

inline Rule withIcon(Rule rule, const QString& icon) {
  rule.icon = icon;
  return rule;
}

inline Rule withLabel(Rule rule, const QString& language,
                      const QString& text) {
  rule.label.insert(language, text);
  return rule;
}

inline CategoryDef makeCategory(const QString& id, const QString& en,
                                const QString& zh, const QString& ja,
                                const QStringList& traits) {
  CategoryDef category;
  category.id = id;
  category.label.insert(QStringLiteral("en"), en);
  category.label.insert(QStringLiteral("zh"), zh);
  category.label.insert(QStringLiteral("ja"), ja);
  category.traits = traits;
  return category;
}

}  // namespace detail

inline QVector<CategoryDef> defaultCategories() {
  return {
      detail::makeCategory(QStringLiteral("dev"), QStringLiteral("Development"), QStringLiteral("\u5F00\u53D1"), QStringLiteral("\u958B\u767A"),
                           {QStringLiteral("focus")}),
      detail::makeCategory(QStringLiteral("office"), QStringLiteral("Office"), QStringLiteral("\u529E\u516C"), QStringLiteral("\u30AA\u30D5\u30A3\u30B9"),
                           {QStringLiteral("focus")}),
      detail::makeCategory(QStringLiteral("notes"), QStringLiteral("Notes"), QStringLiteral("\u7B14\u8BB0"), QStringLiteral("\u30CE\u30FC\u30C8"),
                           {QStringLiteral("focus")}),
      detail::makeCategory(QStringLiteral("create"), QStringLiteral("Creation"), QStringLiteral("\u521B\u4F5C"), QStringLiteral("\u5236\u4F5C"),
                           {}),
      detail::makeCategory(QStringLiteral("social"), QStringLiteral("Social"), QStringLiteral("\u793E\u4EA4"), QStringLiteral("\u30BD\u30FC\u30B7\u30E3\u30EB"),
                           {}),
      detail::makeCategory(QStringLiteral("video"), QStringLiteral("Video"), QStringLiteral("\u89C6\u9891"), QStringLiteral("\u52D5\u753B"),
                           {QStringLiteral("entertainment")}),
      detail::makeCategory(QStringLiteral("music"), QStringLiteral("Music"), QStringLiteral("\u97F3\u4E50"), QStringLiteral("\u97F3\u697D"),
                           {}),
      detail::makeCategory(QStringLiteral("game"), QStringLiteral("Games"), QStringLiteral("\u6E38\u620F"), QStringLiteral("\u30B2\u30FC\u30E0"),
                           {QStringLiteral("entertainment")}),
      detail::makeCategory(QStringLiteral("browse"), QStringLiteral("Browsing"), QStringLiteral("\u6D4F\u89C8"), QStringLiteral("\u30D6\u30E9\u30A6\u30BA"),
                           {}),
      detail::makeCategory(QStringLiteral("read"), QStringLiteral("Reading"), QStringLiteral("\u9605\u8BFB"), QStringLiteral("\u8AAD\u66F8"),
                           {}),
      detail::makeCategory(QStringLiteral("shop"), QStringLiteral("Shopping"), QStringLiteral("\u8D2D\u7269"), QStringLiteral("\u30B7\u30E7\u30C3\u30D4\u30F3\u30B0"),
                           {}),
      detail::makeCategory(QStringLiteral("system"), QStringLiteral("System"), QStringLiteral("\u7CFB\u7EDF"), QStringLiteral("\u30B7\u30B9\u30C6\u30E0"),
                           {QStringLiteral("deprioritize")}),
      detail::makeCategory(QStringLiteral("other"), QStringLiteral("Other"), QStringLiteral("\u5176\u4ED6"), QStringLiteral("\u305D\u306E\u4ED6"),
                           {})
  };
}

inline QVector<Rule> defaultRules() {
  QVector<Rule> rules;
  rules.reserve(239);
  rules.append(detail::makeRule(QStringLiteral("app:windows-system"), QStringLiteral("system"), QStringLiteral("Windows Shell"),
                   {QStringLiteral("startmenuexperiencehost"), QStringLiteral("searchhost"), QStringLiteral("searchapp"), QStringLiteral("shellexperiencehost"), QStringLiteral("lockapp"), QStringLiteral("applicationframehost"), QStringLiteral("textinputhost"), QStringLiteral("dwm.exe"), QStringLiteral("sihost"), QStringLiteral("ctfmon"), QStringLiteral("systemsettings"), QStringLiteral("useroobe"), QStringLiteral("rundll32"), QStringLiteral("taskmgr"), QStringLiteral("winlogon"), QStringLiteral("fontdrvhost"), QStringLiteral("wininit"), QStringLiteral("csrss"), QStringLiteral("smartscreen"), QStringLiteral("runtimebroker"), QStringLiteral("taskhostw"), QStringLiteral("dllhost"), QStringLiteral("conhost"), QStringLiteral("wmiprvse"), QStringLiteral("audiodg"), QStringLiteral("widgets.exe"), QStringLiteral("backgroundtaskhost"), QStringLiteral("securityhealthsystray"), QStringLiteral("crashpad_handler"), QStringLiteral("werfault"), QStringLiteral("pickerhost"), QStringLiteral("permissioncenterui")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:windows-service-host"), QStringLiteral("system"), QStringLiteral("Service Host"),
                   {QStringLiteral("svchost")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:nvidia-container"), QStringLiteral("system"), QStringLiteral("NVIDIA Container"),
                   {QStringLiteral("nvcontainer")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:file-explorer"), QStringLiteral("system"), QStringLiteral("File Explorer"),
                   {QStringLiteral("explorer.exe"), QStringLiteral("windows\\explorer")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:finder"), QStringLiteral("system"), QStringLiteral("Finder"),
                   {QStringLiteral("com.apple.finder")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:macos-shell"), QStringLiteral("system"), QStringLiteral("macOS Shell"),
                   {QStringLiteral("com.apple.dock"), QStringLiteral("com.apple.systemuiserver"), QStringLiteral("com.apple.controlcenter"), QStringLiteral("com.apple.notificationcenterui"), QStringLiteral("com.apple.spotlight"), QStringLiteral("com.apple.loginwindow")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:qq-screenshot"), QStringLiteral("system"), QStringLiteral("QQ Screenshot"),
                   {QStringLiteral("qqscreenshot"), QStringLiteral("qqscreentshot"), QStringLiteral("qqscreenclip"), QStringLiteral("qqcapture")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:vscode"), QStringLiteral("dev"), QStringLiteral("VS Code"),
                   {QStringLiteral("com.microsoft.vscode"), QStringLiteral("visual studio code"), QStringLiteral("=code")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:codex"), QStringLiteral("dev"), QStringLiteral("Codex"),
                   {QStringLiteral("openai codex"), QStringLiteral("codex.exe"), QStringLiteral("=codex")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:jetbrains"), QStringLiteral("dev"), QStringLiteral("JetBrains IDE"),
                   {QStringLiteral("com.jetbrains"), QStringLiteral("idea64"), QStringLiteral("pycharm"), QStringLiteral("clion"), QStringLiteral("goland"), QStringLiteral("webstorm"), QStringLiteral("rider64"), QStringLiteral("datagrip"), QStringLiteral("rubymine"), QStringLiteral("phpstorm")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:visual-studio"), QStringLiteral("dev"), QStringLiteral("Visual Studio"),
                   {QStringLiteral("devenv")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:qt-creator"), QStringLiteral("dev"), QStringLiteral("Qt Creator"),
                   {QStringLiteral("qtcreator"), QStringLiteral("org.qt-project.qtcreator")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:android-studio"), QStringLiteral("dev"), QStringLiteral("Android Studio"),
                   {QStringLiteral("android studio")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:xcode"), QStringLiteral("dev"), QStringLiteral("Xcode"),
                   {QStringLiteral("com.apple.dt.xcode")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:sublime"), QStringLiteral("dev"), QStringLiteral("Sublime Text"),
                   {QStringLiteral("sublime_text"), QStringLiteral("com.sublimetext")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:notepadpp"), QStringLiteral("dev"), QStringLiteral("Notepad++"),
                   {QStringLiteral("notepad++")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:neovim"), QStringLiteral("dev"), QStringLiteral("Neovim"),
                   {QStringLiteral("neovim"), QStringLiteral("=nvim")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:terminal"), QStringLiteral("dev"), QStringLiteral("Terminal"),
                   {QStringLiteral("windowsterminal"), QStringLiteral("powershell"), QStringLiteral("cmd.exe"), QStringLiteral("conemu"), QStringLiteral("git-bash"), QStringLiteral("mingw"), QStringLiteral("com.apple.terminal"), QStringLiteral("com.googlecode.iterm2"), QStringLiteral("=iterm")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:docker"), QStringLiteral("dev"), QStringLiteral("Docker"),
                   {QStringLiteral("docker")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:dbeaver"), QStringLiteral("dev"), QStringLiteral("DBeaver"),
                   {QStringLiteral("dbeaver")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:postman"), QStringLiteral("dev"), QStringLiteral("Postman"),
                   {QStringLiteral("postman")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:chrome"), QStringLiteral("browse"), QStringLiteral("Google Chrome"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:edge"), QStringLiteral("browse"), QStringLiteral("Microsoft Edge"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:firefox"), QStringLiteral("browse"), QStringLiteral("Firefox"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:safari"), QStringLiteral("browse"), QStringLiteral("Safari"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:other-browsers"), QStringLiteral("browse"), QStringLiteral("Browser"),
                   {QStringLiteral("opera.exe"), QStringLiteral("com.operasoftware.opera"), QStringLiteral("brave"), QStringLiteral("vivaldi"), QStringLiteral("360se"), QStringLiteral("qqbrowser"), QStringLiteral("sogouexplorer"), QStringLiteral("ucbrowser"), QStringLiteral("company.thebrowser.browser")},
                   {}));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("app:wechat"), QStringLiteral("social"), QStringLiteral("WeChat"),
                   {QStringLiteral("com.tencent.xinwechat"), QStringLiteral("wechat"), QStringLiteral("weixin"), QStringLiteral("\u5FAE\u4FE1")},
                   {}),
      QStringLiteral("zh"), QStringLiteral("\u5FAE\u4FE1")));
  rules.append(detail::makeRule(QStringLiteral("app:qq"), QStringLiteral("social"), QStringLiteral("QQ"),
                   {QStringLiteral("=com.tencent.qq"), QStringLiteral("tencent qq"), QStringLiteral("=qq")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:tim"), QStringLiteral("social"), QStringLiteral("TIM"),
                   {QStringLiteral("=tim")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:discord"), QStringLiteral("social"), QStringLiteral("Discord"),
                   {QStringLiteral("discord")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:telegram"), QStringLiteral("social"), QStringLiteral("Telegram"),
                   {QStringLiteral("telegram")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:slack"), QStringLiteral("social"), QStringLiteral("Slack"),
                   {QStringLiteral("slack")},
                   {}));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("app:dingtalk"), QStringLiteral("social"), QStringLiteral("DingTalk"),
                   {QStringLiteral("dingtalk"), QStringLiteral("\u9489\u9489")},
                   {}),
      QStringLiteral("zh"), QStringLiteral("\u9489\u9489")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("app:feishu"), QStringLiteral("social"), QStringLiteral("Lark"),
                   {QStringLiteral("feishu"), QStringLiteral("=lark"), QStringLiteral("\u98DE\u4E66")},
                   {}),
      QStringLiteral("zh"), QStringLiteral("\u98DE\u4E66")));
  rules.append(detail::makeRule(QStringLiteral("app:teams"), QStringLiteral("social"), QStringLiteral("Microsoft Teams"),
                   {QStringLiteral("teams.exe"), QStringLiteral("microsoft teams")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:whatsapp"), QStringLiteral("social"), QStringLiteral("WhatsApp"),
                   {QStringLiteral("whatsapp")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:skype"), QStringLiteral("social"), QStringLiteral("Skype"),
                   {QStringLiteral("skype")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:zoom"), QStringLiteral("social"), QStringLiteral("Zoom"),
                   {QStringLiteral("zoom.exe"), QStringLiteral("us.zoom")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:spotify"), QStringLiteral("music"), QStringLiteral("Spotify"),
                   {QStringLiteral("com.spotify.client"), QStringLiteral("spotify")},
                   {}));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("app:netease-music"), QStringLiteral("music"), QStringLiteral("NetEase Cloud Music"),
                   {QStringLiteral("cloudmusic"), QStringLiteral("netease cloud music"), QStringLiteral("orpheus"), QStringLiteral("\u7F51\u6613\u4E91\u97F3\u4E50")},
                   {}),
      QStringLiteral("zh"), QStringLiteral("\u7F51\u6613\u4E91\u97F3\u4E50")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("app:qq-music"), QStringLiteral("music"), QStringLiteral("QQ Music"),
                   {QStringLiteral("qqmusic"), QStringLiteral("qq\u97F3\u4E50")},
                   {}),
      QStringLiteral("zh"), QStringLiteral("QQ\u97F3\u4E50")));
  rules.append(detail::makeRule(QStringLiteral("app:kugou"), QStringLiteral("music"), QStringLiteral("KuGou"),
                   {QStringLiteral("kugou")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:kuwo"), QStringLiteral("music"), QStringLiteral("Kuwo"),
                   {QStringLiteral("kuwo")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:foobar"), QStringLiteral("music"), QStringLiteral("foobar2000"),
                   {QStringLiteral("foobar")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:apple-music"), QStringLiteral("music"), QStringLiteral("Music"),
                   {QStringLiteral("com.apple.music")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:potplayer"), QStringLiteral("video"), QStringLiteral("PotPlayer"),
                   {QStringLiteral("potplayer")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:vlc"), QStringLiteral("video"), QStringLiteral("VLC"),
                   {QStringLiteral("vlc.exe"), QStringLiteral("org.videolan.vlc")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:mpv"), QStringLiteral("video"), QStringLiteral("mpv"),
                   {QStringLiteral("mpv.exe"), QStringLiteral("mpc-hc"), QStringLiteral("com.colliderli.iina")},
                   {}));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("app:bilibili"), QStringLiteral("video"), QStringLiteral("bilibili"),
                   {QStringLiteral("bilibili")},
                   {}),
      QStringLiteral("zh"), QStringLiteral("\u54D4\u54E9\u54D4\u54E9")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("app:tencent-video"), QStringLiteral("video"), QStringLiteral("Tencent Video"),
                   {QStringLiteral("tencentvideo"), QStringLiteral("qqlive")},
                   {}),
      QStringLiteral("zh"), QStringLiteral("\u817E\u8BAF\u89C6\u9891")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("app:iqiyi"), QStringLiteral("video"), QStringLiteral("iQIYI"),
                   {QStringLiteral("iqiyi")},
                   {}),
      QStringLiteral("zh"), QStringLiteral("\u7231\u5947\u827A")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("app:youku"), QStringLiteral("video"), QStringLiteral("Youku"),
                   {QStringLiteral("youku")},
                   {}),
      QStringLiteral("zh"), QStringLiteral("\u4F18\u9177")));
  rules.append(detail::makeRule(QStringLiteral("app:steam"), QStringLiteral("game"), QStringLiteral("Steam"),
                   {QStringLiteral("steam.exe"), QStringLiteral("steamwebhelper"), QStringLiteral("com.valvesoftware.steam")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:epic"), QStringLiteral("game"), QStringLiteral("Epic Games"),
                   {QStringLiteral("epicgames")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:riot"), QStringLiteral("game"), QStringLiteral("Riot Games"),
                   {QStringLiteral("riotclient"), QStringLiteral("leagueoflegends"), QStringLiteral("valorant")},
                   {}));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("app:genshin-impact"), QStringLiteral("game"), QStringLiteral("Genshin Impact"),
                   {QStringLiteral("yuanshen.exe"), QStringLiteral("genshinimpact.exe")},
                   {}),
      QStringLiteral("zh"), QStringLiteral("\u539F\u795E")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("app:honkai-star-rail"), QStringLiteral("game"), QStringLiteral("Honkai: Star Rail"),
                   {QStringLiteral("starrail.exe")},
                   {}),
      QStringLiteral("zh"), QStringLiteral("\u5D29\u574F\uFF1A\u661F\u7A79\u94C1\u9053")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("app:zenless-zone-zero"), QStringLiteral("game"), QStringLiteral("Zenless Zone Zero"),
                   {QStringLiteral("zenlesszonezero.exe")},
                   {}),
      QStringLiteral("zh"), QStringLiteral("\u7EDD\u533A\u96F6")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("app:wuthering-waves"), QStringLiteral("game"), QStringLiteral("Wuthering Waves"),
                   {QStringLiteral("wuthering waves"), QStringLiteral("wutheringwaves")},
                   {}),
      QStringLiteral("zh"), QStringLiteral("\u9E23\u6F6E")));
  rules.append(detail::makeRule(QStringLiteral("app:apex-legends"), QStringLiteral("game"), QStringLiteral("Apex Legends"),
                   {QStringLiteral("r5apex"), QStringLiteral("apex legends")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:wegame"), QStringLiteral("game"), QStringLiteral("WeGame"),
                   {QStringLiteral("wegame")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:battlenet"), QStringLiteral("game"), QStringLiteral("Battle.net"),
                   {QStringLiteral("battle.net")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:ubisoft"), QStringLiteral("game"), QStringLiteral("Ubisoft Connect"),
                   {QStringLiteral("ubisoft")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:gog"), QStringLiteral("game"), QStringLiteral("GOG Galaxy"),
                   {QStringLiteral("gog galaxy")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:street-fighter"), QStringLiteral("game"), QStringLiteral("Street Fighter"),
                   {QStringLiteral("streetfighter")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:uu-accelerator"), QStringLiteral("game"), QStringLiteral("UU Accelerator"),
                   {QStringLiteral("uu accelerator"), QStringLiteral("uu booster"), QStringLiteral("netease\\uu"), QStringLiteral("netease/uu"), QStringLiteral("=uu")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:word"), QStringLiteral("office"), QStringLiteral("Word"),
                   {QStringLiteral("winword"), QStringLiteral("com.microsoft.word")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:excel"), QStringLiteral("office"), QStringLiteral("Excel"),
                   {QStringLiteral("excel.exe"), QStringLiteral("com.microsoft.excel")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:powerpoint"), QStringLiteral("office"), QStringLiteral("PowerPoint"),
                   {QStringLiteral("powerpnt"), QStringLiteral("com.microsoft.powerpoint")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:outlook"), QStringLiteral("office"), QStringLiteral("Outlook"),
                   {QStringLiteral("outlook")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:wps"), QStringLiteral("office"), QStringLiteral("WPS Office"),
                   {QStringLiteral("wps"), QStringLiteral("=et"), QStringLiteral("wpp")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:acrobat"), QStringLiteral("office"), QStringLiteral("Acrobat"),
                   {QStringLiteral("acrobat"), QStringLiteral("acrord32")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:foxit"), QStringLiteral("office"), QStringLiteral("Foxit Reader"),
                   {QStringLiteral("foxit")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:sumatrapdf"), QStringLiteral("office"), QStringLiteral("SumatraPDF"),
                   {QStringLiteral("sumatrapdf")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:apple-mail"), QStringLiteral("office"), QStringLiteral("Mail"),
                   {QStringLiteral("com.apple.mail")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:photoshop"), QStringLiteral("create"), QStringLiteral("Photoshop"),
                   {QStringLiteral("photoshop")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:illustrator"), QStringLiteral("create"), QStringLiteral("Illustrator"),
                   {QStringLiteral("illustrator")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:premiere"), QStringLiteral("create"), QStringLiteral("Premiere Pro"),
                   {QStringLiteral("premiere")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:after-effects"), QStringLiteral("create"), QStringLiteral("After Effects"),
                   {QStringLiteral("afterfx")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:lightroom"), QStringLiteral("create"), QStringLiteral("Lightroom"),
                   {QStringLiteral("lightroom")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:figma"), QStringLiteral("create"), QStringLiteral("Figma"),
                   {QStringLiteral("figma")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:blender"), QStringLiteral("create"), QStringLiteral("Blender"),
                   {QStringLiteral("blender")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:obs"), QStringLiteral("create"), QStringLiteral("OBS Studio"),
                   {QStringLiteral("obs64"), QStringLiteral("=obs"), QStringLiteral("obs studio")},
                   {}));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("app:capcut"), QStringLiteral("create"), QStringLiteral("CapCut"),
                   {QStringLiteral("com.lemon.lvpro"), QStringLiteral("jianyingpro"), QStringLiteral("jianying"), QStringLiteral("capcut"), QStringLiteral("\u526A\u6620")},
                   {}),
      QStringLiteral("zh"), QStringLiteral("\u526A\u6620\u4E13\u4E1A\u7248")));
  rules.append(detail::makeRule(QStringLiteral("app:davinci"), QStringLiteral("create"), QStringLiteral("DaVinci Resolve"),
                   {QStringLiteral("davinci"), QStringLiteral("resolve.exe")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:audition"), QStringLiteral("create"), QStringLiteral("Audition"),
                   {QStringLiteral("audition")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:coreldraw"), QStringLiteral("create"), QStringLiteral("CorelDRAW"),
                   {QStringLiteral("coreldraw")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:3dsmax"), QStringLiteral("create"), QStringLiteral("3ds Max"),
                   {QStringLiteral("3dsmax")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:maya"), QStringLiteral("create"), QStringLiteral("Maya"),
                   {QStringLiteral("maya.exe")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:wallpaper-engine"), QStringLiteral("create"), QStringLiteral("Wallpaper Engine"),
                   {QStringLiteral("wallpaperengine"), QStringLiteral("wallpaper engine"), QStringLiteral("wallpaperui"), QStringLiteral("wallpaper32"), QStringLiteral("wallpaper64"), QStringLiteral("webwallpaper")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:notion"), QStringLiteral("notes"), QStringLiteral("Notion"),
                   {QStringLiteral("notion")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:obsidian"), QStringLiteral("notes"), QStringLiteral("Obsidian"),
                   {QStringLiteral("obsidian")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:typora"), QStringLiteral("notes"), QStringLiteral("Typora"),
                   {QStringLiteral("typora")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:evernote"), QStringLiteral("notes"), QStringLiteral("Evernote"),
                   {QStringLiteral("evernote")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:youdao"), QStringLiteral("notes"), QStringLiteral("Youdao Note"),
                   {QStringLiteral("youdao")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:joplin"), QStringLiteral("notes"), QStringLiteral("Joplin"),
                   {QStringLiteral("joplin")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:logseq"), QStringLiteral("notes"), QStringLiteral("Logseq"),
                   {QStringLiteral("logseq")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:onenote"), QStringLiteral("notes"), QStringLiteral("OneNote"),
                   {QStringLiteral("onenote")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:apple-notes"), QStringLiteral("notes"), QStringLiteral("Notes"),
                   {QStringLiteral("com.apple.notes")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:zotero"), QStringLiteral("read"), QStringLiteral("Zotero"),
                   {QStringLiteral("zotero")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:calibre"), QStringLiteral("read"), QStringLiteral("calibre"),
                   {QStringLiteral("calibre")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:kindle"), QStringLiteral("read"), QStringLiteral("Kindle"),
                   {QStringLiteral("kindle")},
                   {}));
  rules.append(detail::makeRule(QStringLiteral("app:timearc"), QStringLiteral("other"), QStringLiteral("TimeArc"),
                   {QStringLiteral("timearc"), QStringLiteral("time-arc")},
                   {}));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:bilibili.chrome"), QStringLiteral("video"), QStringLiteral("bilibili"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("bilibili"), QStringLiteral("b23.tv"), QStringLiteral("\u54D4\u54E9\u54D4\u54E9")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/bilibili.png")),
      QStringLiteral("zh"), QStringLiteral("\u54D4\u54E9\u54D4\u54E9")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:bilibili.edge"), QStringLiteral("video"), QStringLiteral("bilibili"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("bilibili"), QStringLiteral("b23.tv"), QStringLiteral("\u54D4\u54E9\u54D4\u54E9")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/bilibili.png")),
      QStringLiteral("zh"), QStringLiteral("\u54D4\u54E9\u54D4\u54E9")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:bilibili.firefox"), QStringLiteral("video"), QStringLiteral("bilibili"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("bilibili"), QStringLiteral("b23.tv"), QStringLiteral("\u54D4\u54E9\u54D4\u54E9")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/bilibili.png")),
      QStringLiteral("zh"), QStringLiteral("\u54D4\u54E9\u54D4\u54E9")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:bilibili.safari"), QStringLiteral("video"), QStringLiteral("bilibili"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("bilibili"), QStringLiteral("b23.tv"), QStringLiteral("\u54D4\u54E9\u54D4\u54E9")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/bilibili.png")),
      QStringLiteral("zh"), QStringLiteral("\u54D4\u54E9\u54D4\u54E9")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:douyin.chrome"), QStringLiteral("video"), QStringLiteral("Douyin"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("douyin"), QStringLiteral("\u6296\u97F3")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/douyin.ico")),
      QStringLiteral("zh"), QStringLiteral("\u6296\u97F3")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:douyin.edge"), QStringLiteral("video"), QStringLiteral("Douyin"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("douyin"), QStringLiteral("\u6296\u97F3")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/douyin.ico")),
      QStringLiteral("zh"), QStringLiteral("\u6296\u97F3")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:douyin.firefox"), QStringLiteral("video"), QStringLiteral("Douyin"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("douyin"), QStringLiteral("\u6296\u97F3")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/douyin.ico")),
      QStringLiteral("zh"), QStringLiteral("\u6296\u97F3")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:douyin.safari"), QStringLiteral("video"), QStringLiteral("Douyin"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("douyin"), QStringLiteral("\u6296\u97F3")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/douyin.ico")),
      QStringLiteral("zh"), QStringLiteral("\u6296\u97F3")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:xiaohongshu.chrome"), QStringLiteral("social"), QStringLiteral("Xiaohongshu"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("xiaohongshu"), QStringLiteral("\u5C0F\u7EA2\u4E66")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/xiaohongshu.png")),
      QStringLiteral("zh"), QStringLiteral("\u5C0F\u7EA2\u4E66")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:xiaohongshu.edge"), QStringLiteral("social"), QStringLiteral("Xiaohongshu"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("xiaohongshu"), QStringLiteral("\u5C0F\u7EA2\u4E66")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/xiaohongshu.png")),
      QStringLiteral("zh"), QStringLiteral("\u5C0F\u7EA2\u4E66")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:xiaohongshu.firefox"), QStringLiteral("social"), QStringLiteral("Xiaohongshu"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("xiaohongshu"), QStringLiteral("\u5C0F\u7EA2\u4E66")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/xiaohongshu.png")),
      QStringLiteral("zh"), QStringLiteral("\u5C0F\u7EA2\u4E66")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:xiaohongshu.safari"), QStringLiteral("social"), QStringLiteral("Xiaohongshu"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("xiaohongshu"), QStringLiteral("\u5C0F\u7EA2\u4E66")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/xiaohongshu.png")),
      QStringLiteral("zh"), QStringLiteral("\u5C0F\u7EA2\u4E66")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:weibo.chrome"), QStringLiteral("social"), QStringLiteral("Weibo"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("weibo"), QStringLiteral("\u5FAE\u535A")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/weibo.ico")),
      QStringLiteral("zh"), QStringLiteral("\u5FAE\u535A")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:weibo.edge"), QStringLiteral("social"), QStringLiteral("Weibo"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("weibo"), QStringLiteral("\u5FAE\u535A")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/weibo.ico")),
      QStringLiteral("zh"), QStringLiteral("\u5FAE\u535A")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:weibo.firefox"), QStringLiteral("social"), QStringLiteral("Weibo"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("weibo"), QStringLiteral("\u5FAE\u535A")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/weibo.ico")),
      QStringLiteral("zh"), QStringLiteral("\u5FAE\u535A")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:weibo.safari"), QStringLiteral("social"), QStringLiteral("Weibo"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("weibo"), QStringLiteral("\u5FAE\u535A")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/weibo.ico")),
      QStringLiteral("zh"), QStringLiteral("\u5FAE\u535A")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:zhihu.chrome"), QStringLiteral("read"), QStringLiteral("Zhihu"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("zhihu"), QStringLiteral("\u77E5\u4E4E")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/zhihu.png")),
      QStringLiteral("zh"), QStringLiteral("\u77E5\u4E4E")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:zhihu.edge"), QStringLiteral("read"), QStringLiteral("Zhihu"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("zhihu"), QStringLiteral("\u77E5\u4E4E")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/zhihu.png")),
      QStringLiteral("zh"), QStringLiteral("\u77E5\u4E4E")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:zhihu.firefox"), QStringLiteral("read"), QStringLiteral("Zhihu"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("zhihu"), QStringLiteral("\u77E5\u4E4E")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/zhihu.png")),
      QStringLiteral("zh"), QStringLiteral("\u77E5\u4E4E")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:zhihu.safari"), QStringLiteral("read"), QStringLiteral("Zhihu"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("zhihu"), QStringLiteral("\u77E5\u4E4E")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/zhihu.png")),
      QStringLiteral("zh"), QStringLiteral("\u77E5\u4E4E")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:taobao.chrome"), QStringLiteral("shop"), QStringLiteral("Taobao"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("taobao"), QStringLiteral("\u6DD8\u5B9D")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/taobao.png")),
      QStringLiteral("zh"), QStringLiteral("\u6DD8\u5B9D")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:taobao.edge"), QStringLiteral("shop"), QStringLiteral("Taobao"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("taobao"), QStringLiteral("\u6DD8\u5B9D")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/taobao.png")),
      QStringLiteral("zh"), QStringLiteral("\u6DD8\u5B9D")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:taobao.firefox"), QStringLiteral("shop"), QStringLiteral("Taobao"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("taobao"), QStringLiteral("\u6DD8\u5B9D")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/taobao.png")),
      QStringLiteral("zh"), QStringLiteral("\u6DD8\u5B9D")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:taobao.safari"), QStringLiteral("shop"), QStringLiteral("Taobao"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("taobao"), QStringLiteral("\u6DD8\u5B9D")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/taobao.png")),
      QStringLiteral("zh"), QStringLiteral("\u6DD8\u5B9D")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:tmall.chrome"), QStringLiteral("shop"), QStringLiteral("Tmall"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("tmall"), QStringLiteral("\u5929\u732B")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/tmall.png")),
      QStringLiteral("zh"), QStringLiteral("\u5929\u732B")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:tmall.edge"), QStringLiteral("shop"), QStringLiteral("Tmall"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("tmall"), QStringLiteral("\u5929\u732B")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/tmall.png")),
      QStringLiteral("zh"), QStringLiteral("\u5929\u732B")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:tmall.firefox"), QStringLiteral("shop"), QStringLiteral("Tmall"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("tmall"), QStringLiteral("\u5929\u732B")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/tmall.png")),
      QStringLiteral("zh"), QStringLiteral("\u5929\u732B")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:tmall.safari"), QStringLiteral("shop"), QStringLiteral("Tmall"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("tmall"), QStringLiteral("\u5929\u732B")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/tmall.png")),
      QStringLiteral("zh"), QStringLiteral("\u5929\u732B")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:jd.chrome"), QStringLiteral("shop"), QStringLiteral("JD"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("jd.com"), QStringLiteral("\u4EAC\u4E1C"), QStringLiteral("jingdong")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/jd.ico")),
      QStringLiteral("zh"), QStringLiteral("\u4EAC\u4E1C")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:jd.edge"), QStringLiteral("shop"), QStringLiteral("JD"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("jd.com"), QStringLiteral("\u4EAC\u4E1C"), QStringLiteral("jingdong")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/jd.ico")),
      QStringLiteral("zh"), QStringLiteral("\u4EAC\u4E1C")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:jd.firefox"), QStringLiteral("shop"), QStringLiteral("JD"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("jd.com"), QStringLiteral("\u4EAC\u4E1C"), QStringLiteral("jingdong")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/jd.ico")),
      QStringLiteral("zh"), QStringLiteral("\u4EAC\u4E1C")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:jd.safari"), QStringLiteral("shop"), QStringLiteral("JD"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("jd.com"), QStringLiteral("\u4EAC\u4E1C"), QStringLiteral("jingdong")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/jd.ico")),
      QStringLiteral("zh"), QStringLiteral("\u4EAC\u4E1C")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:pinduoduo.chrome"), QStringLiteral("shop"), QStringLiteral("Pinduoduo"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("pinduoduo"), QStringLiteral("\u62FC\u591A\u591A"), QStringLiteral("yangkeduo")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/pinduoduo.png")),
      QStringLiteral("zh"), QStringLiteral("\u62FC\u591A\u591A")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:pinduoduo.edge"), QStringLiteral("shop"), QStringLiteral("Pinduoduo"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("pinduoduo"), QStringLiteral("\u62FC\u591A\u591A"), QStringLiteral("yangkeduo")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/pinduoduo.png")),
      QStringLiteral("zh"), QStringLiteral("\u62FC\u591A\u591A")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:pinduoduo.firefox"), QStringLiteral("shop"), QStringLiteral("Pinduoduo"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("pinduoduo"), QStringLiteral("\u62FC\u591A\u591A"), QStringLiteral("yangkeduo")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/pinduoduo.png")),
      QStringLiteral("zh"), QStringLiteral("\u62FC\u591A\u591A")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:pinduoduo.safari"), QStringLiteral("shop"), QStringLiteral("Pinduoduo"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("pinduoduo"), QStringLiteral("\u62FC\u591A\u591A"), QStringLiteral("yangkeduo")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/pinduoduo.png")),
      QStringLiteral("zh"), QStringLiteral("\u62FC\u591A\u591A")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:baidu.chrome"), QStringLiteral("browse"), QStringLiteral("Baidu"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("baidu"), QStringLiteral("\u767E\u5EA6")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/baidu.png")),
      QStringLiteral("zh"), QStringLiteral("\u767E\u5EA6")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:baidu.edge"), QStringLiteral("browse"), QStringLiteral("Baidu"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("baidu"), QStringLiteral("\u767E\u5EA6")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/baidu.png")),
      QStringLiteral("zh"), QStringLiteral("\u767E\u5EA6")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:baidu.firefox"), QStringLiteral("browse"), QStringLiteral("Baidu"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("baidu"), QStringLiteral("\u767E\u5EA6")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/baidu.png")),
      QStringLiteral("zh"), QStringLiteral("\u767E\u5EA6")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:baidu.safari"), QStringLiteral("browse"), QStringLiteral("Baidu"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("baidu"), QStringLiteral("\u767E\u5EA6")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/baidu.png")),
      QStringLiteral("zh"), QStringLiteral("\u767E\u5EA6")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:iqiyi.chrome"), QStringLiteral("video"), QStringLiteral("iQIYI"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("iqiyi"), QStringLiteral("\u7231\u5947\u827A")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/iqiyi.png")),
      QStringLiteral("zh"), QStringLiteral("\u7231\u5947\u827A")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:iqiyi.edge"), QStringLiteral("video"), QStringLiteral("iQIYI"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("iqiyi"), QStringLiteral("\u7231\u5947\u827A")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/iqiyi.png")),
      QStringLiteral("zh"), QStringLiteral("\u7231\u5947\u827A")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:iqiyi.firefox"), QStringLiteral("video"), QStringLiteral("iQIYI"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("iqiyi"), QStringLiteral("\u7231\u5947\u827A")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/iqiyi.png")),
      QStringLiteral("zh"), QStringLiteral("\u7231\u5947\u827A")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:iqiyi.safari"), QStringLiteral("video"), QStringLiteral("iQIYI"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("iqiyi"), QStringLiteral("\u7231\u5947\u827A")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/iqiyi.png")),
      QStringLiteral("zh"), QStringLiteral("\u7231\u5947\u827A")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:youku.chrome"), QStringLiteral("video"), QStringLiteral("Youku"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("youku"), QStringLiteral("\u4F18\u9177")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/youku.png")),
      QStringLiteral("zh"), QStringLiteral("\u4F18\u9177")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:youku.edge"), QStringLiteral("video"), QStringLiteral("Youku"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("youku"), QStringLiteral("\u4F18\u9177")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/youku.png")),
      QStringLiteral("zh"), QStringLiteral("\u4F18\u9177")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:youku.firefox"), QStringLiteral("video"), QStringLiteral("Youku"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("youku"), QStringLiteral("\u4F18\u9177")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/youku.png")),
      QStringLiteral("zh"), QStringLiteral("\u4F18\u9177")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:youku.safari"), QStringLiteral("video"), QStringLiteral("Youku"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("youku"), QStringLiteral("\u4F18\u9177")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/youku.png")),
      QStringLiteral("zh"), QStringLiteral("\u4F18\u9177")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:tencent-video.chrome"), QStringLiteral("video"), QStringLiteral("Tencent Video"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("\u817E\u8BAF\u89C6\u9891"), QStringLiteral("v.qq.com"), QStringLiteral("qqlive")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/tencent-video.png")),
      QStringLiteral("zh"), QStringLiteral("\u817E\u8BAF\u89C6\u9891")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:tencent-video.edge"), QStringLiteral("video"), QStringLiteral("Tencent Video"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("\u817E\u8BAF\u89C6\u9891"), QStringLiteral("v.qq.com"), QStringLiteral("qqlive")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/tencent-video.png")),
      QStringLiteral("zh"), QStringLiteral("\u817E\u8BAF\u89C6\u9891")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:tencent-video.firefox"), QStringLiteral("video"), QStringLiteral("Tencent Video"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("\u817E\u8BAF\u89C6\u9891"), QStringLiteral("v.qq.com"), QStringLiteral("qqlive")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/tencent-video.png")),
      QStringLiteral("zh"), QStringLiteral("\u817E\u8BAF\u89C6\u9891")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:tencent-video.safari"), QStringLiteral("video"), QStringLiteral("Tencent Video"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("\u817E\u8BAF\u89C6\u9891"), QStringLiteral("v.qq.com"), QStringLiteral("qqlive")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/tencent-video.png")),
      QStringLiteral("zh"), QStringLiteral("\u817E\u8BAF\u89C6\u9891")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:mango-tv.chrome"), QStringLiteral("video"), QStringLiteral("Mango TV"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("mgtv"), QStringLiteral("\u8292\u679Ctv")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/mango-tv.png")),
      QStringLiteral("zh"), QStringLiteral("\u8292\u679CTV")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:mango-tv.edge"), QStringLiteral("video"), QStringLiteral("Mango TV"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("mgtv"), QStringLiteral("\u8292\u679Ctv")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/mango-tv.png")),
      QStringLiteral("zh"), QStringLiteral("\u8292\u679CTV")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:mango-tv.firefox"), QStringLiteral("video"), QStringLiteral("Mango TV"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("mgtv"), QStringLiteral("\u8292\u679Ctv")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/mango-tv.png")),
      QStringLiteral("zh"), QStringLiteral("\u8292\u679CTV")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:mango-tv.safari"), QStringLiteral("video"), QStringLiteral("Mango TV"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("mgtv"), QStringLiteral("\u8292\u679Ctv")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/mango-tv.png")),
      QStringLiteral("zh"), QStringLiteral("\u8292\u679CTV")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:kuaishou.chrome"), QStringLiteral("video"), QStringLiteral("Kuaishou"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("kuaishou"), QStringLiteral("\u5FEB\u624B")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/kuaishou.ico")),
      QStringLiteral("zh"), QStringLiteral("\u5FEB\u624B")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:kuaishou.edge"), QStringLiteral("video"), QStringLiteral("Kuaishou"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("kuaishou"), QStringLiteral("\u5FEB\u624B")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/kuaishou.ico")),
      QStringLiteral("zh"), QStringLiteral("\u5FEB\u624B")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:kuaishou.firefox"), QStringLiteral("video"), QStringLiteral("Kuaishou"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("kuaishou"), QStringLiteral("\u5FEB\u624B")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/kuaishou.ico")),
      QStringLiteral("zh"), QStringLiteral("\u5FEB\u624B")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:kuaishou.safari"), QStringLiteral("video"), QStringLiteral("Kuaishou"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("kuaishou"), QStringLiteral("\u5FEB\u624B")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/kuaishou.ico")),
      QStringLiteral("zh"), QStringLiteral("\u5FEB\u624B")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:xigua.chrome"), QStringLiteral("video"), QStringLiteral("Xigua Video"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("ixigua"), QStringLiteral("\u897F\u74DC\u89C6\u9891")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/xigua-video.ico")),
      QStringLiteral("zh"), QStringLiteral("\u897F\u74DC\u89C6\u9891")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:xigua.edge"), QStringLiteral("video"), QStringLiteral("Xigua Video"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("ixigua"), QStringLiteral("\u897F\u74DC\u89C6\u9891")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/xigua-video.ico")),
      QStringLiteral("zh"), QStringLiteral("\u897F\u74DC\u89C6\u9891")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:xigua.firefox"), QStringLiteral("video"), QStringLiteral("Xigua Video"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("ixigua"), QStringLiteral("\u897F\u74DC\u89C6\u9891")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/xigua-video.ico")),
      QStringLiteral("zh"), QStringLiteral("\u897F\u74DC\u89C6\u9891")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:xigua.safari"), QStringLiteral("video"), QStringLiteral("Xigua Video"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("ixigua"), QStringLiteral("\u897F\u74DC\u89C6\u9891")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/xigua-video.ico")),
      QStringLiteral("zh"), QStringLiteral("\u897F\u74DC\u89C6\u9891")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:acfun.chrome"), QStringLiteral("video"), QStringLiteral("AcFun"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("acfun"), QStringLiteral("acfun.cn")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/acfun.png")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:acfun.edge"), QStringLiteral("video"), QStringLiteral("AcFun"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("acfun"), QStringLiteral("acfun.cn")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/acfun.png")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:acfun.firefox"), QStringLiteral("video"), QStringLiteral("AcFun"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("acfun"), QStringLiteral("acfun.cn")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/acfun.png")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:acfun.safari"), QStringLiteral("video"), QStringLiteral("AcFun"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("acfun"), QStringLiteral("acfun.cn")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/acfun.png")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:youtube.chrome"), QStringLiteral("video"), QStringLiteral("YouTube"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("youtube"), QStringLiteral("youtu.be")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/youtube.png")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:youtube.edge"), QStringLiteral("video"), QStringLiteral("YouTube"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("youtube"), QStringLiteral("youtu.be")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/youtube.png")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:youtube.firefox"), QStringLiteral("video"), QStringLiteral("YouTube"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("youtube"), QStringLiteral("youtu.be")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/youtube.png")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:youtube.safari"), QStringLiteral("video"), QStringLiteral("YouTube"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("youtube"), QStringLiteral("youtu.be")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/youtube.png")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:netflix.chrome"), QStringLiteral("video"), QStringLiteral("Netflix"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("netflix")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/netflix.png")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:netflix.edge"), QStringLiteral("video"), QStringLiteral("Netflix"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("netflix")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/netflix.png")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:netflix.firefox"), QStringLiteral("video"), QStringLiteral("Netflix"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("netflix")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/netflix.png")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:netflix.safari"), QStringLiteral("video"), QStringLiteral("Netflix"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("netflix")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/netflix.png")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:twitch.chrome"), QStringLiteral("video"), QStringLiteral("Twitch"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("twitch")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/twitch.ico")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:twitch.edge"), QStringLiteral("video"), QStringLiteral("Twitch"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("twitch")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/twitch.ico")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:twitch.firefox"), QStringLiteral("video"), QStringLiteral("Twitch"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("twitch")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/twitch.ico")));
  rules.append(detail::withIcon(
      detail::makeRule(QStringLiteral("site:twitch.safari"), QStringLiteral("video"), QStringLiteral("Twitch"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("twitch")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/twitch.ico")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:douyu.chrome"), QStringLiteral("video"), QStringLiteral("Douyu"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("douyu"), QStringLiteral("\u6597\u9C7C")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/douyu.ico")),
      QStringLiteral("zh"), QStringLiteral("\u6597\u9C7C")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:douyu.edge"), QStringLiteral("video"), QStringLiteral("Douyu"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("douyu"), QStringLiteral("\u6597\u9C7C")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/douyu.ico")),
      QStringLiteral("zh"), QStringLiteral("\u6597\u9C7C")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:douyu.firefox"), QStringLiteral("video"), QStringLiteral("Douyu"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("douyu"), QStringLiteral("\u6597\u9C7C")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/douyu.ico")),
      QStringLiteral("zh"), QStringLiteral("\u6597\u9C7C")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:douyu.safari"), QStringLiteral("video"), QStringLiteral("Douyu"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("douyu"), QStringLiteral("\u6597\u9C7C")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/douyu.ico")),
      QStringLiteral("zh"), QStringLiteral("\u6597\u9C7C")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:huya.chrome"), QStringLiteral("video"), QStringLiteral("Huya"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("huya"), QStringLiteral("\u864E\u7259")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/huya.png")),
      QStringLiteral("zh"), QStringLiteral("\u864E\u7259")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:huya.edge"), QStringLiteral("video"), QStringLiteral("Huya"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("huya"), QStringLiteral("\u864E\u7259")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/huya.png")),
      QStringLiteral("zh"), QStringLiteral("\u864E\u7259")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:huya.firefox"), QStringLiteral("video"), QStringLiteral("Huya"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("huya"), QStringLiteral("\u864E\u7259")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/huya.png")),
      QStringLiteral("zh"), QStringLiteral("\u864E\u7259")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:huya.safari"), QStringLiteral("video"), QStringLiteral("Huya"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("huya"), QStringLiteral("\u864E\u7259")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/huya.png")),
      QStringLiteral("zh"), QStringLiteral("\u864E\u7259")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:douban.chrome"), QStringLiteral("read"), QStringLiteral("Douban"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("douban"), QStringLiteral("\u8C46\u74E3")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/douban.ico")),
      QStringLiteral("zh"), QStringLiteral("\u8C46\u74E3")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:douban.edge"), QStringLiteral("read"), QStringLiteral("Douban"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("douban"), QStringLiteral("\u8C46\u74E3")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/douban.ico")),
      QStringLiteral("zh"), QStringLiteral("\u8C46\u74E3")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:douban.firefox"), QStringLiteral("read"), QStringLiteral("Douban"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("douban"), QStringLiteral("\u8C46\u74E3")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/douban.ico")),
      QStringLiteral("zh"), QStringLiteral("\u8C46\u74E3")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:douban.safari"), QStringLiteral("read"), QStringLiteral("Douban"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("douban"), QStringLiteral("\u8C46\u74E3")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/douban.ico")),
      QStringLiteral("zh"), QStringLiteral("\u8C46\u74E3")));
  rules.append(detail::makeRule(QStringLiteral("site:csdn.chrome"), QStringLiteral("dev"), QStringLiteral("CSDN"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("csdn")}));
  rules.append(detail::makeRule(QStringLiteral("site:csdn.edge"), QStringLiteral("dev"), QStringLiteral("CSDN"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("csdn")}));
  rules.append(detail::makeRule(QStringLiteral("site:csdn.firefox"), QStringLiteral("dev"), QStringLiteral("CSDN"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("csdn")}));
  rules.append(detail::makeRule(QStringLiteral("site:csdn.safari"), QStringLiteral("dev"), QStringLiteral("CSDN"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("csdn")}));
  rules.append(detail::makeRule(QStringLiteral("site:github.chrome"), QStringLiteral("dev"), QStringLiteral("GitHub"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("github")}));
  rules.append(detail::makeRule(QStringLiteral("site:github.edge"), QStringLiteral("dev"), QStringLiteral("GitHub"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("github")}));
  rules.append(detail::makeRule(QStringLiteral("site:github.firefox"), QStringLiteral("dev"), QStringLiteral("GitHub"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("github")}));
  rules.append(detail::makeRule(QStringLiteral("site:github.safari"), QStringLiteral("dev"), QStringLiteral("GitHub"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("github")}));
  rules.append(detail::makeRule(QStringLiteral("site:stackoverflow.chrome"), QStringLiteral("dev"), QStringLiteral("Stack Overflow"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("stack overflow"), QStringLiteral("stackoverflow")}));
  rules.append(detail::makeRule(QStringLiteral("site:stackoverflow.edge"), QStringLiteral("dev"), QStringLiteral("Stack Overflow"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("stack overflow"), QStringLiteral("stackoverflow")}));
  rules.append(detail::makeRule(QStringLiteral("site:stackoverflow.firefox"), QStringLiteral("dev"), QStringLiteral("Stack Overflow"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("stack overflow"), QStringLiteral("stackoverflow")}));
  rules.append(detail::makeRule(QStringLiteral("site:stackoverflow.safari"), QStringLiteral("dev"), QStringLiteral("Stack Overflow"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("stack overflow"), QStringLiteral("stackoverflow")}));
  rules.append(detail::makeRule(QStringLiteral("site:arxiv.chrome"), QStringLiteral("read"), QStringLiteral("arXiv"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("arxiv")}));
  rules.append(detail::makeRule(QStringLiteral("site:arxiv.edge"), QStringLiteral("read"), QStringLiteral("arXiv"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("arxiv")}));
  rules.append(detail::makeRule(QStringLiteral("site:arxiv.firefox"), QStringLiteral("read"), QStringLiteral("arXiv"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("arxiv")}));
  rules.append(detail::makeRule(QStringLiteral("site:arxiv.safari"), QStringLiteral("read"), QStringLiteral("arXiv"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("arxiv")}));
  rules.append(detail::makeRule(QStringLiteral("site:wikipedia.chrome"), QStringLiteral("read"), QStringLiteral("Wikipedia"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("wikipedia"), QStringLiteral("\u7EF4\u57FA\u767E\u79D1")}));
  rules.append(detail::makeRule(QStringLiteral("site:wikipedia.edge"), QStringLiteral("read"), QStringLiteral("Wikipedia"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("wikipedia"), QStringLiteral("\u7EF4\u57FA\u767E\u79D1")}));
  rules.append(detail::makeRule(QStringLiteral("site:wikipedia.firefox"), QStringLiteral("read"), QStringLiteral("Wikipedia"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("wikipedia"), QStringLiteral("\u7EF4\u57FA\u767E\u79D1")}));
  rules.append(detail::makeRule(QStringLiteral("site:wikipedia.safari"), QStringLiteral("read"), QStringLiteral("Wikipedia"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("wikipedia"), QStringLiteral("\u7EF4\u57FA\u767E\u79D1")}));
  rules.append(detail::makeRule(QStringLiteral("site:spotify-web.chrome"), QStringLiteral("music"), QStringLiteral("Spotify Web"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("spotify")}));
  rules.append(detail::makeRule(QStringLiteral("site:spotify-web.edge"), QStringLiteral("music"), QStringLiteral("Spotify Web"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("spotify")}));
  rules.append(detail::makeRule(QStringLiteral("site:spotify-web.firefox"), QStringLiteral("music"), QStringLiteral("Spotify Web"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("spotify")}));
  rules.append(detail::makeRule(QStringLiteral("site:spotify-web.safari"), QStringLiteral("music"), QStringLiteral("Spotify Web"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("spotify")}));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("site:qq-music-web.chrome"), QStringLiteral("music"), QStringLiteral("QQ Music"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("qq\u97F3\u4E50"), QStringLiteral("y.qq.com")}),
      QStringLiteral("zh"), QStringLiteral("QQ\u97F3\u4E50")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("site:qq-music-web.edge"), QStringLiteral("music"), QStringLiteral("QQ Music"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("qq\u97F3\u4E50"), QStringLiteral("y.qq.com")}),
      QStringLiteral("zh"), QStringLiteral("QQ\u97F3\u4E50")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("site:qq-music-web.firefox"), QStringLiteral("music"), QStringLiteral("QQ Music"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("qq\u97F3\u4E50"), QStringLiteral("y.qq.com")}),
      QStringLiteral("zh"), QStringLiteral("QQ\u97F3\u4E50")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("site:qq-music-web.safari"), QStringLiteral("music"), QStringLiteral("QQ Music"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("qq\u97F3\u4E50"), QStringLiteral("y.qq.com")}),
      QStringLiteral("zh"), QStringLiteral("QQ\u97F3\u4E50")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("site:netease-music-web.chrome"), QStringLiteral("music"), QStringLiteral("NetEase Cloud Music"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("music.163"), QStringLiteral("\u7F51\u6613\u4E91\u97F3\u4E50")}),
      QStringLiteral("zh"), QStringLiteral("\u7F51\u6613\u4E91\u97F3\u4E50")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("site:netease-music-web.edge"), QStringLiteral("music"), QStringLiteral("NetEase Cloud Music"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("music.163"), QStringLiteral("\u7F51\u6613\u4E91\u97F3\u4E50")}),
      QStringLiteral("zh"), QStringLiteral("\u7F51\u6613\u4E91\u97F3\u4E50")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("site:netease-music-web.firefox"), QStringLiteral("music"), QStringLiteral("NetEase Cloud Music"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("music.163"), QStringLiteral("\u7F51\u6613\u4E91\u97F3\u4E50")}),
      QStringLiteral("zh"), QStringLiteral("\u7F51\u6613\u4E91\u97F3\u4E50")));
  rules.append(detail::withLabel(
      detail::makeRule(QStringLiteral("site:netease-music-web.safari"), QStringLiteral("music"), QStringLiteral("NetEase Cloud Music"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("music.163"), QStringLiteral("\u7F51\u6613\u4E91\u97F3\u4E50")}),
      QStringLiteral("zh"), QStringLiteral("\u7F51\u6613\u4E91\u97F3\u4E50")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:alipay.chrome"), QStringLiteral("other"), QStringLiteral("Alipay"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("alipay"), QStringLiteral("\u652F\u4ED8\u5B9D")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/alipay.png")),
      QStringLiteral("zh"), QStringLiteral("\u652F\u4ED8\u5B9D")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:alipay.edge"), QStringLiteral("other"), QStringLiteral("Alipay"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("alipay"), QStringLiteral("\u652F\u4ED8\u5B9D")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/alipay.png")),
      QStringLiteral("zh"), QStringLiteral("\u652F\u4ED8\u5B9D")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:alipay.firefox"), QStringLiteral("other"), QStringLiteral("Alipay"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("alipay"), QStringLiteral("\u652F\u4ED8\u5B9D")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/alipay.png")),
      QStringLiteral("zh"), QStringLiteral("\u652F\u4ED8\u5B9D")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:alipay.safari"), QStringLiteral("other"), QStringLiteral("Alipay"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("alipay"), QStringLiteral("\u652F\u4ED8\u5B9D")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/alipay.png")),
      QStringLiteral("zh"), QStringLiteral("\u652F\u4ED8\u5B9D")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:meituan.chrome"), QStringLiteral("other"), QStringLiteral("Meituan"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("meituan"), QStringLiteral("\u7F8E\u56E2")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/meituan.ico")),
      QStringLiteral("zh"), QStringLiteral("\u7F8E\u56E2")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:meituan.edge"), QStringLiteral("other"), QStringLiteral("Meituan"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("meituan"), QStringLiteral("\u7F8E\u56E2")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/meituan.ico")),
      QStringLiteral("zh"), QStringLiteral("\u7F8E\u56E2")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:meituan.firefox"), QStringLiteral("other"), QStringLiteral("Meituan"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("meituan"), QStringLiteral("\u7F8E\u56E2")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/meituan.ico")),
      QStringLiteral("zh"), QStringLiteral("\u7F8E\u56E2")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:meituan.safari"), QStringLiteral("other"), QStringLiteral("Meituan"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("meituan"), QStringLiteral("\u7F8E\u56E2")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/meituan.ico")),
      QStringLiteral("zh"), QStringLiteral("\u7F8E\u56E2")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:dianping.chrome"), QStringLiteral("other"), QStringLiteral("Dianping"),
                   {QStringLiteral("com.google.chrome"), QStringLiteral("google chrome"), QStringLiteral("chrome.exe")},
                   {QStringLiteral("dianping"), QStringLiteral("\u5927\u4F17\u70B9\u8BC4")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/dianping.ico")),
      QStringLiteral("zh"), QStringLiteral("\u5927\u4F17\u70B9\u8BC4")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:dianping.edge"), QStringLiteral("other"), QStringLiteral("Dianping"),
                   {QStringLiteral("com.microsoft.edgemac"), QStringLiteral("microsoftedge"), QStringLiteral("microsoft edge"), QStringLiteral("msedge"), QStringLiteral("edge.exe")},
                   {QStringLiteral("dianping"), QStringLiteral("\u5927\u4F17\u70B9\u8BC4")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/dianping.ico")),
      QStringLiteral("zh"), QStringLiteral("\u5927\u4F17\u70B9\u8BC4")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:dianping.firefox"), QStringLiteral("other"), QStringLiteral("Dianping"),
                   {QStringLiteral("org.mozilla.firefox"), QStringLiteral("firefox")},
                   {QStringLiteral("dianping"), QStringLiteral("\u5927\u4F17\u70B9\u8BC4")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/dianping.ico")),
      QStringLiteral("zh"), QStringLiteral("\u5927\u4F17\u70B9\u8BC4")));
  rules.append(detail::withLabel(
      detail::withIcon(
      detail::makeRule(QStringLiteral("site:dianping.safari"), QStringLiteral("other"), QStringLiteral("Dianping"),
                   {QStringLiteral("com.apple.safari"), QStringLiteral("=safari")},
                   {QStringLiteral("dianping"), QStringLiteral("\u5927\u4F17\u70B9\u8BC4")}),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/dianping.ico")),
      QStringLiteral("zh"), QStringLiteral("\u5927\u4F17\u70B9\u8BC4")));
  return rules;
}

inline RuleSet defaultRuleSet() {
  RuleSet set;
  set.schema = 1;
  set.fromDefaults = kDefaultTableVersion;
  set.categories = defaultCategories();
  set.rules = defaultRules();
  return set;
}

}  // namespace TimeArc::Categorization

#endif  // TIMEARC_SERVICES_CATEGORIZATION_DEFAULT_RULES_H
