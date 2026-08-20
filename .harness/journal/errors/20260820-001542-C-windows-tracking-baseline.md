# Error Report - windows-tracking-baseline

## Metadata

- Level: **L1**
- Track: **C**
- Topic: windows-tracking-baseline
- Recorded: 2026-08-20T00:15:42Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[178/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/CardCarousel_qml.cpp.obj
[179/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/MemoryCard_qml.cpp.obj
[180/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/TagChip_qml.cpp.obj
[181/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/CalendarSyncList_qml.cpp.obj
[182/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/TodayConclusionCard_qml.cpp.obj
[183/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/SilkyFlickable_qml.cpp.obj
[184/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/DailyUsageShare_qml.cpp.obj
[185/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/RecapSlide_qml.cpp.obj
[186/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/GlassTextField_qml.cpp.obj
[187/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/GlassSwitch_qml.cpp.obj
[188/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/GlassSlider_qml.cpp.obj
[189/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/GlassComboBox_qml.cpp.obj
[190/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/KbdChip_qml.cpp.obj
[191/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/RecapOverlay_qml.cpp.obj
[192/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/memorylake/NotifierTray_qml.cpp.obj
[193/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/MobileAppShell_qml.cpp.obj
[194/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/MobileTheme_qml.cpp.obj
[195/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/pages/MobileHomePage_qml.cpp.obj
[196/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/pages/MobileStatsPage_qml.cpp.obj
[197/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileStatusBar_qml.cpp.obj
[198/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileSectionTitle_qml.cpp.obj
[199/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/pages/MobileHistoryPage_qml.cpp.obj
[200/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileSwitch_qml.cpp.obj
[201/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/pages/MobileSettingsPage_qml.cpp.obj
[202/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileSettingRow_qml.cpp.obj
[203/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileTabButton_qml.cpp.obj
[204/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileGlassPanel_qml.cpp.obj
[205/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileSymbolIcon_qml.cpp.obj
[206/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileAppIcon_qml.cpp.obj
[207/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileLaunchOverlay_qml.cpp.obj
[208/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileUsageRankRow_qml.cpp.obj
[209/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileFlipCard_qml.cpp.obj
[210/227] Building CXX object CMakeFiles/time-arc.dir/build/.qt/rcc/qrc_time-arc_raw_qml_0.cpp.obj
[211/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileMonthProfiles_js.cpp.obj
[212/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileShareOverlay_qml.cpp.obj
[213/227] Linking CXX executable timearc_pomodoro_test.exe
[214/227] Linking CXX executable timearc_db_smoke.exe
[215/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileSeasonScene_qml.cpp.obj
[216/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileMonthlyStory_qml.cpp.obj
[217/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileRoundedFrame_qml.cpp.obj
[218/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileShareActionBar_qml.cpp.obj
[219/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/monthly/MonthlyCoverPage_qml.cpp.obj
[220/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/monthly/MonthlyOverviewPage_qml.cpp.obj
[221/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/monthly/MonthlyHighlightPage_qml.cpp.obj
[222/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/MobileRankingShareOverlay_qml.cpp.obj
[223/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/monthly/MonthlyCompanionPage_qml.cpp.obj
[224/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/monthly/MonthlyRankingPage_qml.cpp.obj
[225/227] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/mobile/components/monthly/MonthlySharePage_qml.cpp.obj
[226/227] Linking CXX executable TimeArc.exe
FAILED: TimeArc.exe
C:\WINDOWS\system32\cmd.exe /C "cd . && D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe  -mwindows @CMakeFiles\time-arc.rsp -o TimeArc.exe -Wl,--out-implib,libTimeArc.dll.a -Wl,--major-image-version,0,--minor-image-version,0 && C:\WINDOWS\system32\cmd.exe /C "cd /D D:\TimeArc\time-arc\build && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E make_directory D:/TimeArc/time-arc/build/assets && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E remove -f D:/TimeArc/time-arc/build/assets/timearc-gui-assets.rcc && cd /D D:\TimeArc\time-arc\build && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E copy_if_different D:/TimeArc/time-arc/build/timearc-backgrounds.rcc D:/TimeArc/time-arc/build/assets/timearc-backgrounds.rcc && cd /D D:\TimeArc\time-arc\build && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E copy_if_different D:/TimeArc/time-arc/build/timearc-site-icons.rcc D:/TimeArc/time-arc/build/assets/timearc-site-icons.rcc && cd /D D:\TimeArc\time-arc\build && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E copy_if_different D:/TimeArc/time-arc/build/timearc-monthly-recap.rcc D:/TimeArc/time-arc/build/assets/timearc-monthly-recap.rcc""
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
