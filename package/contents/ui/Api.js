.pragma library
.import "Lockouts.js" as Lockouts

// Battle.net Game Data and Profile APIs with a client-credentials token: each user registers
// their own free API client at develop.battle.net. No player login is involved; character
// profiles are public.
var TOKEN_URL = "https://oauth.battle.net/token"
var LOCALES = ["en_US", "en_GB", "de_DE", "es_ES", "es_MX", "fr_FR", "it_IT", "pt_BR", "ru_RU", "ko_KR", "zh_TW"]
// Kills older than this can't be part of the current week, so they aren't cached.
var KEEP_MS = 8 * 24 * 3600000

// Qt locale name ("sv_SE") -> a locale the API serves names in.
function apiLocale(name) {
    if (LOCALES.indexOf(name) >= 0)
        return name
    var lang = String(name).split("_")[0] + "_"
    for (var i = 0; i < LOCALES.length; i++)
        if (LOCALES[i].indexOf(lang) === 0)
            return LOCALES[i]
    return "en_US"
}

var B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

// Client IDs and secrets are ASCII.
function base64(s) {
    var out = ""
    for (var i = 0; i < s.length; i += 3) {
        var a = s.charCodeAt(i) & 0xff
        var b = i + 1 < s.length ? s.charCodeAt(i + 1) & 0xff : NaN
        var c = i + 2 < s.length ? s.charCodeAt(i + 2) & 0xff : NaN
        var n = (a << 16) | ((b || 0) << 8) | (c || 0)
        out += B64.charAt(n >> 18) + B64.charAt((n >> 12) & 63)
             + (isNaN(b) ? "=" : B64.charAt((n >> 6) & 63))
             + (isNaN(c) ? "=" : B64.charAt(n & 63))
    }
    return out
}

function request(method, url, headers, body, cb) {
    var xhr = new XMLHttpRequest()
    xhr.open(method, url)
    for (var h in headers)
        xhr.setRequestHeader(h, headers[h])
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return
        var data = null
        try {
            data = JSON.parse(xhr.responseText)
        } catch (e) {
        }
        cb(xhr.status, data)
    }
    xhr.send(body || null)
}

// HTTP status -> error code; ErrorText.qml turns codes into messages.
function errorCode(status) {
    switch (status) {
    case 0: return "network"
    case 401: return "expired"
    case 403: return "forbidden"
    case 404: return "notfound"
    case 429: return "ratelimit"
    default: return "http:" + status
    }
}

function get(cfg, token, path, namespace, cb) {
    var url = "https://" + cfg.region + ".api.blizzard.com" + path
            + "?namespace=" + namespace + "-" + cfg.region
            + (namespace === "profile" ? "&locale=" + cfg.locale : "")
    request("GET", url, { "Authorization": "Bearer " + token }, null, cb)
}

// Reuses state.token until shortly before it expires (tokens last 24 hours).
function withToken(state, cfg, cb) {
    var creds = cfg.clientId + ":" + cfg.clientSecret
    if (state.token && state.creds === creds && Date.now() < state.tokenExpires) {
        cb("")
        return
    }
    request("POST", TOKEN_URL, {
        "Authorization": "Basic " + base64(creds),
        "Content-Type": "application/x-www-form-urlencoded"
    }, "grant_type=client_credentials", function (status, data) {
        if (status === 200 && data && data.access_token) {
            state.token = data.access_token
            state.creds = creds
            state.tokenExpires = Date.now() + ((data.expires_in || 3600) - 300) * 1000
            cb("")
        } else {
            state.token = ""
            cb(status === 400 || status === 401 ? "auth" : errorCode(status))
        }
    })
}

// The region's realm index, so "Argent Dawn", "argent-dawn" and localized names all resolve.
// Without a locale the API returns every translation of each name.
function withRealms(state, cfg, cb) {
    if (state.realmRegion === cfg.region) {
        cb()
        return
    }
    get(cfg, state.token, "/data/wow/realm/index", "dynamic", function (status, data) {
        if (status === 200 && data && data.realms) {
            state.realmRegion = cfg.region
            state.realms = data.realms.map(function (r) {
                var names = typeof r.name === "string" ? [r.name] : Object.keys(r.name || {}).map(function (k) { return r.name[k] })
                return { slug: r.slug, names: names }
            })
        }
        cb()
    })
}

// Profile summary plus this week's raid (and Mythic dungeon) kills for one character.
function fetchCharacter(state, cfg, c, cb) {
    var slug = Lockouts.resolveRealm(state.realms || [], c.realm)
    var base = "/profile/wow/character/" + encodeURIComponent(slug) + "/" + encodeURIComponent(c.name.toLowerCase())
    var cutoff = Date.now() - KEEP_MS
    var result = { error: "", summary: null, entries: [] }
    var pending = cfg.dungeons ? 3 : 2
    function done() {
        if (--pending === 0)
            cb(result)
    }
    get(cfg, state.token, base, "profile", function (status, d) {
        if (status === 200 && d) {
            result.summary = {
                name: d.name,
                realm: d.realm ? d.realm.name : c.realm,
                level: d.level || 0,
                className: d.character_class ? d.character_class.name : "",
                classId: d.character_class ? d.character_class.id : 0,
                lastLogin: d.last_login_timestamp || 0
            }
        } else {
            result.error = errorCode(status)
        }
        done()
    })
    function encounters(kind, path) {
        get(cfg, state.token, base + path, "profile", function (status, d) {
            // A character with no kills at all can get a 404 here.
            if (status === 200)
                result.entries = result.entries.concat(Lockouts.extract(d, kind, cutoff))
            else if (status !== 404 && result.error === "")
                result.error = errorCode(status)
            done()
        })
    }
    encounters("raid", "/encounters/raids")
    if (cfg.dungeons)
        encounters("dungeon", "/encounters/dungeons")
}

// Token -> realm index -> every character in parallel. `state` caches the token and realm
// index between calls. cb(error, results by character key); a token that stopped working
// clears the cache and reports "expired" so the caller can retry once.
function fetchAll(state, cfg, characters, cb) {
    withToken(state, cfg, function (err) {
        if (err) {
            cb(err, {})
            return
        }
        withRealms(state, cfg, function () {
            var chars = characters.filter(function (c) { return c.valid })
            var results = {}
            var pending = chars.length
            var expired = false
            if (pending === 0) {
                cb("", results)
                return
            }
            chars.forEach(function (c) {
                fetchCharacter(state, cfg, c, function (r) {
                    if (r.error === "expired") {
                        state.token = ""
                        expired = true
                    }
                    results[c.key] = r
                    if (--pending === 0)
                        cb(expired ? "expired" : "", results)
                })
            })
        })
    })
}
