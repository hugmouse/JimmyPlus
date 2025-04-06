//
//  Tab.swift
//  jimmy
//
//  Created by Jonathan Foucher on 17/02/2022.
//

import CryptoKit
import Foundation
import Network
import SwiftUI

class Tab: ObservableObject, Hashable, Identifiable {
  var certs: IgnoredCertificates
  @Published var url: URL
  @Published var content: [LineView]
  @Published var textContent: NSAttributedString
  @Published var id: UUID
  @Published var loading: Bool = false
  @Published var status = ""
  @Published var icon = ""
  @Published var ignoredCertValidation = false
  @Published var fontSize = 16.0
  @Published var scrollPos: Double = 0.0

  var emojis = Emojis()
  @Published var tabSpecificHistory: History

  private var client: Client
  private var ranges: [Range<String.Index>]?
  private var selectedRangeIndex = 0
  private var isNavigatingHistory = false

  let homeTemplate = """
    # Welcome to JimmyPlus

    Simple gemini browser for macOS, fork of Jimmy.

    ## Get started

    Just type the URL you want to visit above, and press enter!
    Save your favorite sites as bookmarks to be able to reference them later.

    ## 🚀 A few links

    Here are some sites you can visit to start off:

    => gemini://medusae.space/
    => gemini://transjovian.org/
    => gemini://geminispace.info/
    => gemini://gemini.6px.eu/ jfourcher's capsule

    ### About gemini
    => gemini://geminiprotocol.net/docs/faq.gmi Gemini Protocol FAQ
    """

  init(url: URL) {
    self.url = url
    self.content = []
    self.id = UUID()
    self.tabSpecificHistory = History()
    self.client = Client(host: "localhost", port: 1965, validateCert: true)
    self.certs = IgnoredCertificates()
    self.textContent = NSAttributedString(string: "")

    self.tabSpecificHistory.clear()
  }

  static func == (lhs: Tab, rhs: Tab) -> Bool {
    return lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  func stop() {
    self.client.stop()
    self.loading = false
    self.status = ""
  }

  func load() {
    self.client.stop()
    selectedRangeIndex = 0
    self.ranges = []
    guard let host = self.url.host else {
      return
    }

    self.icon = emojis.emoji(host)

    if host == "about" {
      cb(error: nil, message: Data(("20 text/gemini\r\n" + homeTemplate).utf8))
      return
    }

    DispatchQueue.main.async {
      self.loading = true
      self.status =
        "Loading " + self.url.absoluteString.replacingOccurrences(of: "gemini://", with: "")
      self.ignoredCertValidation = self.certs.items.contains(where: { $0.id == self.url.host ?? "" }
      )
    }

    self.client = Client(
      host: host, port: 1965,
      validateCert: !certs.items.contains(where: { $0.id == self.url.host ?? "" }))
    self.client.start()
    self.client.dataReceivedCallback = cb(error:message:)

    self.client.send(data: (url.absoluteString + "\r\n").data(using: .utf8)!)
  }

  func back() {
    if tabSpecificHistory.canGoBack {
      isNavigatingHistory = true
      tabSpecificHistory.goBack()
      if let previousItem = tabSpecificHistory.currentItem {
        self.url = previousItem.url
        self.load()
      }
    }
  }

  func forward() {
    if tabSpecificHistory.canGoForward {
      isNavigatingHistory = true
      tabSpecificHistory.goForward()
      if let nextItem = tabSpecificHistory.currentItem {
        self.url = nextItem.url
        self.load()
      }
    }
  }

  func cb(error: NWError?, message: Data?) {
    DispatchQueue.main.async {
      self.resetUIState()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
      if let error = error {
        self.handleError(error: error, message: message)
      } else if let message = message {
        self.handleMessage(message: message)
      }
    }
  }

  private func resetUIState() {
    self.loading = false
    self.status = ""
    self.content = []
    self.textContent = NSAttributedString(string: "")
  }

  private func handleError(error: NWError, message: Data?) {
    let contentParser = ContentParser(content: Data([]), tab: self)
    let errorContent: [LineView] = {
      switch error {
      case .tls(-9808), .tls(-9813):
        return invalidCertificateErrorView(parser: contentParser)
      case .tls(-9814):
        return expiredCertificateErrorView(parser: contentParser)
      case .dns(-65554), .dns(0):
        return couldNotConnectErrorView(parser: contentParser)
      default:
        return unknownErrorView(error: error, parser: contentParser)
      }
    }()
    self.content = errorContent
  }

  private func handleMessage(message: Data) {
    let parsedMessage = ContentParser(content: message, tab: self)
    switch parsedMessage.header.code {
    case 10...19:
      self.content = createInputContent(parsedMessage: parsedMessage)
    case 20...29:
      if !isNavigatingHistory {
        tabSpecificHistory.pushState(
          HistoryItem(url: self.url, date: Date(), snippet: String(parsedMessage.firstTitle)))
      }
      isNavigatingHistory = false  // Reset the flag
      if !parsedMessage.header.contentType.starts(with: "text/")
        && !parsedMessage.header.contentType.starts(with: "image/")
      {
        return  // Let ContentParser trigger the file save dialog
      }
      self.textContent = parsedMessage.attrStr
      self.content = parsedMessage.parsed
    case 30...39:
      handleRedirect(parsedMessage: parsedMessage)
    case 51:
      self.content = pageNotFoundView(parsedMessage: parsedMessage)
    default:
      self.content = serverErrorView(parsedMessage: parsedMessage)
    }
  }

  private func invalidCertificateErrorView(parser: ContentParser) -> [LineView] {
    let ats = NSMutableAttributedString(
      string: String(localized: "Invalid certificate"),
      attributes: parser.title1Style
    )
    let format = NSLocalizedString(
      "The SSL certificate for %@%@ is invalid.", comment: "SSL certificate invalid for this host.")
    let ats2 = NSMutableAttributedString(
      string: String(format: format, self.emojis.emoji(self.url.host ?? ""), self.url.host ?? ""),
      attributes: parser.title3Style
    )
    return [
      LineView(attributed: ats, tab: self),
      LineView(attributed: ats2, tab: self),
      LineView(data: Data("".utf8), type: "text/ignore-cert", tab: self),
    ]
  }

  private func expiredCertificateErrorView(parser: ContentParser) -> [LineView] {
    let ats = NSMutableAttributedString(
      string: String(localized: "Expired certificate"),
      attributes: parser.title1Style
    )
    let format = NSLocalizedString(
      "The SSL certificate for %@%@ has expired.", comment: "SSL certificate expired for this host."
    )
    let ats2 = NSMutableAttributedString(
      string: String(format: format, self.emojis.emoji(self.url.host ?? ""), self.url.host ?? ""),
      attributes: parser.title3Style
    )
    return [
      LineView(attributed: ats, tab: self),
      LineView(attributed: ats2, tab: self),
      LineView(data: Data("".utf8), type: "text/ignore-cert", tab: self),
    ]
  }

  private func couldNotConnectErrorView(parser: ContentParser) -> [LineView] {
    let ats = NSMutableAttributedString(
      string: "Could not connect",
      attributes: parser.title1Style
    )
    let ats2 = NSMutableAttributedString(
      string: """
        This means we can't connect to the capsule. Make sure that:
        - You have an internet connection
        - Capsule is healthy
        """,
      attributes: parser.textStyle
    )
    return [
      LineView(attributed: ats, tab: self),
      LineView(attributed: ats2, tab: self),
    ]
  }

  private func unknownErrorView(error: NWError, parser: ContentParser) -> [LineView] {
    let ats = NSMutableAttributedString(
      string: String(localized: "Unknown Error"),
      attributes: parser.title1Style
    )
    let ats2 = NSMutableAttributedString(
      string: error.localizedDescription,
      attributes: parser.title1Style
    )
    debugPrint(error)
    return [
      LineView(attributed: ats, tab: self),
      LineView(attributed: ats2, tab: self),
    ]
  }

  private func createInputContent(parsedMessage: ContentParser) -> [LineView] {
    let ats = NSMutableAttributedString(
      string: parsedMessage.header.contentType,
      attributes: parsedMessage.title1Style
    )
    return [
      LineView(attributed: ats, tab: self),
      LineView(data: Data(), type: "text/answer", tab: self),
    ]
  }

  private func pageNotFoundView(parsedMessage: ContentParser) -> [LineView] {
    let format1 = NSLocalizedString(
      "%d Page Not Found", comment: "Page not found title. First argument is the error code")
    let ats = NSMutableAttributedString(
      string: String(format: format1, parsedMessage.header.code),
      attributes: parsedMessage.title1Style
    )
    let format2 = NSLocalizedString(
      "Sorry, the page %@ was not found on %@%@",
      comment:
        "Page not found subtitle. First argument is the path, second the icon, third the host name")
    let ats2 = NSMutableAttributedString(
      string: String(
        format: format2, self.url.path, self.emojis.emoji(self.url.host ?? ""), self.url.host ?? ""),
      attributes: parsedMessage.textStyle
    )
    return [
      LineView(attributed: ats, tab: self),
      LineView(attributed: ats2, tab: self),
    ]
  }

  private func serverErrorView(parsedMessage: ContentParser) -> [LineView] {
    let format1 = NSLocalizedString(
      "%d Server Error", comment: "Generic server error title. First param is the error code")
    let ats = NSMutableAttributedString(
      string: String(format: format1, parsedMessage.header.code),
      attributes: parsedMessage.title1Style
    )
    let format2 = NSLocalizedString(
      "Could not load %@", comment: "Generic server error subtitle. First param is full url")
    let ats2 = NSMutableAttributedString(
      string: String(format: format2, self.url.absoluteString),
      attributes: parsedMessage.textStyle
    )
    ats2.append(
      NSAttributedString(
        string: "\n" + parsedMessage.header.contentType, attributes: parsedMessage.title3Style))
    return [
      LineView(attributed: ats, tab: self),
      LineView(attributed: ats2, tab: self),
    ]
  }

  private func handleRedirect(parsedMessage: ContentParser) {
    if let redirect = URL(string: parsedMessage.header.contentType) {
      self.url = redirect
      self.load()
    }
  }

  func search(_ str: String) -> [Range<String.Index>] {
    let wholeRange = NSRange(self.textContent.string.startIndex..., in: self.textContent.string)
    let content = NSMutableAttributedString("")
    content.append(self.textContent)
    content.removeAttribute(.backgroundColor, range: wholeRange)

    if content.string.contains(str) {
      self.ranges = content.string.ranges(of: str, options: [])

      for range in ranges! {
        content.addAttribute(
          .backgroundColor,
          value: NSColor.systemGray.blended(withFraction: 0.5, of: NSColor.textBackgroundColor)
            ?? NSColor.gray, range: range.nsRange(in: content.string))
      }

      self.textContent = content
      return ranges!
    } else {
      self.ranges = []
    }

    self.textContent = content

    return []
  }

  func enterSearch() {
    guard let ranges = self.ranges else { return }
    if ranges.count == 0 {
      return
    }
    let content = NSMutableAttributedString("")
    content.append(self.textContent)
    for range in ranges {
      content.addAttribute(
        .backgroundColor,
        value: NSColor.systemGray.blended(withFraction: 0.5, of: NSColor.textBackgroundColor)
          ?? NSColor.gray, range: range.nsRange(in: content.string))
    }

    if selectedRangeIndex >= ranges.count {
      selectedRangeIndex = 0
    }

    let range = ranges[selectedRangeIndex]

    content.addAttribute(
      .backgroundColor, value: NSColor.green, range: range.nsRange(in: content.string))

    selectedRangeIndex += 1

    self.textContent = content
  }
}

extension RangeExpression where Bound == String.Index {
  func nsRange<S: StringProtocol>(in string: S) -> NSRange { .init(self, in: string) }
}

extension String {
  func ranges(of substring: String, options: CompareOptions = [], locale: Locale? = nil) -> [Range<
    Index
  >] {
    var ranges: [Range<Index>] = []
    while let range = range(
      of: substring, options: options,
      range: (ranges.last?.upperBound ?? self.startIndex)..<self.endIndex, locale: locale)
    {
      ranges.append(range)
    }
    return ranges
  }
}
