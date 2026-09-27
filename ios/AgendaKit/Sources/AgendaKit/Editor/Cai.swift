import Foundation

// Accesul la date prin „căi”, ca în js/app.js (resolvePath / getPath / setPath):
// „constructii.#<id>.dotari.asi.v”, „nereguli.@a.amenda.suma”, „acte.lfd.status”, „incarcare.aplicatie”.
// „#x” = elementul listei cu id-ul x, „@x” = elementul cu cheia x, altfel proprietatea.

private func pas(_ v: JSONValue?, _ s: Substring) -> JSONValue? {
    guard let v, !v.esteNull else { return nil }
    if s.first == "#" { return v.lista?.first { $0.obiect?["id"] == .string(String(s.dropFirst())) } }
    if s.first == "@" { return v.lista?.first { $0.obiect?["key"] == .string(String(s.dropFirst())) } }
    return v.obiect?[String(s)]
}

/// `getPath(obj, path)`
public func valoareLaCale(_ o: JSObiect, _ cale: String) -> JSONValue? {
    let segs = cale.split(separator: ".", omittingEmptySubsequences: false)
    var cur: JSONValue? = .object(o)
    for s in segs.dropLast() { cur = pas(cur, s) }
    return cur?.obiect?[String(segs.last ?? "")]
}

/// Obiectul care conține ultima cheie a căii (`resolvePath(obj, path)[0]`)
public func parinteLaCale(_ o: JSObiect, _ cale: String) -> JSObiect? {
    let segs = cale.split(separator: ".", omittingEmptySubsequences: false)
    var cur: JSONValue? = .object(o)
    for s in segs.dropLast() { cur = pas(cur, s) }
    return cur?.obiect
}

/// `setPath(obj, path, v)`: dacă un pas intermediar lipsește, nu se schimbă nimic
public func seteazaLaCale(_ o: inout JSObiect, _ cale: String, _ v: JSONValue) {
    var radacina = JSONValue.object(o)
    _ = seteaza(&radacina, cale.split(separator: ".", omittingEmptySubsequences: false)[...], v)
    if let nou = radacina.obiect { o = nou }
}

private func seteaza(_ val: inout JSONValue, _ segs: ArraySlice<Substring>, _ v: JSONValue) -> Bool {
    guard let s = segs.first else { return false }
    if segs.count == 1 {
        guard case .object(var o) = val else { return false }
        o[String(s)] = v
        val = .object(o)
        return true
    }
    let rest = segs.dropFirst()
    if s.first == "#" || s.first == "@" {
        guard case .array(var l) = val else { return false }
        let cheie = s.first == "#" ? "id" : "key"
        guard let i = l.firstIndex(where: { $0.obiect?[cheie] == .string(String(s.dropFirst())) }) else { return false }
        guard seteaza(&l[i], rest, v) else { return false }
        val = .array(l)
        return true
    }
    guard case .object(var o) = val, var copil = o[String(s)], !copil.esteNull else { return false }
    guard seteaza(&copil, rest, v) else { return false }
    o[String(s)] = copil
    val = .object(o)
    return true
}

/// Modifică pe loc obiectul la care duce calea (fiecare segment e un pas, inclusiv ultimul: „nereguli.@a” = neregula a),
/// ca `resolvePath(c, path)[0]` din web; dacă un pas lipsește, nu se schimbă nimic
public func modificaLaCale(_ o: inout JSObiect, _ cale: String, _ f: (inout JSObiect) -> Void) {
    if cale.isEmpty { f(&o); return }
    var radacina = JSONValue.object(o)
    guard modifica(&radacina, cale.split(separator: ".", omittingEmptySubsequences: false)[...], f), let nou = radacina.obiect else { return }
    o = nou
}

private func modifica(_ val: inout JSONValue, _ segs: ArraySlice<Substring>, _ f: (inout JSObiect) -> Void) -> Bool {
    guard let s = segs.first else {
        guard case .object(var x) = val else { return false }
        f(&x)
        val = .object(x)
        return true
    }
    let rest = segs.dropFirst()
    if s.first == "#" || s.first == "@" {
        guard case .array(var l) = val else { return false }
        let cheie = s.first == "#" ? "id" : "key"
        guard let i = l.firstIndex(where: { $0.obiect?[cheie] == .string(String(s.dropFirst())) }), modifica(&l[i], rest, f) else { return false }
        val = .array(l)
        return true
    }
    guard case .object(var o) = val, var copil = o[String(s)], !copil.esteNull, modifica(&copil, rest, f) else { return false }
    o[String(s)] = copil
    val = .object(o)
    return true
}

// ───────── adresele din aplicație (location.hash) ─────────

/// `encodeURIComponent`
public func encodeURIComponent(_ s: String) -> String {
    var permise = CharacterSet.alphanumerics.intersection(CharacterSet(charactersIn: Unicode.Scalar(0)...Unicode.Scalar(127)))
    permise.insert(charactersIn: "-_.!~*'()")
    return s.addingPercentEncoding(withAllowedCharacters: permise) ?? s
}

/// `decodeURIComponent` (textul rămâne neschimbat dacă nu se poate decoda)
public func decodeURIComponent(_ s: String) -> String { s.removingPercentEncoding ?? s }
