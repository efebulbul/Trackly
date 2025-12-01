import UIKit

// HEX → UIColor
extension UIColor {
    convenience init(hex: String) {
        var c = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if c.hasPrefix("#") { c.removeFirst() }

        var rgb: UInt64 = 0
        Scanner(string: c).scanHexInt64(&rgb)

        self.init(
            red:   CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8)  / 255.0,
            blue:  CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
