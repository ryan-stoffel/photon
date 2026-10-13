import SwiftUI

/// Keyboard scrolling for launcher lists. Rows report where they sit in the scroll view,
/// and `reveal` scrolls only when the selected row is clipped, pinning it `listInset` from the nearest edge.
/// A bare `scrollTo(id)` in a lazy stack nudges or bounces the list even when the row is visible.
///
/// Mark the scroll view with `listScrollViewport(_:)`, each row with `listScrollRow(_:tracker:)`,
/// and call `reveal(_:in:with:)` from `onChange` of the selection.
@MainActor
public final class ListScrollTracker {
  static let coordinateSpace = "photon.list.viewport"
  private var rowFrames: [AnyHashable: CGRect] = [:]
  fileprivate var viewportHeight: CGFloat = 0

  public init() {}

  /// `order` is the list's row ids, top to bottom.
  public func reveal<ID: Hashable>(_ id: ID, in order: [ID], with proxy: ScrollViewProxy) {
    // Lazy stacks only build rows near the viewport, so a row without a frame is off screen.
    // It comes in from the bottom when it sits below the visible rows.
    guard let frame = rowFrames[AnyHashable(id)] else {
      let target = order.firstIndex(of: id) ?? 0
      let visible = order.firstIndex { rowFrames[AnyHashable($0)].map(isVisible) ?? false } ?? 0
      proxy.scrollTo(id, anchor: anchor(atBottom: target > visible, rowHeight: LauncherLayout.rowHeight))
      return
    }
    let inset = LauncherLayout.listInset
    if frame.minY < inset {
      proxy.scrollTo(id, anchor: anchor(atBottom: false, rowHeight: frame.height))
    } else if frame.maxY > viewportHeight - inset {
      proxy.scrollTo(id, anchor: anchor(atBottom: true, rowHeight: frame.height))
    }
  }

  /// `scrollTo` lines up the anchor point of the row with the same point of the viewport. This
  /// picks the point that leaves `listInset` between the row and the edge, so a scrolled list
  /// shows whole rows with even padding.
  private func anchor(atBottom: Bool, rowHeight: CGFloat) -> UnitPoint {
    let travel = viewportHeight - rowHeight
    guard travel > 0 else {
      return atBottom ? .bottom : .top
    }
    let inset = LauncherLayout.listInset
    let y = atBottom ? (travel - inset) / travel : inset / travel
    return UnitPoint(x: 0.5, y: y)
  }

  private func isVisible(_ frame: CGRect) -> Bool {
    frame.maxY > 0 && frame.minY < viewportHeight
  }

  fileprivate func setFrame(_ frame: CGRect?, for id: AnyHashable) {
    rowFrames[id] = frame
  }
}

public extension View {
  /// Apply to the `ScrollView` whose rows `tracker` follows.
  func listScrollViewport(_ tracker: ListScrollTracker) -> some View {
    coordinateSpace(name: ListScrollTracker.coordinateSpace)
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tracker.viewportHeight = $0 }
  }

  /// Apply to each row, after its final frame modifiers.
  func listScrollRow(_ id: some Hashable, tracker: ListScrollTracker) -> some View {
    onGeometryChange(for: CGRect.self) {
      $0.frame(in: .named(ListScrollTracker.coordinateSpace))
    } action: {
      tracker.setFrame($0, for: AnyHashable(id))
    }
    .onDisappear {
      tracker.setFrame(nil, for: AnyHashable(id))
    }
  }
}
