import QtQuick
import QtQuick.Controls
import "components"

Item {
    id: root

    anchors.fill: parent

    property string activePage: "home"
    property int refreshTick: 0
    property var selectedProject: ({ name: "学习计划", tag: "学习" })

    MobileTheme {
        id: mobileTheme
    }

    property var theme: mobileTheme

    function showPage(page) {
        activePage = page
    }

    function openTimerPage() {
        activePage = "timer"
    }

    function openProject(projectName, tag) {
        selectedProject = {
            name: projectName && projectName.length > 0 ? projectName : "学习计划",
            tag: tag && tag.length > 0 ? tag : "学习"
        }
        activePage = "detail"
    }

    function openStatsPage() {
        activePage = "stats"
    }

    function openSettingsPage() {
        activePage = "settings"
    }

    function goBack(defaultPage) {
        activePage = defaultPage && defaultPage.length > 0 ? defaultPage : "home"
    }

    function navPage() {
        if (activePage === "timer" || activePage === "detail" || activePage === "stats" || activePage === "settings")
            return activePage === "settings" || activePage === "stats" ? "profile" : "home"
        return activePage
    }

    function sourceForPage() {
        if (activePage === "chat") return Qt.resolvedUrl("pages/MobileChatPage.qml")
        if (activePage === "memory") return Qt.resolvedUrl("pages/MobileMemoryLakePage.qml")
        if (activePage === "calendar") return Qt.resolvedUrl("pages/MobileCalendarPage.qml")
        if (activePage === "profile") return Qt.resolvedUrl("pages/MobileProfilePage.qml")
        if (activePage === "timer") return Qt.resolvedUrl("pages/MobileTimerPage.qml")
        if (activePage === "detail") return Qt.resolvedUrl("pages/MobileProjectDetailPage.qml")
        if (activePage === "stats") return Qt.resolvedUrl("pages/MobileStatsPage.qml")
        if (activePage === "settings") return Qt.resolvedUrl("pages/MobileSettingsPage.qml")
        return Qt.resolvedUrl("pages/MobileHomePage.qml")
    }

    function secondsToDisplay(seconds) {
        var total = Math.max(0, Math.floor(seconds ? seconds : 0))
        if (total <= 0) return "0m"
        if (total < 60) return "<1m"
        var h = Math.floor(total / 3600)
        var m = Math.floor((total % 3600) / 60)
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    function formatTimer(seconds) {
        var total = Math.max(0, Math.floor(seconds ? seconds : 0))
        var h = Math.floor(total / 3600)
        var m = Math.floor((total % 3600) / 60)
        var s = total % 60
        function pad(n) { return n < 10 ? "0" + n : "" + n }
        return pad(h) + ":" + pad(m) + ":" + pad(s)
    }

    function todaySoftwareRaw() {
        refreshTick
        if (!usageStatManager)
            return []
        return usageStatManager.activeSoftwareForRange("day")
    }

    function todaySoftwareSeconds() {
        refreshTick
        if (!usageStatManager)
            return 0
        return usageStatManager.activeSoftwareSecondsForRange("day")
    }

    function todayManualSeconds() {
        refreshTick
        return projectManager ? projectManager.todayProjectMinutes * 60 : 0
    }

    function todayTotalSeconds() {
        var total = todaySoftwareSeconds() + todayManualSeconds()
        return total > 0 ? total : 4 * 3600 + 31 * 60
    }

    function monthTotalSeconds() {
        var software = usageStatManager ? usageStatManager.activeSoftwareSecondsForRange("month") : 0
        var manual = projectManager ? projectManager.monthProjectMinutes * 60 : 0
        return software + manual
    }

    function yearTotalSeconds() {
        var software = usageStatManager ? usageStatManager.activeSoftwareSecondsForRange("year") : 0
        var manual = projectManager ? projectManager.yearProjectMinutes * 60 : 0
        return software + manual
    }

    function appIconSource(item) {
        var appName = item && item.name ? item.name : (item && item.appName ? item.appName : "")
        var appId = item && item.appId ? item.appId : ""
        var path = item && item.path ? item.path : ""
        var identity = (appName + " " + appId + " " + path).toLowerCase()
        if (identity.indexOf("bilibili") >= 0)
            return Qt.resolvedUrl("../../resources/icons/bilibili.svg")
        if (path && path.length > 0)
            return "image://appicon/" + encodeURIComponent(path)
        if (appId && appId.length > 0)
            return "image://appicon/" + encodeURIComponent(appId)
        return ""
    }

    function appName(item) {
        return item && item.name ? item.name : (item && item.appName ? item.appName : "Unknown app")
    }

    function todaySoftwareItems(maxCount) {
        refreshTick
        var raw = todaySoftwareRaw()
        var result = []
        for (var i = 0; i < raw.length && result.length < maxCount; ++i) {
            var item = raw[i]
            var seconds = item.seconds ? item.seconds : 0
            if (seconds <= 0)
                continue
            result.push({
                title: appName(item),
                timeRange: item.live ? "现在" : "今日",
                duration: item.time ? item.time : secondsToDisplay(seconds),
                seconds: seconds,
                iconSource: appIconSource(item),
                iconColor: theme.appIconColor(appName(item))
            })
        }
        if (result.length > 0)
            return result
        return [
            { title: "LockApp", timeRange: "09:00", duration: "1h 34m", seconds: 5640, iconSource: "", iconColor: theme.appIconColor("LockApp") },
            { title: "Google Chrome", timeRange: "10:30", duration: "1h 15m", seconds: 4500, iconSource: "", iconColor: theme.appIconColor("Chrome") },
            { title: "VS Code", timeRange: "14:00", duration: "30m", seconds: 1800, iconSource: "", iconColor: theme.appIconColor("VS Code") },
            { title: "Discord", timeRange: "15:00", duration: "30m", seconds: 1800, iconSource: "", iconColor: theme.appIconColor("Discord") }
        ]
    }

    function todayTimelineItems() {
        var list = todaySoftwareItems(4)
        if (list.length >= 4) {
            list[0].timeRange = "09:00"
            list[1].timeRange = "10:30"
            list[2].timeRange = "14:00"
            list[3].timeRange = "15:00"
        }
        return list
    }

    function maxSeconds(items) {
        var maxValue = 1
        for (var i = 0; i < items.length; ++i)
            maxValue = Math.max(maxValue, items[i].seconds ? items[i].seconds : 0)
        return maxValue
    }

    function todaySecondsForProject(projectName, tag) {
        refreshTick
        if (!projectManager)
            return 0
        var list = projectManager.projectsForRange("day")
        for (var i = 0; i < list.length; ++i) {
            if (list[i].name === projectName && list[i].tag === tag)
                return list[i].seconds ? list[i].seconds : 0
        }
        return 0
    }

    function projectItems() {
        refreshTick
        var result = []
        var raw = projectManager ? projectManager.projects : []
        for (var i = 0; i < raw.length; ++i) {
            result.push({
                name: raw[i].name ? raw[i].name : "未命名项目",
                tag: raw[i].tag ? raw[i].tag : "其他",
                todaySeconds: todaySecondsForProject(raw[i].name, raw[i].tag)
            })
        }
        if (result.length > 0)
            return result
        return [
            { name: "学习计划", tag: "学习", todaySeconds: 0 },
            { name: "论文整理", tag: "阅读", todaySeconds: 0 },
            { name: "健身计划", tag: "运动", todaySeconds: 0 }
        ]
    }

    function startProject(projectName, tag) {
        if (projectManager && projectName && projectName.length > 0)
            projectManager.ensureProject(projectName, tag && tag.length > 0 ? tag : "其他")
        if (timerManager && projectName && projectName.length > 0)
            timerManager.startProject(projectName)
        openProject(projectName, tag)
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: theme.pageTop }
            GradientStop { position: 1.0; color: theme.pageBottom }
        }
    }

    Loader {
        id: pageLoader
        anchors.fill: parent
        anchors.bottomMargin: bottomNav.height - 4
        source: root.sourceForPage()
        onLoaded: {
            if (!item)
                return
            item.theme = root.theme
            item.shell = root
        }
    }

    MobileBottomNavBar {
        id: bottomNav
        theme: root.theme
        currentPage: root.navPage()
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        onNavigate: function(page) { root.showPage(page) }
        onPlusClicked: root.openTimerPage()
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (usageStatManager)
                usageStatManager.refresh()
            root.refreshTick += 1
        }
    }

    Connections {
        target: usageStatManager
        function onUsageStatsChanged() {
            root.refreshTick += 1
        }
    }

    Connections {
        target: projectManager
        function onProjectsChanged() {
            root.refreshTick += 1
        }
    }

    Connections {
        target: timerManager
        function onElapsedSecondsChanged() {
            root.refreshTick += 1
        }

        function onTimerStopped(projectName, elapsedSeconds) {
            if (projectManager && projectName && projectName.length > 0 && elapsedSeconds > 0)
                projectManager.addElapsedTime(projectName, elapsedSeconds)
            root.refreshTick += 1
        }
    }
}
