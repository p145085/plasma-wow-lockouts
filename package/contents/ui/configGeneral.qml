import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "Api.js" as Api
import "Lockouts.js" as Lockouts

KCM.SimpleKCM {
    id: page

    property string cfg_region
    property alias cfg_clientId: clientId.text
    property alias cfg_clientSecret: clientSecret.text
    property alias cfg_characters: characters.text
    property alias cfg_includeDungeons: includeDungeons.checked
    property int cfg_resetDay
    property alias cfg_resetHour: resetHour.value
    property alias cfg_refreshMinutes: refreshMinutes.value
    property alias cfg_showCountInPanel: showCount.checked

    readonly property var regions: [
        { value: "us", text: i18n("Americas & Oceania") },
        { value: "eu", text: i18n("Europe") },
        { value: "kr", text: i18n("Korea") },
        { value: "tw", text: i18n("Taiwan") }
    ]
    readonly property var days: [i18n("Sunday"), i18n("Monday"), i18n("Tuesday"), i18n("Wednesday"),
                                 i18n("Thursday"), i18n("Friday"), i18n("Saturday")]

    property bool testing: false
    property string testResult: ""
    property bool testOk: false

    ErrorText { id: errors }

    // Checks the values in the form, before they are applied.
    function runTest() {
        var chars = Lockouts.parseCharacters(characters.text)
        var cfg = {
            region: cfg_region, clientId: clientId.text.trim(), clientSecret: clientSecret.text.trim(),
            locale: Api.apiLocale(Qt.locale().name), dungeons: includeDungeons.checked
        }
        testing = true
        testResult = ""
        Api.fetchAll({}, cfg, chars, function (err, results) {
            testing = false
            if (err !== "" && err !== "expired") {
                testOk = false
                testResult = errors.text(err)
                return
            }
            var lines = [i18n("✓ Connected to Battle.net.")]
            var ok = true
            var since = Lockouts.lastReset(Date.now(), Lockouts.schedule(cfg_region, cfg_resetDay, resetHour.value))
            chars.forEach(function (c) {
                var r = results[c.key]
                if (!c.valid || !r || r.error !== "") {
                    ok = false
                    lines.push(i18n("✗ %1: %2", c.raw, errors.text(c.valid ? (r ? r.error : "") : "format")))
                } else {
                    lines.push(i18n("✓ %1 (%2), level %3 %4: %5", r.summary.name, r.summary.realm, r.summary.level, r.summary.className,
                                    i18np("1 lockout this week", "%1 lockouts this week", Lockouts.lockouts(r.entries, since).length)))
                }
            })
            if (chars.length === 0)
                lines.push(i18n("Add a character to see it here."))
            testOk = ok
            testResult = lines.join("\n")
        })
    }

    Kirigami.FormLayout {
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: clientId.text.trim() === "" || clientSecret.text.trim() === ""
            type: Kirigami.MessageType.Information
            text: i18n("<b>One-time setup:</b> the widget reads your characters through Blizzard's official API, which needs a free API client of your own.<br>"
                       + "1. Sign in at <a href=\"https://develop.battle.net/access/clients\">develop.battle.net/access/clients</a> with your Battle.net account.<br>"
                       + "2. Click <i>Create Client</i>. Any name works, such as \"Plasma lockouts\". Leave the redirect URL empty, tick that it is for personal use, and save.<br>"
                       + "3. Copy the <i>Client ID</i> and <i>Client Secret</i> into the fields below, add your characters, and click <i>Test</i>.")
            onLinkActivated: link => Qt.openUrlExternally(link)
        }

        QQC2.ComboBox {
            id: region
            Kirigami.FormData.label: i18n("Region:")
            model: page.regions
            textRole: "text"
            valueRole: "value"
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_region))
            onActivated: page.cfg_region = currentValue
        }
        QQC2.TextField {
            id: clientId
            Kirigami.FormData.label: i18n("Client ID:")
            Layout.fillWidth: true
            placeholderText: i18n("From develop.battle.net")
        }
        Kirigami.PasswordField {
            id: clientSecret
            Kirigami.FormData.label: i18n("Client secret:")
            Layout.fillWidth: true
            placeholderText: i18n("Secret")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.TextArea {
            id: characters
            Kirigami.FormData.label: i18n("Characters:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            Layout.minimumHeight: Kirigami.Units.gridUnit * 5
            placeholderText: i18n("Thrall-Argent Dawn\nJaina-Stormscale")
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("One per line as Name-Realm, the way the game shows cross-realm names. Spaces and capitals in the realm name don't matter.")
        }

        RowLayout {
            QQC2.Button {
                text: i18n("Test")
                icon.name: "network-connect"
                enabled: !page.testing && clientId.text.trim() !== "" && clientSecret.text.trim() !== ""
                onClicked: page.runTest()
            }
            QQC2.BusyIndicator {
                visible: page.testing
                running: visible
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }
        }
        QQC2.Label {
            visible: page.testResult !== ""
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            color: page.testOk ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            text: page.testResult
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: includeDungeons
            Kirigami.FormData.label: i18n("Show:")
            text: i18n("Mythic dungeon lockouts")
        }
        QQC2.CheckBox {
            id: showCount
            text: i18n("Number of lockouts on the panel icon")
        }
        QQC2.SpinBox {
            id: refreshMinutes
            Kirigami.FormData.label: i18n("Refresh every (minutes):")
            from: 5
            to: 240
        }

        Item { Kirigami.FormData.isSection: true }

        RowLayout {
            Kirigami.FormData.label: i18n("Weekly reset:")
            QQC2.ComboBox {
                id: resetDay
                model: [i18n("Region default")].concat(page.days)
                Component.onCompleted: currentIndex = page.cfg_resetDay + 1
                onActivated: page.cfg_resetDay = currentIndex - 1
            }
            QQC2.SpinBox {
                id: resetHour
                visible: resetDay.currentIndex > 0
                from: 0
                to: 23
                textFromValue: (v) => String(v).padStart(2, "0") + ":00 UTC"
                valueFromText: (t) => parseInt(t, 10)
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: {
                var s = Lockouts.schedule(page.cfg_region, page.cfg_resetDay, resetHour.value)
                var next = Lockouts.lastReset(Date.now(), s) + Lockouts.WEEK_MS
                return i18n("Next reset: %1 your time.", Qt.formatDateTime(new Date(next), "dddd hh:mm"))
            }
        }
    }
}
