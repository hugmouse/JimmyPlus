//
//  jimmyApp.swift
//  jimmy
//
//  Created by Jonathan Foucher on 16/02/2022.
//

import Foundation
import SwiftUI

@main
struct JimmyApp: App {
  @StateObject private var bookmarks = Bookmarks()
  @StateObject private var certificates = IgnoredCertificates()
  @StateObject private var actions = Actions()
  @StateObject private var globalHistory = History()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(bookmarks)
        .environmentObject(certificates)
        .environmentObject(actions)
        .environmentObject(globalHistory)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
    }
    .handlesExternalEvents(matching: ["*"])
    .windowStyle(.titleBar)
    .windowToolbarStyle(.unified(showsTitle: false))
    .commands {
      CommandGroup(replacing: .newItem) {
        CommandsView()
          .environmentObject(actions)
      }
    }
  }
}
