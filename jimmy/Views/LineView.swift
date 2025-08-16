//
//  LineView.swift
//  jimmy
//
//  Created by Jonathan Foucher on 17/02/2022.
//

import SwiftUI

struct LineView: View, Hashable {
  @EnvironmentObject var certs: IgnoredCertificates
  var line: String
  var data: Data
  var type: String
  var tab: Tab
  var attrStr: NSAttributedString?
  var id: UUID

  @State var answer = ""

  init(data: Data, type: String, tab: Tab) {
    self.line = String(decoding: data, as: UTF8.self)
    self.data = data

    self.type = type
    self.id = UUID()
    self.tab = tab
  }

  init(attributed: NSAttributedString, tab: Tab) {
    self.id = UUID()
    self.tab = tab
    self.type = "text"
    self.line = ""
    self.data = Data([])
    self.attrStr = attributed
  }

  var body: some View {
    textView
  }

  @ViewBuilder
  private var textView: some View {
    if type.starts(with: "text/ignore-cert") {
      let format = NSLocalizedString(
        "Ignore certificate validation for %@%@",
        comment: "Button label to ignore certificate validation for this host")

      Button(
        action: {
          if let host = tab.url.host {
            certs.items.append(Cert(id: host))
            tab.certs.items = certs.items
            certs.save()
            tab.load()
          }
        },
        label: {
          Text(String(format: format, tab.emojis.emoji(tab.url.host ?? ""), (tab.url.host ?? "")))
        })
        .accessibilityLabel("Ignore certificate validation for \(tab.url.host ?? "this host")")
        .accessibilityHint("Tap to ignore certificate errors for this website")
    } else if type.starts(with: "text/answer") {
      // Line for an answer. The question should be above this
      HStack {
        TextField("Answer", text: $answer)
          .textFieldStyle(.roundedBorder)
          .onSubmit {
            send()
          }
          .accessibilityLabel("Answer input field")
          .accessibilityHint("Enter your answer and press return to submit")
        Button(action: send) {
          Text("Send")
        }
        .accessibilityLabel("Send answer")
        .accessibilityHint("Submit your answer to the server")
      }
    } else if type.starts(with: "image/") {
      // Line for an answer. The question should be above this
      if let img = NSImage(data: Data(self.data)) {
        Image(nsImage: img)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .layoutPriority(-1)
          .accessibilityLabel("Image from Gemtext document")
          .accessibilityAddTraits(.isImage)
      } else {
        Image(systemName: "xmark")
          .accessibilityLabel("Failed to load image")
          .accessibilityAddTraits(.isImage)
      }
    } else {
      if let a = attrStr {
        AttributedText(a)
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Gemtext content")
      }
    }
  }

  func send() {
    if let url = URL(
      string: tab.url.absoluteString + "?"
        + (answer.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))
    {
      tab.url = url
      tab.load()
    }
  }

  static func == (lhs: LineView, rhs: LineView) -> Bool {
    return lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
