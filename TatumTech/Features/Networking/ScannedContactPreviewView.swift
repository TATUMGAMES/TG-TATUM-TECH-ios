import Contacts
import ContactsUI
import SwiftUI
import TatumTechKit

/// A scanned card: its details, Save Contact (records the connection and opens the system
/// new-contact screen), and Cancel.
struct ScannedContactPreviewView: View {
    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router
    @State private var payload: ContactCardPayload?
    @State private var didConsume = false
    @State private var contactToAdd: NewContact?
    @State private var pendingMessage: String?
    @State private var toast: ToastMessage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let card = payload {
                    details(card)
                    Button("Save Contact") { save(card) }
                        .buttonStyle(.primary)
                        .padding(.top, Spacing.xl)
                        .accessibilityIdentifier("scannedContact.save")
                    Button("Cancel") { router.pop() }
                        .buttonStyle(.outlinedAction)
                        .accessibilityIdentifier("scannedContact.cancel")
                } else if didConsume {
                    Text("This QR code is not a valid Tatum Tech contact card")
                    Button("Cancel") { router.pop() }
                        .buttonStyle(.outlinedAction)
                        .padding(.top, Spacing.md)
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Connecting With New Friend")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $contactToAdd, onDismiss: showPendingMessage) { contact in
            NewContactSheet(contact: contact.value)
                .ignoresSafeArea()
        }
        .toast($toast)
        .onAppear {
            guard !didConsume else { return }
            payload = router.consumeScannedCard()
            didConsume = true
        }
    }

    @ViewBuilder
    private func details(_ card: ContactCardPayload) -> some View {
        Text(card.name)
            .font(.title2.bold())
        if let job = ContactCardQRCodec.blankToNil(card.jobTitle) {
            Text(job).font(.body)
        }
        if let company = ContactCardQRCodec.blankToNil(card.company) {
            Text(company).foregroundStyle(Palette.grey)
        }
        if let description = ContactCardQRCodec.blankToNil(card.description) {
            Text(description).padding(.top, Spacing.xs)
        }
        ForEach(
            [card.email, card.phone, card.alternateEmail, card.website, card.linkedin, card.twitter, card.customLink, card.calendly]
                .compactMap(ContactCardQRCodec.blankToNil),
            id: \.self
        ) { value in
            Text(value).textSelection(.enabled)
        }
    }

    private func save(_ card: ContactCardPayload) {
        let local = app.local
        Task {
            let user = await local.ensureUser()
            let ownCardID = await local.contactCard()?.cardID
            if ContactCardQRCodec.isOwnCard(card, anonymousID: user.anonymousID, localCardID: ownCardID) {
                toast = ToastMessage(text: "You cannot save your own card")
                return
            }
            let now = Date()
            let connection = ContactCardQRCodec.connection(ownerUserID: user.id, payload: card, connectedAt: now)
            switch await local.saveOrUpdateConnection(connection) {
            case .created:
                let description = "Connected with \(card.name)"
                await local.addTimelineEntry(.connectionMade, description: description, at: now)
                await local.addTimelineEntry(.qrScan, description: description, at: now)
                pendingMessage = "Saved connection with \(card.name)"
            case .updated:
                pendingMessage = "Updated connection with \(card.name)"
            }
            contactToAdd = NewContact(value: SystemContact.make(from: card))
        }
    }

    private func showPendingMessage() {
        guard let pendingMessage else { return }
        toast = ToastMessage(text: pendingMessage)
        self.pendingMessage = nil
    }
}

private struct NewContact: Identifiable {
    let id = UUID()
    let value: CNMutableContact
}

/// Builds the system contact for a scanned card. Links go in URL fields because contact notes
/// need a special entitlement.
enum SystemContact {
    static func make(from card: ContactCardPayload) -> CNMutableContact {
        let blank = ContactCardQRCodec.blankToNil
        let contact = CNMutableContact()
        let parts = card.name.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1).map(String.init)
        contact.givenName = parts.first ?? card.name
        contact.familyName = parts.count > 1 ? parts[1] : ""
        contact.jobTitle = blank(card.jobTitle) ?? ""
        contact.organizationName = blank(card.company) ?? ""
        contact.emailAddresses = [
            blank(card.email).map { CNLabeledValue(label: CNLabelWork, value: $0 as NSString) },
            blank(card.alternateEmail).map { CNLabeledValue(label: CNLabelOther, value: $0 as NSString) }
        ].compactMap { $0 }
        if let phone = blank(card.phone) {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
        }
        contact.urlAddresses = [
            blank(card.website).map { CNLabeledValue(label: CNLabelURLAddressHomePage, value: $0 as NSString) },
            blank(card.linkedin).map { CNLabeledValue(label: "LinkedIn", value: $0 as NSString) },
            blank(card.twitter).map { CNLabeledValue(label: "Twitter/X", value: $0 as NSString) },
            blank(card.customLink).map { CNLabeledValue(label: "Link", value: $0 as NSString) },
            blank(card.calendly).map { CNLabeledValue(label: "Calendly", value: $0 as NSString) }
        ].compactMap { $0 }
        return contact
    }
}

/// The system "New Contact" screen, prefilled. The user decides whether to save it.
private struct NewContactSheet: UIViewControllerRepresentable {
    let contact: CNMutableContact
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = CNContactViewController(forNewContact: contact)
        controller.contactStore = CNContactStore()
        controller.delegate = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let dismiss: () -> Void

        init(dismiss: @escaping () -> Void) {
            self.dismiss = dismiss
        }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            dismiss()
        }
    }
}
