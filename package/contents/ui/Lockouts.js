.pragma library

var DAY_MS = 24 * 3600000
var WEEK_MS = 7 * DAY_MS

// Weekly reset per region as a UTC weekday (0 = Sunday) and hour. Blizzard keeps these fixed
// in UTC, so the local time moves with daylight saving.
var RESETS = {
    us: { day: 2, hour: 15 },   // Americas & Oceania: Tuesday 15:00 UTC
    eu: { day: 3, hour: 4 },    // Europe: Wednesday 04:00 UTC
    kr: { day: 3, hour: 23 },   // Korea: Thursday 08:00 KST
    tw: { day: 3, hour: 23 }    // Taiwan: Thursday 07:00 local
}

// A custom day (0-6) overrides the region's schedule.
function schedule(region, day, hour) {
    if (day >= 0 && day <= 6)
        return { day: day, hour: hour }
    return RESETS[region] || RESETS.us
}

// Most recent weekly reset at or before `now`.
function lastReset(now, sched) {
    var d = new Date(now)
    var t = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), sched.hour)
    t -= ((d.getUTCDay() - sched.day + 7) % 7) * DAY_MS
    if (t > now)
        t -= WEEK_MS
    return t
}

// Lowercase, no accents, no spaces or punctuation: "Mal'Ganis", "malganis" and
// "Argent Dawn" / "argent-dawn" / "ArgentDawn" compare equal.
function normalize(s) {
    s = String(s).toLowerCase()
    if (s.normalize)
        s = s.normalize("NFD").replace(/[̀-ͯ]/g, "")
    return s.replace(/[\s'’`\-().,]/g, "")
}

// Best guess at a realm slug when the realm index couldn't be loaded.
function guessSlug(realm) {
    var s = String(realm).trim().toLowerCase()
    if (s.normalize)
        s = s.normalize("NFD").replace(/[̀-ͯ]/g, "")
    return s.replace(/['’`().,]/g, "").replace(/\s+/g, "-")
}

// Realm as typed -> slug, matched against the region's realm index ({ slug, names }).
function resolveRealm(realms, realm) {
    var n = normalize(realm)
    for (var i = 0; i < realms.length; i++) {
        var r = realms[i]
        if (normalize(r.slug) === n || r.names.some(function (name) { return normalize(name) === n }))
            return r.slug
    }
    return guessSlug(realm)
}

// One character per line as "Name-Realm", the way the game writes cross-realm names.
// Character names never contain a dash, so the first one separates name and realm.
function parseCharacters(text) {
    var out = []
    var seen = {}
    var lines = String(text || "").split(/\r?\n/)
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line === "" || line.charAt(0) === "#")
            continue
        var dash = line.indexOf("-")
        var name = dash > 0 ? line.slice(0, dash).trim() : ""
        var realm = dash > 0 ? line.slice(dash + 1).trim() : ""
        var valid = name !== "" && realm !== ""
        var key = valid ? name.toLowerCase() + "-" + normalize(realm) : "invalid:" + line
        if (seen[key])
            continue
        seen[key] = true
        out.push({ raw: line, name: name, realm: realm, key: key, valid: valid })
    }
    return out
}

// Kills since `cutoff` from an /encounters/raids or /encounters/dungeons response, one entry
// per instance and difficulty. Only Mythic dungeons have a weekly lockout. The API can list
// the same instance twice (under its expansion and under "Current Season").
//
// Raids from Classic to Wrath only track some bosses, often just the last one, and those
// stats may not have updated since 2008. The encounters are in journal order, so once every
// tracked boss has died at some point the last one listed is the final boss: `finalBoss`.
function extract(data, kind, cutoff) {
    var out = []
    var seen = {}
    var expansions = (data && data.expansions) || []
    for (var i = 0; i < expansions.length; i++) {
        var instances = expansions[i].instances || []
        for (var j = 0; j < instances.length; j++) {
            var inst = instances[j]
            var modes = inst.modes || []
            for (var k = 0; k < modes.length; k++) {
                var mode = modes[k]
                var type = mode.difficulty ? mode.difficulty.type : ""
                if (kind === "dungeon" && type !== "MYTHIC")
                    continue
                var key = kind + ":" + inst.instance.id + ":" + type
                if (seen[key])
                    continue
                var progress = mode.progress || {}
                var encounters = progress.encounters || []
                var kills = encounters
                    .filter(function (e) { return e.last_kill_timestamp >= cutoff })
                    .map(function (e) { return { id: e.encounter.id, name: e.encounter.name, t: e.last_kill_timestamp } })
                if (kills.length === 0)
                    continue
                seen[key] = true
                out.push({
                    key: key, kind: kind, instance: inst.instance.name, instanceId: inst.instance.id,
                    difficulty: mode.difficulty.name, difficultyType: type,
                    total: progress.total_count || 0, kills: kills,
                    finalBoss: encounters.length > 0 && progress.completed_count >= progress.total_count
                        ? encounters[encounters.length - 1].encounter.id : 0
                })
            }
        }
    }
    return out
}

function rank(type) {
    if (type.indexOf("MYTHIC") >= 0)
        return 4
    if (type.indexOf("HEROIC") >= 0)
        return 3
    if (type === "LFR")
        return 1
    return 2
}

// Instances with a boss killed since `since`: raids first, the most recently visited instance
// on top, its difficulties from Mythic down.
function lockouts(entries, since) {
    var list = []
    var latest = {}
    entries = entries || []
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i]
        var kills = e.kills.filter(function (k) { return k.t >= since })
                           .sort(function (a, b) { return a.t - b.t })
        if (kills.length === 0)
            continue
        var group = e.kind + ":" + e.instanceId
        var last = kills[kills.length - 1].t
        latest[group] = Math.max(latest[group] || 0, last)
        // The final boss can't be reached without clearing the rest, so killing it means the
        // whole instance is done even when the API doesn't track the other bosses.
        var cleared = !!e.finalBoss && kills.some(function (k) { return k.id === e.finalBoss })
        list.push(Object.assign({}, e, {
            kills: kills, killed: cleared ? Math.max(kills.length, e.total) : kills.length,
            cleared: cleared || (e.total > 0 && kills.length >= e.total), group: group
        }))
    }
    list.sort(function (a, b) {
        if (a.kind !== b.kind)
            return a.kind === "raid" ? -1 : 1
        if (a.group !== b.group)
            return (latest[b.group] - latest[a.group]) || (a.group < b.group ? -1 : 1)
        return rank(b.difficultyType) - rank(a.difficultyType)
    })
    return list
}

function formatCountdown(ms) {
    var m = Math.max(0, Math.floor(ms / 60000))
    var d = Math.floor(m / 1440)
    var h = Math.floor((m % 1440) / 60)
    m = m % 60
    if (d > 0)
        return d + "d " + h + "h"
    if (h > 0)
        return h + "h " + m + "m"
    return m + "m"
}
