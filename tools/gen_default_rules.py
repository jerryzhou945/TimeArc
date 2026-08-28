# -*- coding: utf-8 -*-
"""Emit src/services/categorization/default_rules.h with \\uXXXX escapes.

Run from the repository root:  python3 tools/gen_default_rules.py
Edit the readable tables below, never the generated header.
"""

def esc(s):
    out = []
    for ch in s:
        if ord(ch) < 128:
            if ch == '"':  out.append('\\"')
            elif ch == '\\': out.append('\\\\')
            else: out.append(ch)
        else:
            out.append('\\u%04X' % ord(ch))
    return ''.join(out)

def q(s):
    return 'QStringLiteral("%s")' % esc(s)

def sl(items):
    if not items: return '{}'
    return '{' + ', '.join(q(i) for i in items) + '}'

# ---------------------------------------------------------------- categories
# (id, en, zh, ja, traits)
CATEGORIES = [
    ("dev",    "Development", "开发", "開発",       ["focus"]),
    ("office", "Office",      "办公", "オフィス",   ["focus"]),
    ("notes",  "Notes",       "笔记", "ノート",     ["focus"]),
    ("create", "Creation",    "创作", "制作",       []),
    ("social", "Social",      "社交", "ソーシャル", []),
    ("video",  "Video",       "视频", "動画",       ["entertainment"]),
    ("music",  "Music",       "音乐", "音楽",       []),
    ("game",   "Games",       "游戏", "ゲーム",     ["entertainment"]),
    ("browse", "Browsing",    "浏览", "ブラウズ",   []),
    ("read",   "Reading",     "阅读", "読書",       []),
    ("shop",   "Shopping",    "购物", "ショッピング", []),
    ("system", "System",      "系统", "システム",   ["deprioritize"]),
    ("other",  "Other",       "其他", "その他",     []),
]

# ---------------------------------------------------------------- browsers
# Every rule binds to a concrete app. Site rules are therefore generated once
# per browser instead of hiding behind an abstract "all browsers" scope: the
# binding a user sees in the editor is always an app they actually have.
BROWSER_TARGETS = [
    ("chrome",  ["com.google.chrome", "google chrome", "chrome.exe"]),
    ("edge",    ["com.microsoft.edgemac", "microsoftedge", "microsoft edge",
                 "msedge", "edge.exe"]),
    ("firefox", ["org.mozilla.firefox", "firefox"]),
    ("safari",  ["com.apple.safari", "=safari"]),
]

# -------------------------------------------------------------------- rules
# Rule ids keep the legacy colon format (app:vscode, site:youtube) because
# hidden_apps and app_display_names are keyed by group key; changing the
# separator would silently orphan every existing user preference.
# NOTE: needles are normalized exactly like observed text, so a needle spelled
# "qq.exe" becomes "qq" - a two-character substring that would also match
# QQMusic and QQBrowser. Use "=" for short names. lint() enforces this.
# (id, category, en, [app needles], [title needles], scope, {extra labels})
A = []   # app rules
def app(rid, cat, en, needles, extra=None):
    A.append((rid, cat, en, needles, [], "", extra or {}))
SITE_ICONS = {'site:acfun': 'acfun.png', 'site:alipay': 'alipay.png', 'site:baidu': 'baidu.png', 'site:bilibili': 'bilibili.png', 'site:dianping': 'dianping.ico', 'site:douban': 'douban.ico', 'site:douyin': 'douyin.ico', 'site:douyu': 'douyu.ico', 'site:huya': 'huya.png', 'site:iqiyi': 'iqiyi.png', 'site:jd': 'jd.ico', 'site:kuaishou': 'kuaishou.ico', 'site:mango-tv': 'mango-tv.png', 'site:meituan': 'meituan.ico', 'site:netflix': 'netflix.png', 'site:pinduoduo': 'pinduoduo.png', 'site:taobao': 'taobao.png', 'site:tencent-video': 'tencent-video.png', 'site:tmall': 'tmall.png', 'site:twitch': 'twitch.ico', 'site:weibo': 'weibo.ico', 'site:xiaohongshu': 'xiaohongshu.png', 'site:xigua': 'xigua-video.ico', 'site:youku': 'youku.png', 'site:youtube': 'youtube.png', 'site:zhihu': 'zhihu.png'}

def site(rid, cat, en, titles, extra=None):
    """One rule per (site, browser); each is bound to that one browser."""
    for suffix, needles in BROWSER_TARGETS:
        A.append(("%s.%s" % (rid, suffix), cat, en, list(needles), titles, "",
                  extra or {}))

# --- system / shell -------------------------------------------------------
app("app:windows-system", "system", "Windows Shell",
    ["startmenuexperiencehost", "searchhost", "searchapp", "shellexperiencehost",
     "lockapp", "applicationframehost", "textinputhost", "dwm.exe", "sihost",
     "ctfmon", "systemsettings", "useroobe", "rundll32", "taskmgr", "winlogon",
     "fontdrvhost", "wininit", "csrss", "smartscreen", "runtimebroker",
     "taskhostw", "dllhost", "conhost", "wmiprvse", "audiodg", "widgets.exe",
     "backgroundtaskhost", "securityhealthsystray", "crashpad_handler",
     "werfault", "pickerhost", "permissioncenterui"])
app("app:windows-service-host", "system", "Service Host", ["svchost"])
app("app:nvidia-container", "system", "NVIDIA Container", ["nvcontainer"])
app("app:file-explorer", "system", "File Explorer",
    ["explorer.exe", "windows\\explorer"])
app("app:finder", "system", "Finder", ["com.apple.finder"])
app("app:macos-shell", "system", "macOS Shell",
    ["com.apple.dock", "com.apple.systemuiserver", "com.apple.controlcenter",
     "com.apple.notificationcenterui", "com.apple.spotlight",
     "com.apple.loginwindow"])
app("app:qq-screenshot", "system", "QQ Screenshot",
    ["qqscreenshot", "qqscreentshot", "qqscreenclip", "qqcapture"])

# --- development ----------------------------------------------------------
app("app:vscode", "dev", "VS Code",
    ["com.microsoft.vscode", "visual studio code", "=code"])
app("app:codex", "dev", "Codex", ["openai codex", "codex.exe", "=codex"])
app("app:jetbrains", "dev", "JetBrains IDE",
    ["com.jetbrains", "idea64", "pycharm", "clion", "goland", "webstorm",
     "rider64", "datagrip", "rubymine", "phpstorm"])
app("app:visual-studio", "dev", "Visual Studio", ["devenv"])
app("app:qt-creator", "dev", "Qt Creator", ["qtcreator", "org.qt-project.qtcreator"])
app("app:android-studio", "dev", "Android Studio", ["android studio"])
app("app:xcode", "dev", "Xcode", ["com.apple.dt.xcode"])
app("app:sublime", "dev", "Sublime Text", ["sublime_text", "com.sublimetext"])
app("app:notepadpp", "dev", "Notepad++", ["notepad++"])
app("app:neovim", "dev", "Neovim", ["neovim", "=nvim"])
app("app:terminal", "dev", "Terminal",
    ["windowsterminal", "powershell", "cmd.exe", "conemu", "git-bash", "mingw",
     "com.apple.terminal", "com.googlecode.iterm2", "=iterm"])
app("app:docker", "dev", "Docker", ["docker"])
app("app:dbeaver", "dev", "DBeaver", ["dbeaver"])
app("app:postman", "dev", "Postman", ["postman"])

# --- browsers -------------------------------------------------------------
app("app:chrome", "browse", "Google Chrome",
    ["com.google.chrome", "google chrome", "chrome.exe"])
app("app:edge", "browse", "Microsoft Edge",
    ["com.microsoft.edgemac", "microsoftedge", "microsoft edge", "msedge", "edge.exe"])
app("app:firefox", "browse", "Firefox", ["org.mozilla.firefox", "firefox"])
app("app:safari", "browse", "Safari", ["com.apple.safari", "=safari"])
app("app:other-browsers", "browse", "Browser",
    ["opera.exe", "com.operasoftware.opera", "brave", "vivaldi", "360se",
     "qqbrowser", "sogouexplorer", "ucbrowser", "company.thebrowser.browser"])

# --- social ---------------------------------------------------------------
app("app:wechat", "social", "WeChat",
    ["com.tencent.xinwechat", "wechat", "weixin", "微信"], {"zh": "微信"})
app("app:qq", "social", "QQ", ["=com.tencent.qq", "tencent qq", "=qq"])
app("app:tim", "social", "TIM", ["=tim"])
app("app:discord", "social", "Discord", ["discord"])
app("app:telegram", "social", "Telegram", ["telegram"])
app("app:slack", "social", "Slack", ["slack"])
app("app:dingtalk", "social", "DingTalk", ["dingtalk", "钉钉"], {"zh": "钉钉"})
app("app:feishu", "social", "Lark", ["feishu", "=lark", "飞书"], {"zh": "飞书"})
app("app:teams", "social", "Microsoft Teams", ["teams.exe", "microsoft teams"])
app("app:whatsapp", "social", "WhatsApp", ["whatsapp"])
app("app:skype", "social", "Skype", ["skype"])
app("app:zoom", "social", "Zoom", ["zoom.exe", "us.zoom"])

# --- music ----------------------------------------------------------------
app("app:spotify", "music", "Spotify", ["com.spotify.client", "spotify"])
app("app:netease-music", "music", "NetEase Cloud Music",
    ["cloudmusic", "netease cloud music", "orpheus", "网易云音乐"],
    {"zh": "网易云音乐"})
app("app:qq-music", "music", "QQ Music", ["qqmusic", "qq音乐"], {"zh": "QQ音乐"})
app("app:kugou", "music", "KuGou", ["kugou"])
app("app:kuwo", "music", "Kuwo", ["kuwo"])
app("app:foobar", "music", "foobar2000", ["foobar"])
app("app:apple-music", "music", "Music", ["com.apple.music"])

# --- video ----------------------------------------------------------------
app("app:potplayer", "video", "PotPlayer", ["potplayer"])
app("app:vlc", "video", "VLC", ["vlc.exe", "org.videolan.vlc"])
app("app:mpv", "video", "mpv", ["mpv.exe", "mpc-hc", "com.colliderli.iina"])
app("app:bilibili", "video", "bilibili", ["bilibili"], {"zh": "哔哩哔哩"})
app("app:tencent-video", "video", "Tencent Video", ["tencentvideo", "qqlive"],
    {"zh": "腾讯视频"})
app("app:iqiyi", "video", "iQIYI", ["iqiyi"], {"zh": "爱奇艺"})
app("app:youku", "video", "Youku", ["youku"], {"zh": "优酷"})

# --- games ----------------------------------------------------------------
app("app:steam", "game", "Steam", ["steam.exe", "steamwebhelper", "com.valvesoftware.steam"])
app("app:epic", "game", "Epic Games", ["epicgames"])
app("app:riot", "game", "Riot Games", ["riotclient", "leagueoflegends", "valorant"])
app("app:genshin-impact", "game", "Genshin Impact",
    ["yuanshen.exe", "genshinimpact.exe"], {"zh": "原神"})
app("app:honkai-star-rail", "game", "Honkai: Star Rail", ["starrail.exe"],
    {"zh": "崩坏：星穹铁道"})
app("app:zenless-zone-zero", "game", "Zenless Zone Zero", ["zenlesszonezero.exe"],
    {"zh": "绝区零"})
# Client-Win64-Shipping.exe is shared by many Unreal titles; the install path
# is the disambiguator, and on Windows app_id IS the full path.
app("app:wuthering-waves", "game", "Wuthering Waves",
    ["wuthering waves", "wutheringwaves"], {"zh": "鸣潮"})
app("app:apex-legends", "game", "Apex Legends", ["r5apex", "apex legends"])
app("app:wegame", "game", "WeGame", ["wegame"])
app("app:battlenet", "game", "Battle.net", ["battle.net"])
app("app:ubisoft", "game", "Ubisoft Connect", ["ubisoft"])
app("app:gog", "game", "GOG Galaxy", ["gog galaxy"])
app("app:street-fighter", "game", "Street Fighter", ["streetfighter"])
app("app:uu-accelerator", "game", "UU Accelerator",
    ["uu accelerator", "uu booster", "netease\\uu", "netease/uu", "=uu"])

# --- office ---------------------------------------------------------------
app("app:word", "office", "Word", ["winword", "com.microsoft.word"])
app("app:excel", "office", "Excel", ["excel.exe", "com.microsoft.excel"])
app("app:powerpoint", "office", "PowerPoint", ["powerpnt", "com.microsoft.powerpoint"])
app("app:outlook", "office", "Outlook", ["outlook"])
app("app:wps", "office", "WPS Office", ["wps", "=et", "wpp"])
app("app:acrobat", "office", "Acrobat", ["acrobat", "acrord32"])
app("app:foxit", "office", "Foxit Reader", ["foxit"])
app("app:sumatrapdf", "office", "SumatraPDF", ["sumatrapdf"])
app("app:apple-mail", "office", "Mail", ["com.apple.mail"])

# --- creation -------------------------------------------------------------
app("app:photoshop", "create", "Photoshop", ["photoshop"])
app("app:illustrator", "create", "Illustrator", ["illustrator"])
app("app:premiere", "create", "Premiere Pro", ["premiere"])
app("app:after-effects", "create", "After Effects", ["afterfx"])
app("app:lightroom", "create", "Lightroom", ["lightroom"])
app("app:figma", "create", "Figma", ["figma"])
app("app:blender", "create", "Blender", ["blender"])
app("app:obs", "create", "OBS Studio", ["obs64", "=obs", "obs studio"])
app("app:capcut", "create", "CapCut",
    ["com.lemon.lvpro", "jianyingpro", "jianying", "capcut", "剪映"],
    {"zh": "剪映专业版"})
app("app:davinci", "create", "DaVinci Resolve", ["davinci", "resolve.exe"])
app("app:audition", "create", "Audition", ["audition"])
app("app:coreldraw", "create", "CorelDRAW", ["coreldraw"])
app("app:3dsmax", "create", "3ds Max", ["3dsmax"])
app("app:maya", "create", "Maya", ["maya.exe"])
app("app:wallpaper-engine", "create", "Wallpaper Engine",
    ["wallpaperengine", "wallpaper engine", "wallpaperui", "wallpaper32",
     "wallpaper64", "webwallpaper"])

# --- notes / reading ------------------------------------------------------
app("app:notion", "notes", "Notion", ["notion"])
app("app:obsidian", "notes", "Obsidian", ["obsidian"])
app("app:typora", "notes", "Typora", ["typora"])
app("app:evernote", "notes", "Evernote", ["evernote"])
app("app:youdao", "notes", "Youdao Note", ["youdao"])
app("app:joplin", "notes", "Joplin", ["joplin"])
app("app:logseq", "notes", "Logseq", ["logseq"])
app("app:onenote", "notes", "OneNote", ["onenote"])
app("app:apple-notes", "notes", "Notes", ["com.apple.notes"])
app("app:zotero", "read", "Zotero", ["zotero"])
app("app:calibre", "read", "calibre", ["calibre"])
app("app:kindle", "read", "Kindle", ["kindle"])

# --- self -----------------------------------------------------------------
app("app:timearc", "other", "TimeArc", ["timearc", "time-arc"])

# --- sites (scope @browser, title needles) --------------------------------
site("site:bilibili", "video", "bilibili",
     ["bilibili", "b23.tv", "哔哩哔哩"], {"zh": "哔哩哔哩"})
site("site:douyin", "video", "Douyin", ["douyin", "抖音"], {"zh": "抖音"})
site("site:xiaohongshu", "social", "Xiaohongshu",
     ["xiaohongshu", "小红书"], {"zh": "小红书"})
site("site:weibo", "social", "Weibo", ["weibo", "微博"], {"zh": "微博"})
site("site:zhihu", "read", "Zhihu", ["zhihu", "知乎"], {"zh": "知乎"})
site("site:taobao", "shop", "Taobao", ["taobao", "淘宝"], {"zh": "淘宝"})
site("site:tmall", "shop", "Tmall", ["tmall", "天猫"], {"zh": "天猫"})
site("site:jd", "shop", "JD", ["jd.com", "京东", "jingdong"], {"zh": "京东"})
site("site:pinduoduo", "shop", "Pinduoduo",
     ["pinduoduo", "拼多多", "yangkeduo"], {"zh": "拼多多"})
site("site:baidu", "browse", "Baidu", ["baidu", "百度"], {"zh": "百度"})
site("site:iqiyi", "video", "iQIYI", ["iqiyi", "爱奇艺"], {"zh": "爱奇艺"})
site("site:youku", "video", "Youku", ["youku", "优酷"], {"zh": "优酷"})
site("site:tencent-video", "video", "Tencent Video",
     ["腾讯视频", "v.qq.com", "qqlive"], {"zh": "腾讯视频"})
site("site:mango-tv", "video", "Mango TV", ["mgtv", "芒果tv"], {"zh": "芒果TV"})
site("site:kuaishou", "video", "Kuaishou", ["kuaishou", "快手"], {"zh": "快手"})
site("site:xigua", "video", "Xigua Video",
     ["ixigua", "西瓜视频"], {"zh": "西瓜视频"})
site("site:acfun", "video", "AcFun", ["acfun", "acfun.cn"])
site("site:youtube", "video", "YouTube", ["youtube", "youtu.be"])
site("site:netflix", "video", "Netflix", ["netflix"])
site("site:twitch", "video", "Twitch", ["twitch"])
site("site:douyu", "video", "Douyu", ["douyu", "斗鱼"], {"zh": "斗鱼"})
site("site:huya", "video", "Huya", ["huya", "虎牙"], {"zh": "虎牙"})
site("site:douban", "read", "Douban", ["douban", "豆瓣"], {"zh": "豆瓣"})
site("site:csdn", "dev", "CSDN", ["csdn"])
site("site:github", "dev", "GitHub", ["github"])
site("site:stackoverflow", "dev", "Stack Overflow", ["stack overflow", "stackoverflow"])
site("site:arxiv", "read", "arXiv", ["arxiv"])
site("site:wikipedia", "read", "Wikipedia", ["wikipedia", "维基百科"])
site("site:spotify-web", "music", "Spotify Web", ["spotify"])
site("site:qq-music-web", "music", "QQ Music", ["qq音乐", "y.qq.com"], {"zh": "QQ音乐"})
site("site:netease-music-web", "music", "NetEase Cloud Music",
     ["music.163", "网易云音乐"], {"zh": "网易云音乐"})
site("site:alipay", "other", "Alipay", ["alipay", "支付宝"], {"zh": "支付宝"})
site("site:meituan", "other", "Meituan", ["meituan", "美团"], {"zh": "美团"})
site("site:dianping", "other", "Dianping",
     ["dianping", "大众点评"], {"zh": "大众点评"})

# ------------------------------------------------------------------- emit
out = []
w = out.append
w('// SPDX-License-Identifier: GPL-3.0-or-later')
w('')
w('#ifndef TIMEARC_SERVICES_CATEGORIZATION_DEFAULT_RULES_H')
w('#define TIMEARC_SERVICES_CATEGORIZATION_DEFAULT_RULES_H')
w('')
w('#include "services/categorization/rule.h"')
w('')
w('// GENERATED TABLE - the shipped default categorization.')
w('//')
w('// English-first: every label carries "en"; other locales are optional and')
w('// fall back to it. Non-ASCII uses \\uXXXX escapes because the build sets no')
w('// /utf-8 flag (see normalize.h).')
w('//')
w('// This is data, not logic. Adding an app is one entry here - no registry, no')
w('// second table, no keyword ladder. Regenerate with')
w('// scratchpad/gen_rules.py if you prefer editing the readable source.')
w('namespace TimeArc::Categorization {')
w('')
w('inline constexpr int kDefaultTableVersion = 1;')
w('')
w('namespace detail {')
w('')
w('inline Rule makeRule(const QString& id, const QString& category,')
w('                     const QString& labelEn, const QStringList& app,')
w('                     const QStringList& title) {')
w('  Rule rule;')
w('  rule.id = id;')
w('  rule.category = category;')
w('  rule.label.insert(QStringLiteral("en"), labelEn);')
w('  rule.app = app;')
w('  rule.title = title;')
w('  return rule;')
w('}')
w('')
w('inline Rule withIcon(Rule rule, const QString& icon) {')
w('  rule.icon = icon;')
w('  return rule;')
w('}')
w('')
w('inline Rule withLabel(Rule rule, const QString& language,')
w('                      const QString& text) {')
w('  rule.label.insert(language, text);')
w('  return rule;')
w('}')
w('')
w('inline CategoryDef makeCategory(const QString& id, const QString& en,')
w('                                const QString& zh, const QString& ja,')
w('                                const QStringList& traits) {')
w('  CategoryDef category;')
w('  category.id = id;')
w('  category.label.insert(QStringLiteral("en"), en);')
w('  category.label.insert(QStringLiteral("zh"), zh);')
w('  category.label.insert(QStringLiteral("ja"), ja);')
w('  category.traits = traits;')
w('  return category;')
w('}')
w('')
w('}  // namespace detail')
w('')
w('inline QVector<CategoryDef> defaultCategories() {')
w('  return {')
for i, (cid, en, zh, ja, traits) in enumerate(CATEGORIES):
    tail = ',' if i < len(CATEGORIES) - 1 else ''
    w('      detail::makeCategory(%s, %s, %s, %s,' % (q(cid), q(en), q(zh), q(ja)))
    w('                           %s)%s' % (sl(traits), tail))
w('  };')
w('}')
w('')
w('inline QVector<Rule> defaultRules() {')
w('  QVector<Rule> rules;')
w('  rules.reserve(%d);' % len(A))
for rid, cat, en, apps, titles, scope, extra in A:
    call = 'detail::makeRule(%s, %s, %s,\n                   %s,\n                   %s)' % (
        q(rid), q(cat), q(en), sl(apps), sl(titles))
    icon = SITE_ICONS.get(rid.split('.')[0] if rid.startswith('site:') else rid)
    if icon:
        call = 'detail::withIcon(\n      %s,\n      %s)' % (
            call, q('qrc:/qt/qml/time_arc/resources/app/icons/sites/' + icon))
    for lang, text in extra.items():
        call = 'detail::withLabel(\n      %s,\n      %s, %s)' % (call, q(lang), q(text))
    w('  rules.append(%s);' % call)
w('  return rules;')
w('}')
w('')
w('inline RuleSet defaultRuleSet() {')
w('  RuleSet set;')
w('  set.schema = 1;')
w('  set.fromDefaults = kDefaultTableVersion;')
w('  set.categories = defaultCategories();')
w('  set.rules = defaultRules();')
w('  return set;')
w('}')
w('')
w('}  // namespace TimeArc::Categorization')
w('')
w('#endif  // TIMEARC_SERVICES_CATEGORIZATION_DEFAULT_RULES_H')

open('src/services/categorization/default_rules.h', 'w', encoding='ascii').write('\n'.join(out) + '\n')
print('rules:', len(A), 'categories:', len(CATEGORIES),
      'browsers:', len(BROWSER_TARGETS))
