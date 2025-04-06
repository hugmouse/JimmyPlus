//
//  ContentView.swift
//  jimmy
//
//  Created by Jonathan Foucher on 16/02/2022.
//

import Combine
import SwiftUI

struct ContentView: View {

  @EnvironmentObject var bookmarks: Bookmarks
  @EnvironmentObject var actions: Actions
  @EnvironmentObject var globalHistory: History
  @StateObject var tabStateObject: Tab = Tab(url: URL(string: "gemini://about")!)
  @State var showPopover = false
  @State private var old = 0
  @State private var rotation = 0.0
  @State var showHistorySearch = false
  @State var urlsearch = ""
  @State var typing = false
  @GestureState var isDetectingLongPress = false

  let timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()

  var body: some View {
    GeometryReader { geometry in
      VStack {
        if tabStateObject.url.host == "certs" {
          IgnoredCertificatesView()
        } else {
          TabContentWrapperView(
            tab: tabStateObject,
            close: {
              DispatchQueue.main.async {
                showHistorySearch = false
              }
            })
        }
      }
      .onReceive(Just(actions.reload)) { val in
        //tab.load()
        if old != val {
          old = val
          DispatchQueue.main.async {
            tabStateObject.load()
          }
        }

      }
      .navigationTitle(
        tabStateObject.emojis.emoji(tabStateObject.url.host ?? "") + " "
          + (tabStateObject.url.host?.idnaDecoded ?? "")
      )

      .frame(maxWidth: .infinity, minHeight: 200)
      .toolbar {
        urlToolBarContent(geometry)
      }

      .onOpenURL(perform: { url in
        tabStateObject.url = url
        DispatchQueue.main.async {
          self.showHistorySearch = false
        }
        tabStateObject.load()
      })
      .onDisappear(perform: {
        print("disappearing", getCurrentWindows().count)
        DispatchQueue.main.async {
          let w = getCurrentWindows()
          if w.count == 1
            && (w.first!.tabGroup == nil || w.first!.tabGroup?.isTabBarVisible == false)
          {
            w.first!.toggleTabBar(self)
          }
        }
      })
      .onAppear(perform: {
        DispatchQueue.main.async {

          guard
            let firstWindow = NSApp.windows.first(where: { win in
              return
                (NSStringFromClass(type(of: win)) == "SwiftUI.AppKitWindow"
                || NSStringFromClass(type(of: win)) == "SwiftUI.SwiftUIWindow")
            })
          else { return }

          //firstWindow.makeKeyAndOrderFront(nil)
          var group = firstWindow
          if let g = firstWindow.tabGroup?.selectedWindow {
            group = g
          }
          let w = getCurrentWindows()
          print(w.count)

          if w.count == 1
            && (w.first!.tabGroup == nil || w.first!.tabGroup?.isTabBarVisible == false)
          {
            w.first!.toggleTabBar(self)
          } else if w.count > 1 && NSApp.keyWindow?.tabGroup?.isTabBarVisible == true {
            NSApp.keyWindow?.toggleTabBar(self)
          }

          let lastWindow = NSApp.windows.first(where: { win in
            return win.tabbedWindows?.count == nil
              && (NSStringFromClass(type(of: win)) == "SwiftUI.AppKitWindow"
                || NSStringFromClass(type(of: win)) == "SwiftUI.SwiftUIWindow")
              && win != group
          })

          NSApp.windows.forEach({ win in
            let className = NSStringFromClass(type(of: win))
            if win != firstWindow
              && (className == "SwiftUI.SwiftUIWindow" || className == "SwiftUI.AppKitWindow")
              && win.tabbedWindows?.count == nil
            {
              group.addTabbedWindow(win, ordered: .above)
            }
          })

          if let last = lastWindow {
            last.makeKeyAndOrderFront(nil)
          }
          tabStateObject.load()
        }
      })
    }
  }

  @ToolbarContentBuilder
  func urlToolBarContent(_ geometry: GeometryProxy) -> some ToolbarContent {
    let url = Binding<String>(
      get: { tabStateObject.url.absoluteString.decodedURLString! },
      set: { s in
        urlsearch = s
        tabStateObject.url = URL(unicodeString: s) ?? URL(string: "gemini://about")!
      }
    )

    ToolbarItem(placement: .navigation) {
      HStack {
        // Back Button
        Button(action: back) {
          Image(systemName: "arrow.backward")
            .imageScale(.large)
            .frame(width: 22, height: 22)
        }
        .disabled(!tabStateObject.tabSpecificHistory.canGoBack)
        .buttonStyle(.borderless)

        // Forward Button
        Button(action: forward) {
          Image(systemName: "arrow.forward")
            .imageScale(.large)
            .frame(width: 22, height: 22)
        }
        .disabled(!tabStateObject.tabSpecificHistory.canGoForward)
        .buttonStyle(.borderless)

        // Reload/Stop Button
        Button(action: go) {
          Image(systemName: tabStateObject.loading ? "xmark" : "arrow.clockwise")
            .imageScale(.medium)
            .frame(width: 32, height: 22)
        }
        .disabled(url.wrappedValue.isEmpty)
        .buttonStyle(.borderless)
      }
    }

    ToolbarItemGroup(placement: .principal) {

      ZStack(alignment: .trailing) {

        TextField(
          "gemini://", text: url,
          onEditingChanged: { focused in
            typing = focused
          }
        )
        .onSubmit {
          go()
        }
        .onChange(
          of: urlsearch,
          perform: { u in
            showHistorySearch =
              globalHistory.items.contains(where: { hist in
                hist.url.absoluteString.replacingOccurrences(of: "gemini://", with: "").contains(
                  u.replacingOccurrences(of: "gemini://", with: ""))
              }) && typing && u.starts(with: "gemini://")
            if !u.starts(with: "gemini://") {
              urlsearch = "gemini://" + u
            }
          }
        )
        .popover(
          isPresented: $showHistorySearch, attachmentAnchor: .point(.bottom), arrowEdge: .bottom,
          content: {
            HistoryView(close: {
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.showHistorySearch = false
              }
            })
            .environmentObject(tabStateObject)
          }
        )

        .frame(minWidth: 300, idealWidth: geometry.size.width / 2, maxWidth: .infinity)

        .background(Color("urlbackground"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .textFieldStyle(.roundedBorder)
        if tabStateObject.loading {
          Image(systemName: "arrow.triangle.2.circlepath")
            .foregroundColor(Color.gray)
            .rotationEffect(Angle(degrees: rotation))
            .onReceive(timer) { time in
              $rotation.wrappedValue += 1.0
            }
            .padding(.trailing, 8)

        }

        Button(action: toggleValidateCert) {
          Image(systemName: (tabStateObject.ignoredCertValidation ? "lock.open" : "lock"))
            .foregroundColor((tabStateObject.ignoredCertValidation ? Color.red : Color.green))
            .imageScale(.large).padding(.leading, 0)
            .opacity(0.7)
        }.disabled(!tabStateObject.ignoredCertValidation)
          .padding(.trailing, tabStateObject.loading ? 20 : 0)
      }
      Spacer(minLength: 50)
    }

    ToolbarItemGroup(
      placement: .primaryAction,
      content: {
        Button(action: bookmark) {
          Image(systemName: (bookmarked ? "star.fill" : "star")).imageScale(.large)
        }
        .buttonStyle(.borderless)
        .disabled(url.wrappedValue.isEmpty)
        Button(action: showBookmarks) {
          Image(systemName: "bookmark").imageScale(.large)
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $showPopover, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) {
          BookmarksView(tab: tabStateObject, close: { showPopover = false }).frame(
            maxWidth: .infinity)
        }
      })

  }

  func showBookmarks() {
    self.showPopover = !self.showPopover
  }

  var bookmarked: Bool {
    return bookmarks.items.contains(where: { $0.url == tabStateObject.url })
  }

  func bookmark() {
    if bookmarked {
      bookmarks.items = bookmarks.items.filter({ $0.url != tabStateObject.url })
    } else {
      bookmarks.items.append(Bookmark(url: tabStateObject.url))
    }

    bookmarks.save()
  }

  func go() {

    if tabStateObject.loading {
      tabStateObject.stop()
    } else {
      if !tabStateObject.url.absoluteString.starts(with: "gemini://") {
        let u = tabStateObject.url.absoluteString
        tabStateObject.url = URL(string: "gemini://" + u) ?? URL(string: "gemini://about/")!
      }

      tabStateObject.load()
    }
    DispatchQueue.main.async {
      showHistorySearch = false
    }
  }

  func back() {
    tabStateObject.back()
    DispatchQueue.main.async {
      showHistorySearch = false
    }
  }

  func forward() {
    tabStateObject.forward()
    DispatchQueue.main.async {
      showHistorySearch = false
    }
  }

  func getCurrentWindows() -> [NSWindow] {
    return NSApp.windows.filter { NSStringFromClass(type(of: $0)) == "SwiftUI.SwiftUIWindow" }
  }

  func toggleValidateCert() {
    print(
      "ignored cert validation",
      tabStateObject.certs.items.map { $0.id }.contains(tabStateObject.url.host ?? ""))
    if tabStateObject.certs.items.map({ $0.id }).contains(tabStateObject.url.host ?? "") {
      tabStateObject.certs.items.removeAll(where: { $0.id == tabStateObject.url.host })
      tabStateObject.load()
    } else {
      tabStateObject.certs.items.append(Cert(id: tabStateObject.url.host ?? ""))
    }
  }
}
