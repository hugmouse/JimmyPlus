//
//  History.swift
//  jimmy
//
//  Created by Jonathan Foucher on 23/02/2022.
//

import Foundation
import SwiftUI

/// History was refactored such way that it repeats browser's Web History API.
/// TODO: Add load/save and such, need to integrate that with Tabs.
class History: ObservableObject {
  @Published var items: [HistoryItem] = []
  @Published var currentIndex: Int = 0

  /// Push a new history state.
  /// - Discards all items ahead of the current index,
  /// - Appends the new item,
  /// - Sets currentIndex to the newly added item.
  func pushState(_ item: HistoryItem) {
    debugPrint("History: Pushing state", item.url)

    // Check if the new item is the same as the current one
    if let currentItem = items.last, currentItem.url == item.url {
      debugPrint("History: Duplicate state detected, skipping push")
      return
    }

    // If we're not at the end, remove everything after currentIndex
    if currentIndex < items.count - 1 {
      items.removeSubrange((currentIndex + 1)..<items.count)
    }

    items.append(item)
    // The new item becomes the current entry
    currentIndex = items.count - 1
  }

  /// Replace the current history state.
  /// Replaces the item at the current index but does not change the array length or remove forward entries.
  func replaceState(_ item: HistoryItem) {
    debugPrint("History: replaceState", item)
    guard currentIndex >= 0 && currentIndex < items.count else {
      // If there's no current item, just do a push instead
      pushState(item)
      return
    }

    // Replace the current item
    items[currentIndex] = item
  }

  /// Move back one step in the history.
  func goBack() {
    guard canGoBack else { return }
    currentIndex -= 1
  }

  /// Move forward one step in the history.
  func goForward() {
    guard canGoForward else { return }
    currentIndex += 1
  }

  /// Whether we can move back in history.
  var canGoBack: Bool {
    return currentIndex > 0
  }

  /// Whether we can move forward in history.
  var canGoForward: Bool {
    return currentIndex < (items.count - 1)
  }

  /// Returns the current item. Returns nil if out of bounds.
  var currentItem: HistoryItem? {
    guard currentIndex >= 0 && currentIndex < items.count else {
      return nil
    }
    return items[currentIndex]
  }

  /// (Optional) Remove an item anywhere in the history array.
  func remove(item: HistoryItem) {
    items.removeAll(where: { $0 == item })
    // Adjust currentIndex if needed to keep it in bounds
    currentIndex = min(currentIndex, items.count - 1)
  }

  /// (Optional) Clear the entire history.
  func clear() {
    items = []
    currentIndex = 0
  }
}
