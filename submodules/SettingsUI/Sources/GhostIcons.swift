import Foundation
import UIKit

private var ghostIconCache: [String: UIImage] = [:]

/// An iOS Settings style icon: a white SF Symbol on a coloured rounded square.
func ghostSettingsIcon(_ symbol: String, _ color: UIColor) -> UIImage? {
    let key = "\(symbol)|\(color.description)"
    if let cached = ghostIconCache[key] {
        return cached
    }
    let side: CGFloat = 29.0
    let configuration = UIImage.SymbolConfiguration(pointSize: 15.0, weight: .semibold)
    guard let glyph = (UIImage(systemName: symbol, withConfiguration: configuration) ?? UIImage(systemName: "circle.fill", withConfiguration: configuration))?.withTintColor(.white, renderingMode: .alwaysOriginal) else {
        return nil
    }
    let format = UIGraphicsImageRendererFormat()
    format.scale = UIScreen.main.scale
    let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 7.0)
        // A soft top-to-bottom gradient makes the squares look like the system ones.
        if let context = UIGraphicsGetCurrentContext() {
            context.saveGState()
            path.addClip()
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            let light: UIColor
            if color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
                light = UIColor(hue: hue, saturation: max(0, saturation - 0.08), brightness: min(1, brightness + 0.12), alpha: alpha)
            } else {
                light = color
            }
            let colors = [light.cgColor, color.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
                context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: side), options: [])
            } else {
                color.setFill()
                path.fill()
            }
            context.restoreGState()
        }
        let size = glyph.size
        let scale = min(1.0, 19.0 / max(size.width, size.height))
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        glyph.draw(in: CGRect(x: (side - drawSize.width) / 2.0, y: (side - drawSize.height) / 2.0, width: drawSize.width, height: drawSize.height))
    }
    ghostIconCache[key] = image
    return image
}
