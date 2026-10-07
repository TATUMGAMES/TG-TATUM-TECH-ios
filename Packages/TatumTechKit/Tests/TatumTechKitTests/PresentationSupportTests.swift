import Foundation
import Testing
@testable import TatumTechKit

@Suite("Presentation support: dates, contact links")
struct PresentationSupportTests {

    @Test func eventStartFormatsInItsPublishedOffset() throws {
        let posix = Locale(identifier: "en_US_POSIX")
        let utc = try #require(EventStart(iso8601: "2026-10-10T11:30:00Z"))
        #expect(utc.formatted(locale: posix) == "October 10, 2026 at 11:30 AM")
        let pacific = try #require(EventStart(iso8601: "2026-10-10T18:05:00-07:00"))
        #expect(pacific.formatted(locale: posix) == "October 10, 2026 at 6:05 PM")
    }

    @Test func partnerEmailURLPrefillsSubject() throws {
        let url = try #require(PartnerContactLinks.emailURL(to: " hello@example.com "))
        #expect(url.absoluteString == "mailto:hello@example.com?subject=Got%20Your%20Contact%20Info%20From%20Tatum%20Games.%20I%20Have%20Some%20Questions")
        #expect(PartnerContactLinks.emailURL(to: "  ") == nil)
    }

    @Test func partnerPhoneURLKeepsDialableCharacters() {
        #expect(PartnerContactLinks.phoneURL(for: "+1 (310) 555-0100")?.absoluteString == "tel:+13105550100")
        #expect(PartnerContactLinks.phoneURL(for: "ext.") == nil)
    }

    @Test func googleFailureCopy() {
        #expect(GoogleSignInFailure.cancelled.copy == nil)
        #expect(GoogleSignInFailure.network.copy == .network)
        #expect(GoogleSignInFailure.unavailable.copy == .unavailable)
        #expect(GoogleSignInFailure.failed("x").copy == .failed)
    }
}
