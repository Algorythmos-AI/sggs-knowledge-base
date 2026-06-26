import Foundation

/// Curated seeker-word lexicon, ported verbatim from `webapp/serve.py:SEEKER_LEXICON`.
/// Maps a casual whole-query string to either a theme concept or canonical translit terms.
public enum LexEntry: Sendable, Equatable {
    case theme(String)
    case translit([String])
}

public enum SeekerLexicon {
    public static let table: [String: LexEntry] = [
        "ego": .theme("haumai"), "truth": .theme("sach"), "liberation": .theme("mukti"),
        "moksha": .theme("mukti"), "salvation": .theme("mukti"), "love": .theme("prem_pyar"),
        "mercy": .translit(["daiaa", "kirapaa"]), "compassion": .translit(["daiaa"]),
        "grace": .translit(["nadar", "kirapaa"]), "peace": .translit(["saant", "sukh"]),
        "death": .translit(["kaal", "maran"]), "bliss": .translit(["anand"]),
        "fear": .translit(["bhau"]), "fearless": .translit(["nirabhau"]),
        "soul": .translit(["aatam", "jeeo"]), "light": .translit(["jot"]),
        "mind": .translit(["man"]), "word": .translit(["sabad"]),
        "karma": .translit(["karam"]), "bhakti": .translit(["bhagat"]),
        "dhyan": .translit(["dhiaan"]), "gyan": .translit(["giaan"]),
        "darshan": .translit(["darasan"]), "darshana": .translit(["darasan"]),
        "sewa": .translit(["sevaa"]), "seva": .translit(["sevaa"]), "sewaa": .translit(["sevaa"]),
        "gaya": .translit(["gaio", "gaiaa"]), "gaiya": .translit(["gaio", "gaiaa"]),
        "gayi": .translit(["gaee", "gaiaa"]), "gayee": .translit(["gaee", "gaiaa"]),
        "hua": .translit(["hoaa", "hoiaa"]), "hoya": .translit(["hoaa", "hoiaa"]),
        "raha": .translit(["rahio", "rahiaa"]), "rahaa": .translit(["rahio", "rahiaa"]),
        "kaha": .translit(["kahio", "kahiaa"]), "kahaa": .translit(["kahio", "kahiaa"]),
        "kiya": .translit(["keeaa", "keeo"]), "kia": .translit(["keeaa", "keeo"]),
        "kiaa": .translit(["keeaa", "keeo"]), "keeya": .translit(["keeaa", "keeo"]),
        "aaya": .translit(["aaio", "aaiaa"]), "aya": .translit(["aaio", "aaiaa"]),
        "diya": .translit(["deeo", "deeaa"]), "dia": .translit(["deeo", "deeaa"]),
        "liya": .translit(["leeo", "leeaa"]), "lia": .translit(["leeo", "leeaa"]),
        "bhaya": .translit(["bhaio", "bhaiaa"]), "bhaia": .translit(["bhaio", "bhaiaa"]),
        "paya": .translit(["paaio", "paaiaa"]), "paaya": .translit(["paaio", "paaiaa"]),
        "sai": .translit(["saaee", "saaeen"]), "sain": .translit(["saaeen", "saaee"]),
        "saeen": .translit(["saaeen", "saaee"]), "saai": .translit(["saaee", "saaeen"]),
        "karoh": .translit(["karah"]), "karo": .translit(["karah", "kar"]),
        "farid": .translit(["phareed", "phareedaa"]), "krishna": .translit(["krisan"]),
        "sita": .translit(["seetaa"]), "dhru": .translit(["dhroo"]),
        "prahlad": .translit(["prahilaad", "prahalaad"]), "ravan": .translit(["raavan"]),
        "brahma": .translit(["brahamaa"]), "shiva": .translit(["siv"]), "shiv": .translit(["siv"]),
        "indra": .translit(["indr", "ind"]), "yashoda": .translit(["jasodaa", "jasudaa"]),
        "yamuna": .translit(["jamunaa"]), "waheguru": .translit(["vaahiguroo"]),
        "allah": .translit(["alah"]), "khuda": .translit(["khudaa", "khudaae"]),
        "satnam": .translit(["sat naam", "satinaam"]), "satguru": .translit(["satigur"]),
        "satnam waheguru": .translit(["vaahiguroo", "sat naam"]),
        "baba farid": .translit(["phareed", "phareedaa"]),
        "baba fareed": .translit(["phareed", "phareedaa"]),
        "maaya": .translit(["maaiaa"]), "kya": .translit(["kiaa", "kia"]),
        "ka": .translit(["kai", "kaa"]), "ke": .translit(["ke", "kai"]),
        "ki": .translit(["kee", "ki"]), "kau": .translit(["kau", "ko"]),
        "ko": .translit(["ko", "kau"]),
        "mein": .translit(["mah", "vich"]), "me": .translit(["mah", "vich"]),
        "ye": .translit(["ih", "eh"]), "main": .translit(["mai", "hau"]),
        "inka": .translit(["tin", "tinhaa"]), "jivan": .translit(["jeevan"]),
        "mua": .translit(["mooaa", "moaa"]), "keertan": .translit(["keeratan"]),
        "raidas": .translit(["ravidaas"]), "waheguruji": .translit(["vaahiguroo"]),
        "sachkhand": .translit(["sach khand"]), "kirtan sohila": .translit(["sohilaa"]),
        "onkar": .translit(["oankaar"]), "ikonkar": .translit(["oankaar"]),
        "rabb": .translit(["har", "raam"]), "rab": .translit(["har", "raam"]),
        "dard": .translit(["dukh"]), "dil": .translit(["man"]),
        "khushi": .translit(["sukh"]), "satsang": .translit(["saadhasang", "sang"]),
        "ocean": .translit(["saagar"]), "name": .translit(["naam"]),
    ]
}
