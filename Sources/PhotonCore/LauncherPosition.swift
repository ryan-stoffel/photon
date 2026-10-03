import Foundation

/// Visible area of a display in AppKit coordinates (origin bottom-left).
public struct ScreenVisibleFrame: Equatable, Sendable {
  public var minX: Double
  public var minY: Double
  public var width: Double
  public var height: Double

  public init(minX: Double, minY: Double, width: Double, height: Double) {
    self.minX = minX
    self.minY = minY
    self.width = width
    self.height = height
  }

  public var midX: Double {
    minX + width / 2
  }

  public var maxY: Double {
    minY + height
  }
}

public struct PanelSize: Equatable, Sendable {
  public var width: Double
  public var height: Double

  public init(width: Double, height: Double) {
    self.width = width
    self.height = height
  }
}

public struct PanelOrigin: Equatable, Sendable {
  public var x: Double
  public var y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
}

/// User-customized launcher placement, measured from the bottom-left of the visible frame so it
/// carries across displays. The top edge is stored because the panel height changes with its content.
/// The field names changed from `originY`/`originX`, so positions saved by older builds fall back to the default.
public struct LauncherStoredPosition: Equatable, Codable, Sendable {
  /// Top edge above `visible.minY`.
  public var top: Double
  public var isHorizontallyCentered: Bool
  /// Left edge right of `visible.minX`. Ignored when centered horizontally.
  public var left: Double

  public init(top: Double, isHorizontallyCentered: Bool, left: Double) {
    self.top = top
    self.isHorizontallyCentered = isHorizontallyCentered
    self.left = left
  }
}

/// Default placement and snap geometry for the launcher panel.
public enum LauncherPosition {
  /// Spotlight-like default: centred horizontally, top edge ~74% up the visible frame,
  /// but high enough that an expanded panel still fits above the bottom.
  public static func defaultOrigin(panelSize: PanelSize, visible: ScreenVisibleFrame) -> PanelOrigin {
    let top = min(
      max(visible.minY + visible.height * 0.74, visible.minY + LauncherLayout.expandedHeight),
      visible.maxY - 8
    )
    return PanelOrigin(
      x: visible.midX - panelSize.width / 2,
      y: top - panelSize.height
    )
  }

  public static func origin(
    panelSize: PanelSize,
    visible: ScreenVisibleFrame,
    stored: LauncherStoredPosition?
  ) -> PanelOrigin {
    guard let stored else {
      return defaultOrigin(panelSize: panelSize, visible: visible)
    }
    let x = stored.isHorizontallyCentered
      ? visible.midX - panelSize.width / 2
      : visible.minX + stored.left
    let origin = PanelOrigin(x: x, y: visible.minY + stored.top - panelSize.height)
    return clampedOrigin(origin, panelSize: panelSize, visible: visible)
  }

  public static func clampedOrigin(
    _ origin: PanelOrigin,
    panelSize: PanelSize,
    visible: ScreenVisibleFrame
  ) -> PanelOrigin {
    let minX = visible.minX
    let maxX = visible.minX + visible.width - panelSize.width
    let minY = visible.minY
    let maxY = visible.maxY - panelSize.height
    return PanelOrigin(
      x: min(max(origin.x, minX), maxX),
      y: min(max(origin.y, minY), maxY)
    )
  }

  /// Horizontal positions of the two snap guides in screen coordinates.
  /// Guides sit at the left and right edges of a horizontally centered panel.
  public static func snapGuideXPositions(
    visible: ScreenVisibleFrame,
    panelWidth: Double
  ) -> (left: Double, right: Double) {
    let centeredOriginX = visible.midX - panelWidth / 2
    return (centeredOriginX, centeredOriginX + panelWidth)
  }

  /// Panel midpoints inside this span snap to center. It matches the guide span (the centered
  /// panel width) only on screens at least three panel widths wide. Otherwise it reaches a quarter
  /// of the free width to each side of center, so the panel can still sit off-center on a laptop.
  public static func snapCorridor(
    visible: ScreenVisibleFrame,
    panelWidth: Double
  ) -> (left: Double, right: Double) {
    let half = min(panelWidth / 2, max(0, (visible.width - panelWidth) / 4))
    return (visible.midX - half, visible.midX + half)
  }

  /// Resolves horizontal placement after a drag ends.
  public static func resolveHorizontalSnap(
    panelMidX: Double,
    panelWidth: Double,
    visible: ScreenVisibleFrame
  ) -> (originX: Double, isHorizontallyCentered: Bool) {
    let corridor = snapCorridor(visible: visible, panelWidth: panelWidth)
    if panelMidX >= corridor.left, panelMidX <= corridor.right {
      return (visible.midX - panelWidth / 2, true)
    }
    return (panelMidX - panelWidth / 2, false)
  }

  /// Live drag origin from screen-space mouse movement. AppKit and `NSEvent.mouseLocation`
  /// share a bottom-left origin, so the deltas apply directly (no Y flip).
  public static func originByMouseDelta(
    initialOrigin: PanelOrigin,
    startMouse: PanelOrigin,
    currentMouse: PanelOrigin
  ) -> PanelOrigin {
    PanelOrigin(
      x: initialOrigin.x + (currentMouse.x - startMouse.x),
      y: initialOrigin.y + (currentMouse.y - startMouse.y)
    )
  }

  /// Follows the pointer on Y; snaps X to screen center while the panel midpoint sits in the
  /// snap corridor. Clamps first, so the live preview matches what release stores.
  public static func liveDragOrigin(
    initialOrigin: PanelOrigin,
    startMouse: PanelOrigin,
    currentMouse: PanelOrigin,
    panelWidth: Double,
    visible: ScreenVisibleFrame
  ) -> PanelOrigin {
    let raw = clampedOrigin(
      originByMouseDelta(initialOrigin: initialOrigin, startMouse: startMouse, currentMouse: currentMouse),
      panelSize: PanelSize(width: panelWidth, height: 0),
      visible: visible
    )
    let horizontal = resolveHorizontalSnap(
      panelMidX: raw.x + panelWidth / 2,
      panelWidth: panelWidth,
      visible: visible
    )
    return PanelOrigin(x: horizontal.originX, y: raw.y)
  }

  public static func storedPosition(
    origin: PanelOrigin,
    panelSize: PanelSize,
    visible: ScreenVisibleFrame
  ) -> LauncherStoredPosition {
    let midX = origin.x + panelSize.width / 2
    let horizontal = resolveHorizontalSnap(panelMidX: midX, panelWidth: panelSize.width, visible: visible)
    return LauncherStoredPosition(
      top: origin.y + panelSize.height - visible.minY,
      isHorizontallyCentered: horizontal.isHorizontallyCentered,
      left: horizontal.originX - visible.minX
    )
  }
}
