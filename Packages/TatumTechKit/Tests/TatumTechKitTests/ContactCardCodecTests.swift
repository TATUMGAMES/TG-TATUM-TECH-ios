import Foundation
import Testing
@testable import TatumTechKit

@Suite("Contact card codecs")
struct ContactCardCodecTests {
    private func card(description: String? = "Builds games") -> ContactCard {
        ContactCard(
            cardID: "card-123",
            ownerUserID: 1,
            name: "Ada Lovelace",
            jobTitle: "Engineer",
            company: "Tatum, Games; LLC",
            description: description,
            email: "ada@example.com",
            phone: "+1 555 0100",
            alternateEmail: "ada@work.example.com",
            website: "https://ada.dev",
            linkedin: "https://linkedin.com/in/ada",
            twitter: "https://x.com/ada",
            customLink: "https://portfolio.example.com",
            calendly: "https://calendly.com/ada",
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    @Test func sha256MatchesKnownVectors() {
        #expect(SHA256Digest.hex(of: []) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(SHA256Digest.hex(of: Array("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let long = Array("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8)
        #expect(SHA256Digest.hex(of: long) == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }

    @Test func vCardRoundTripKeepsEveryField() throws {
        let encoded = try #require(ContactCardVCardCodec.encode(card(), firstName: "Ada", lastName: "Lovelace"))
        #expect(encoded.hasPrefix("BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Ada Lovelace\r\nN:Lovelace;Ada;;;\r\n"))
        #expect(encoded.contains("ORG:Tatum\\, Games\\; LLC\r\n"))
        #expect(encoded.hasSuffix("UID:card-123\r\nEND:VCARD\r\n"))

        guard case .success(let payload) = ContactCardQRCodec.parseIncoming(encoded) else {
            Issue.record("vCard did not parse")
            return
        }
        #expect(payload.cardID == "card-123")
        #expect(payload.userID == 0)
        #expect(payload.name == "Ada Lovelace")
        #expect(payload.company == "Tatum, Games; LLC")
        #expect(payload.email == "ada@example.com")
        #expect(payload.alternateEmail == "ada@work.example.com")
        #expect(payload.phone == "+1 555 0100")
        #expect(payload.website == "https://ada.dev")
        #expect(payload.linkedin == "https://linkedin.com/in/ada")
        #expect(payload.twitter == "https://x.com/ada")
        #expect(payload.customLink == "https://portfolio.example.com")
        #expect(payload.calendly == "https://calendly.com/ada")
        #expect(payload.description == "Builds games")
    }

    @Test func longNotesAreClippedAndLinesFolded() throws {
        let note = String(repeating: "é", count: 400)
        let encoded = try #require(ContactCardVCardCodec.encode(card(description: note)))
        for line in encoded.components(separatedBy: "\r\n") {
            #expect(line.utf8.count <= 75, "line too long: \(line.utf8.count)")
        }
        guard case .success(let payload) = ContactCardVCardCodec.parse(encoded) else {
            Issue.record("vCard did not parse")
            return
        }
        #expect(payload.description?.count == 280)
        #expect(payload.description?.hasSuffix("…") == true)
    }

    @Test func cardsWithoutANameAreNotEncoded() {
        var unnamed = card()
        unnamed.name = "  "
        #expect(ContactCardVCardCodec.encode(unnamed) == nil)
        #expect(ContactCardVCardCodec.encode(unnamed, firstName: "Ada")?.contains("FN:Ada\r\n") == true)
    }

    @Test func thirdPartyVCardsWithoutUIDGetAStableID() {
        let raw = "BEGIN:VCARD\nVERSION:3.0\nN:Doe;Jane;;;\nitem1.EMAIL;TYPE=INTERNET:Jane@Example.com\nTEL:555\nURL:https://twitter.com/jane\nURL:https://one.example\nURL:https://two.example\nURL:https://three.example\nEND:VCARD"
        guard case .success(let first) = ContactCardQRCodec.parseIncoming(raw),
              case .success(let second) = ContactCardQRCodec.parseIncoming(raw) else {
            Issue.record("vCard did not parse")
            return
        }
        #expect(first.name == "Jane Doe")
        #expect(first.email == "Jane@Example.com")
        #expect(first.twitter == "https://twitter.com/jane")
        #expect(first.website == "https://one.example")
        #expect(first.customLink == "https://two.example")
        #expect(first.cardID.hasPrefix("vcard:"))
        #expect(first.cardID.count == "vcard:".count + 32)
        #expect(first.cardID == second.cardID)
        let expected = "vcard:" + String(SHA256Digest.hex(of: Array("jane doe|jane@example.com|555".utf8)).prefix(32))
        #expect(first.cardID == expected)
    }

    @Test func xDomainDetectionAvoidsLookalikes() {
        #expect(ContactCardVCardCodec.isXDomain("https://x.com/ada"))
        #expect(ContactCardVCardCodec.isXDomain("x.com"))
        #expect(ContactCardVCardCodec.isXDomain("https://www.x.com?u=1"))
        #expect(!ContactCardVCardCodec.isXDomain("https://box.com/ada"))
        #expect(!ContactCardVCardCodec.isXDomain("https://x.community"))
    }

    @Test func jsonPayloadsRoundTripAndAreValidated() {
        let payload = ContactCardQRCodec.payload(from: card(), anonymousID: "anon_123456")
        let json = ContactCardQRCodec.encodeJSON(payload)
        #expect(json.contains(#""type":"tatum_tech_contact""#))
        #expect(json.contains(#""cardId":"card-123""#))
        #expect(ContactCardQRCodec.parseIncoming(json) == .success(payload))

        #expect(ContactCardQRCodec.parseIncoming(#"{"type":"tatum_tech_contact","version":2,"cardId":"c","userId":1,"name":"A"}"#) == .unsupportedVersion(2))
        #expect(ContactCardQRCodec.parseIncoming(#"{"type":"tatum_tech_contact","version":0,"cardId":"c","userId":1,"name":"A"}"#) == .invalid)
        #expect(ContactCardQRCodec.parseIncoming(#"{"type":"other","version":1,"cardId":"c","userId":1,"name":"A"}"#) == .invalid)
        #expect(ContactCardQRCodec.parseIncoming(#"{"type":"tatum_tech_contact","version":1,"cardId":"","userId":1,"name":"A"}"#) == .invalid)
        #expect(ContactCardQRCodec.parseIncoming("not a card") == .invalid)
        #expect(ContactCardQRCodec.parseIncoming("   ") == .invalid)
    }

    @Test func ownCardsAreRecognisedByStableIdentity() {
        let payload = ContactCardPayload(cardID: "card-123", userID: 1, anonymousID: "anon_1", name: "Ada")
        #expect(ContactCardQRCodec.isOwnCard(payload, anonymousID: "anon_1", localCardID: nil))
        #expect(!ContactCardQRCodec.isOwnCard(payload, anonymousID: "anon_2", localCardID: "card-123"))
        let vCard = ContactCardPayload(cardID: "card-123", userID: 0, name: "Ada")
        #expect(ContactCardQRCodec.isOwnCard(vCard, anonymousID: "anon_2", localCardID: "card-123"))
        #expect(!ContactCardQRCodec.isOwnCard(vCard, anonymousID: "anon_2", localCardID: nil))
    }

    @Test func connectionsTrimBlanksAndKeepTheFirstConnectionDate() async {
        let repository = LocalRepository(fileURL: nil)
        let payload = ContactCardPayload(cardID: "c1", userID: 0, name: "Ada", jobTitle: "  ", company: " Tatum ")
        let first = ContactCardQRCodec.connection(ownerUserID: 1, payload: payload, connectedAt: Date(timeIntervalSince1970: 100))
        #expect(first.jobTitle == nil)
        #expect(first.company == "Tatum")
        #expect(first.connectedUserID == nil)

        let created = await repository.saveOrUpdateConnection(first)
        guard case .created = created else {
            Issue.record("expected a new connection")
            return
        }
        var rescanned = ContactCardQRCodec.connection(ownerUserID: 1, payload: payload, connectedAt: Date(timeIntervalSince1970: 500))
        rescanned.name = "Ada L."
        let updated = await repository.saveOrUpdateConnection(rescanned)
        guard case .updated(let connection) = updated else {
            Issue.record("expected an update")
            return
        }
        #expect(connection.name == "Ada L.")
        #expect(connection.connectedAt == Date(timeIntervalSince1970: 100))
        #expect(await repository.connections(ownerUserID: 1).count == 1)
    }

    @Test func contactNotesListLinksWithoutDedicatedFields() {
        let payload = ContactCardQRCodec.payload(from: card(), anonymousID: "a")
        #expect(ContactCardQRCodec.contactNotes(for: payload) == "Builds games\n\nLinkedIn: https://linkedin.com/in/ada\nTwitter/X: https://x.com/ada\nLink: https://portfolio.example.com\nCalendly: https://calendly.com/ada")
        #expect(ContactCardQRCodec.contactNotes(for: ContactCardPayload(cardID: "c", userID: 0, name: "A")) == nil)
    }
}
