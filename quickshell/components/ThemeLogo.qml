import QtQuick
import QtQuick.Effects
import "../core" as Core
Image {
 id: logo
 // Shell-owned vector logos follow primary. Imported publisher artwork retains its pixels.
 layer.enabled: Core.Theme.selectedIdentity.startsWith("bundled:")
 layer.effect: MultiEffect { colorization: 1; colorizationColor: Core.Theme.primary }
 Glyph { anchors.fill: parent; visible: logo.status !== Image.Ready; name: "arch"; ink: Core.Theme.primary }
}
