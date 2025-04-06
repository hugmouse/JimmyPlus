import SwiftUI

struct IgnoredCertificatesView: View {
  @EnvironmentObject var certs: IgnoredCertificates
  @State private var selectedCerts = Set<Cert.ID>()

  @State private var showingAddDomainPopover = false
  @State private var newDomain: String = ""
  @State private var inputError: String? = nil

  var body: some View {
    VStack(alignment: .leading) {
      Text("Ignored Certificates")
        .font(.title)
        .padding(.bottom, 8)

      ZStack {
        Table(certs.items, selection: $selectedCerts) {
          TableColumn("Domain", value: \.id)
        }
        .border(Color(.separatorColor), width: 1)

        VStack(spacing: 0) {
          Spacer()
          HStack(spacing: 2) {
            // "+" Button
            Button(action: {
              showingAddDomainPopover = true
            }) {
              Image(systemName: "plus")
                .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 8.0)
            .padding(.vertical, 4.0)
            .buttonStyle(.borderless)
            .popover(isPresented: $showingAddDomainPopover, arrowEdge: .top) {
              VStack(alignment: .leading, spacing: 16) {
                Text("Add Domain")
                  .font(.headline)

                TextField("Enter domain", text: $newDomain)
                  .textFieldStyle(RoundedBorderTextFieldStyle())

                if let error = inputError {
                  Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                }

                HStack {
                  Spacer()
                  Button("Cancel") {
                    resetAddDomainState()
                  }
                  Button("Add") {
                    addDomain()
                  }
                  .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
                }
              }
              .padding()
              .frame(width: 300)
            }

            // "-" Button
            Button(action: {
              selectedCerts.forEach { certID in
                certs.remove(item: certID)
              }
            }) {
              Image(systemName: "minus")
                .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 8.0)
            .padding(.vertical, 4.0)
            .buttonStyle(.borderless)
            .disabled(selectedCerts.isEmpty)

            Spacer()
          }
          .background(.regularMaterial)
          .border(Color(.separatorColor))
        }
      }
    }
    .padding()
    .frame(minWidth: 200, maxWidth: 800, alignment: .leading)
  }

  private func addDomain() {
    let trimmedDomain = newDomain.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedDomain.isEmpty else {
      inputError = "Domain cannot be empty."
      return
    }
    certs.add(item: trimmedDomain)
    resetAddDomainState()
  }

  private func resetAddDomainState() {
    newDomain = ""
    inputError = nil
    showingAddDomainPopover = false
  }
}

#Preview {
  IgnoredCertificatesView()
    .environmentObject(IgnoredCertificates())
}
