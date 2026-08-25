# Error Report - app-identity-ui-build-green

## Metadata

- Level: **L1**
- Track: **B**
- Topic: app-identity-ui-build-green
- Recorded: 2026-08-25T02:20:23Z
- Session: .harness/journal/sessions/20260825-0953-B-app-identity-management.md
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[147/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/DetailPanel_qml.cpp.obj
[148/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/TimeRiver_qml.cpp.obj
[149/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/TagChip_qml.cpp.obj
[150/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/CardCarousel_qml.cpp.obj
[151/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/MemoryCard_qml.cpp.obj
[152/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/TodayConclusionCard_qml.cpp.obj
[153/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/SilkyFlickable_qml.cpp.obj
[154/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/GlassSlider_qml.cpp.obj
[155/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/CalendarSyncList_qml.cpp.obj
[156/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/GlassSwitch_qml.cpp.obj
[157/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/GlassComboBox_qml.cpp.obj
[158/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/NotifierTray_qml.cpp.obj
[159/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/GlassTextField_qml.cpp.obj
[160/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/DailyUsageShare_qml.cpp.obj
[161/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/KbdChip_qml.cpp.obj
[162/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/RecapSlide_qml.cpp.obj
[163/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/pages/MobileHomePage_qml.cpp.obj
[164/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/MobileAppShell_qml.cpp.obj
[165/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/MobileTheme_qml.cpp.obj
[166/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/RecapOverlay_qml.cpp.obj
[167/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileStatusBar_qml.cpp.obj
[168/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileSectionTitle_qml.cpp.obj
[169/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileSwitch_qml.cpp.obj
[170/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/pages/MobileStatsPage_qml.cpp.obj
[171/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileGlassPanel_qml.cpp.obj
[172/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileSettingRow_qml.cpp.obj
[173/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/pages/MobileHistoryPage_qml.cpp.obj
[174/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileTabButton_qml.cpp.obj
[175/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileSymbolIcon_qml.cpp.obj
[176/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileLaunchOverlay_qml.cpp.obj
[177/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileAppIcon_qml.cpp.obj
[178/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileUsageRankRow_qml.cpp.obj
[179/195] Building CXX object CMakeFiles/time-arc.dir/build/.qt/rcc/qrc_time-arc_raw_qml_0.cpp.obj
[180/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileFlipCard_qml.cpp.obj
[181/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileMonthProfiles_js.cpp.obj
[182/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/pages/MobileSettingsPage_qml.cpp.obj
[183/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileShareActionBar_qml.cpp.obj
[184/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileShareOverlay_qml.cpp.obj
[185/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileRoundedFrame_qml.cpp.obj
[186/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/monthly/MonthlyCoverPage_qml.cpp.obj
[187/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/monthly/MonthlyOverviewPage_qml.cpp.obj
[188/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileSeasonScene_qml.cpp.obj
[189/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/monthly/MonthlyHighlightPage_qml.cpp.obj
[190/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileRankingShareOverlay_qml.cpp.obj
[191/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/monthly/MonthlyCompanionPage_qml.cpp.obj
[192/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/monthly/MonthlyRankingPage_qml.cpp.obj
[193/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileMonthlyStory_qml.cpp.obj
[194/195] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/monthly/MonthlySharePage_qml.cpp.obj
[195/195] Linking CXX executable TimeArc.exe
FAILED: TimeArc.exe
C:\WINDOWS\system32\cmd.exe /C "cd . && D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe -O3 -DNDEBUG -mwindows @CMakeFiles\time-arc.rsp -o TimeArc.exe -Wl,--out-implib,libTimeArc.dll.a -Wl,--major-image-version,0,--minor-image-version,0 && C:\WINDOWS\system32\cmd.exe /C "cd /D D:\TimeArc\time-arc\build && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E make_directory D:/TimeArc/time-arc/build/assets && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E remove -f D:/TimeArc/time-arc/build/assets/timearc-gui-assets.rcc && cd /D D:\TimeArc\time-arc\build && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E copy_if_different D:/TimeArc/time-arc/build/timearc-backgrounds.rcc D:/TimeArc/time-arc/build/assets/timearc-backgrounds.rcc && cd /D D:\TimeArc\time-arc\build && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E copy_if_different D:/TimeArc/time-arc/build/timearc-site-icons.rcc D:/TimeArc/time-arc/build/assets/timearc-site-icons.rcc && cd /D D:\TimeArc\time-arc\build && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E copy_if_different D:/TimeArc/time-arc/build/timearc-monthly-recap.rcc D:/TimeArc/time-arc/build/assets/timearc-monthly-recap.rcc""
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: cannot open output file TimeArc.exe: Permission denied

collect2.exe: error: ld returned 1 exit status
ninja: build stopped: subcommand failed.
```

## 3. Root cause

- Immediate cause:
- Underlying cause:
- Why the harness/checklists did not prevent it:

## 4. Fix

- Files changed:
- Short description:
- Commit:

## 5. Prevention

Concrete harness upgrade, or 'one-off, no harness change'.
