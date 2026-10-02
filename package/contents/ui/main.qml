import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "Api.js" as Api
import "Lockouts.js" as Lockouts

PlasmoidItem {
    id: root

    readonly property string iconPath: Qt.resolvedUrl("../icons/lockouts.svg").toString().replace("file://", "")
    readonly property var cfg: Plasmoid.configuration

    readonly property bool configured: cfg.clientId.trim() !== "" && cfg.clientSecret.trim() !== ""
    readonly property var characters: Lockouts.parseCharacters(cfg.characters)
    readonly property var apiCfg: ({
        region: cfg.region,
        clientId: cfg.clientId.trim(),
        clientSecret: cfg.clientSecret.trim(),
        locale: Api.apiLocale(Qt.locale().name),
        dungeons: cfg.includeDungeons
    })

    property real now: Date.now()
    readonly property var resetSchedule: Lockouts.schedule(cfg.region, cfg.resetDay, cfg.resetHour)
    // Kills before the last reset drop out of `view` on their own when `now` passes it.
    readonly property real lastReset: Lockouts.lastReset(now, resetSchedule)
    readonly property real nextReset: lastReset + Lockouts.WEEK_MS
    readonly property string resetCountdown: Lockouts.formatCountdown(nextReset - now)

    // Per character key: { summary, entries, error, fetchedAt }. Cached in the config so the
    // widget has something to show when it starts offline.
    property var results: ({})
    // Token and realm index, reused between fetches.
    property var apiState: ({})
    property string errorMsg: ""
    property bool loading: false
    property date lastUpdated
    property int generation: 0

    // One row per configured character, with this week's lockouts.
    readonly property var view: characters.map(function (c) {
        var r = results[c.key] || {}
        return {
            key: c.key,
            name: r.summary ? r.summary.name : (c.valid ? c.name : c.raw),
            realm: r.summary ? r.summary.realm : c.realm,
            summary: r.summary || null,
            error: c.valid ? (r.error || "") : "format",
            lockouts: Lockouts.lockouts(r.entries, lastReset)
        }
    })
    readonly property int lockoutCount: view.reduce((n, c) => n + c.lockouts.length, 0)

    ErrorText { id: errors }

    function loadCache() {
        try {
            var cached = JSON.parse(cfg.cachedResults || "{}")
            results = cached && typeof cached === "object" ? cached : {}
        } catch (e) {
            results = {}
        }
    }

    function refresh(retried) {
        if (!configured)
            return
        var gen = ++generation
        loading = true
        Api.fetchAll(apiState, apiCfg, characters, function (err, fresh) {
            if (gen !== generation)
                return    // settings changed while this was in flight
            if (err === "expired" && !retried) {
                refresh(true)
                return
            }
            loading = false
            var next = {}
            characters.forEach(function (c) {
                var old = results[c.key]
                var r = fresh[c.key]
                if (r && r.error === "")
                    next[c.key] = { summary: r.summary, entries: r.entries, error: "", fetchedAt: Date.now() }
                else if (old || r)
                    // Keep what we had, so a hiccup doesn't wipe the list.
                    next[c.key] = Object.assign({}, old || { entries: [] }, { error: r ? r.error : "" })
            })
            results = next
            cfg.cachedResults = JSON.stringify(next)
            errorMsg = err === "" ? "" : errors.text(err)
            if (err === "")
                lastUpdated = new Date()
            else
                retryTimer.restart()
        })
    }

    // Credentials, region or characters changed. Api.js notices new credentials or a new
    // region by itself and fetches a new token or realm index.
    readonly property string settingsKey: [cfg.region, cfg.clientId, cfg.clientSecret, cfg.characters, cfg.includeDungeons].join("\n")
    onSettingsKeyChanged: settingsTimer.restart()

    Timer {
        id: settingsTimer
        interval: 1500
        onTriggered: root.refresh(false)
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Timer {
        interval: Math.max(5, root.cfg.refreshMinutes) * 60000
        running: root.configured
        repeat: true
        onTriggered: root.refresh(false)
    }

    Timer {
        id: retryTimer
        interval: 5 * 60000
        onTriggered: root.refresh(false)
    }

    Component.onCompleted: {
        loadCache()
        refresh(false)
    }

    Plasmoid.icon: iconPath

    toolTipMainText: !configured
        ? i18n("WoW Raid Lockouts: not set up")
        : lockoutCount === 0
            ? i18n("No lockouts this week")
            : i18np("1 lockout this week", "%1 lockouts this week", lockoutCount)
    toolTipSubText: [
        view.filter(c => c.lockouts.length > 0).map(c => c.name + ": " + c.lockouts.map(l => l.instance + " " + l.difficulty + " " + (l.cleared ? i18n("cleared") : l.killed + "/" + l.total)).join(", ")).join("\n"),
        i18n("Resets in %1", resetCountdown),
        errorMsg
    ].filter(s => s !== "").join("\n")

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            enabled: root.configured
            onTriggered: root.refresh(false)
        }
    ]

    compactRepresentation: CompactView {}
    fullRepresentation: FullView {}
}
