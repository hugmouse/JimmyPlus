//
//  IgnoredCertificates.swift
//  jimmy
//
//  Created by Jonathan Foucher on 23/02/2022.
//

import Foundation

struct Cert: Identifiable {
  let id: String
}

class IgnoredCertificates: ObservableObject {
  @Published var items: [Cert]

  static var sample = IgnoredCertificates(certs: [Cert(id: "medusae.space")])

  init() {
    if let data = UserDefaults.standard.data(forKey: "ignored-certs") {
      if let decoded = try? JSONDecoder().decode([String].self, from: data) {
        items = decoded.map { Cert(id: $0) }
        return
      }
    }

    items = []
  }

  init(certs: [Cert]) {
    items = certs
  }

  func save() {
    if let encoded = try? JSONEncoder().encode(items.map { $0.id }) {
      UserDefaults.standard.set(encoded, forKey: "ignored-certs")
    }
  }

  func add(item: String) {
    self.items.append(Cert(id: item))
    self.save()
  }

  func remove(item: String) {
    self.items = self.items.filter({ $0.id != item })
    self.save()
  }
}
