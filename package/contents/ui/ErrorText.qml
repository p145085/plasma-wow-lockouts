import QtQml

// Error codes from Api.js -> messages.
QtObject {
    function text(code) {
        switch (code) {
        case "": return ""
        case "auth": return i18n("Battle.net rejected the client ID or secret.")
        case "expired": return i18n("The Battle.net token expired, retrying.")
        case "network": return i18n("Can't reach Battle.net.")
        case "notfound": return i18n("Character not found. Check the name, realm and region. New characters, and ones that haven't logged in for a long time, only show up after a login.")
        case "forbidden": return i18n("Battle.net won't share this character's profile.")
        case "ratelimit": return i18n("Too many requests to Battle.net, try again in a minute.")
        case "format": return i18n("Write characters as Name-Realm, one per line.")
        default: return i18n("Battle.net API returned HTTP %1.", code.replace("http:", ""))
        }
    }
}
