// Stand-in for GhostSettings (TelegramCore) used by the CI type checks. Not part of the app.
import Foundation

enum GhostSettings {
    static var automationsEnabled: Bool = true
    static var uploadIsland: Bool = true
}
