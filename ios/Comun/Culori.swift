import SwiftUI
import UIKit

// Tokenurile de culoare din css/app.css (:root și varianta întunecată).
// Culorile se adaptează singure la tema sistemului sau la tema aleasă (preferredColorScheme).
extension Color {
    static let bg = Color(luminos: 0xeef0f5, intunecat: 0x0c111d)
    static let surface = Color(luminos: 0xffffff, intunecat: 0x151c2c)
    static let surface2 = Color(luminos: 0xf6f7fb, intunecat: 0x1b2336)
    static let line = Color(luminos: 0xe1e5ee, intunecat: 0x273149)
    static let lineStrong = Color(luminos: 0xc9cfdc, intunecat: 0x36415d)
    static let text = Color(luminos: 0x121829, intunecat: 0xeef1f8)
    static let muted = Color(luminos: 0x5b6477, intunecat: 0x9aa4ba)
    static let ink = Color(luminos: 0x16213a, intunecat: 0x0a0f1a)
    static let ink2 = Color(luminos: 0x22304f, intunecat: 0x1a2440)
    static let onInk = Color(luminos: 0xffffff, intunecat: 0xffffff)

    static let accent = Color(luminos: 0x5a3de0, intunecat: 0x8b74ff)
    static let accentSoft = Color(luminos: 0xece8fd, intunecat: 0x2a2455)
    static let accentInk = Color(luminos: 0x3b24a8, intunecat: 0xc9bdff)

    static let blue = Color(luminos: 0x1f6fe0, intunecat: 0x4d8ff0)
    static let blueSoft = Color(luminos: 0xe5effd, intunecat: 0x16294a)
    static let blueInk = Color(luminos: 0x1450a8, intunecat: 0x9cc2ff)
    static let green = Color(luminos: 0x148a4c, intunecat: 0x2fb56c)
    static let greenSoft = Color(luminos: 0xe1f4e8, intunecat: 0x133626)
    static let greenInk = Color(luminos: 0x0d6437, intunecat: 0x8fe0b2)
    static let yellow = Color(luminos: 0xe9a800, intunecat: 0xf2bd2c)
    static let yellowSoft = Color(luminos: 0xfff4d1, intunecat: 0x3a2f0e)
    static let yellowInk = Color(luminos: 0x6e4f00, intunecat: 0xffd978)
    static let red = Color(luminos: 0xd92d20, intunecat: 0xf0544a)
    static let redSoft = Color(luminos: 0xfde7e5, intunecat: 0x3d1817)
    static let redInk = Color(luminos: 0xa61b12, intunecat: 0xffaaa3)
    static let warn = Color(luminos: 0xd0620f, intunecat: 0xf08a3c)
    static let warnSoft = Color(luminos: 0xffecdb, intunecat: 0x3a2413)
    static let warnInk = Color(luminos: 0x8f3f05, intunecat: 0xffc08f)

    init(luminos: UInt32, intunecat: UInt32) {
        self.init(uiColor: UIColor { trasaturi in
            UIColor(hex: trasaturi.userInterfaceStyle == .dark ? intunecat : luminos)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1
        )
    }
}
