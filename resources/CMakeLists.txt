set(TIME_ARC_RESOURCE_FILES
    resources/background.png
    resources/background_night.png
    resources/icons/app_icon.svg
    resources/icons/home.svg
    resources/icons/chat.svg
    resources/icons/bilibili.svg
    resources/icons/sites/acfun.ico
    resources/icons/sites/douyin.ico
    resources/icons/sites/douyu.ico
    resources/icons/sites/huya.png
    resources/icons/sites/iqiyi.ico
    resources/icons/sites/kuaishou.ico
    resources/icons/sites/mango-tv.ico
    resources/icons/sites/netflix.ico
    resources/icons/sites/tencent-video.ico
    resources/icons/sites/twitch.ico
    resources/icons/sites/xiaohongshu.ico
    resources/icons/sites/xigua-video.ico
    resources/icons/sites/youtube.ico
    resources/icons/sites/youku.ico
    resources/icons/calendar.svg
    resources/icons/stats.svg
    resources/icons/user.svg
    resources/icons/settings.svg
    resources/icons/recap.svg
    resources/memorylake/memory_bg.png
    resources/memorylake/memory_cat_1.png
    resources/memorylake/memory_cat_2.png
    resources/memorylake/hotspring_01.png
    resources/memorylake/hotspring_02.png
    resources/memorylake/hotspring_03.png
    resources/memorylake/hotspring_04.png
    resources/memorylake/hotspring_05.png
    resources/memorylake/hotspring_06.png
    resources/memorylake/hotspring_07.png
    resources/memorylake/hotspring_08.png
    resources/memorylake/memory_pond_rocks.png
    resources/memorylake/memory_tree.png
    resources/memorylake/desktop.png
    resources/memorylake/exit8.png
    resources/memorylake/senren.png
    resources/memorylake/p3r.png
    resources/memorylake/elden.png
    # 第三方许可证全文（F1-S2 共享产物：随包分发 + F2 应用内渲染，单一真相源）。
    # qrc 内嵌 → 离线可达（rules/06 §4(2) / CHARTER I6）。新增 thirdparty 组件时
    # 须同步在此追加文本并补一行页面条目（rules/06 §4(3)）。
    # 只内嵌 F2 页面实际呈现的组件文本（Qt 两份 + SQLite + Parson + 本项目）。
    # mingw-runtime-exception.txt（libgcc/libstdc++ 的 GCC 运行时例外）与 mingw-w64-winpthreads.txt
    # （libwinpthread 的 MinGW-w64 MIT）留在磁盘作 F1 打包产物（由 F1-S3 随 NOTICE 分发），不入 qrc：
    # 本页不单列 MinGW 运行库，避免内嵌一份无 UI 入口的悬空资源（CHARTER I6）。
    resources/licenses/qt-lgpl-3.0.txt
    resources/licenses/qt-gpl-3.0.txt
    resources/licenses/sqlite-public-domain.txt
    resources/licenses/parson-mit.txt
    resources/licenses/timearc-gpl-3.0.txt
)

set(TIME_ARC_RESOURCE_FILES ${TIME_ARC_RESOURCE_FILES} PARENT_SCOPE)
