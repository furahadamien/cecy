import Foundation
import MessageUI
import Testing
@testable import cecy

@MainActor struct ContactSupportTests {
    @Test func mailLinkContainsOnlyRecipientAndGenericSubject() throws {
        let url = try #require(SupportContact.mailURL)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "mailto")
        #expect(components.path == "support@thabo.xyz")
        #expect(components.queryItems == [URLQueryItem(name: "subject", value: "Cecy support")])
        #expect(components.fragment == nil)
        #expect(SupportContact.email == components.path)
    }

    @Test func cancelledEmailDoesNotClaimSuccessOrFailure() {
        #expect(SupportContact.completionMessage(for: .cancelled, failed: false) == nil)
    }

    @Test func savedEmailIsClearlyUnsent() {
        #expect(SupportContact.completionMessage(for: .saved, failed: false) == "Draft saved in Mail. It hasn’t been sent.")
    }

    @Test func sentResultIsHandoffNotDeliveryConfirmation() {
        #expect(SupportContact.completionMessage(for: .sent, failed: false) == "Your message was handed to Mail for sending. Check Mail for delivery status.")
    }

    @Test func failuresOfferCopyFallbackWithoutRawErrors() {
        let failure = SupportContact.completionMessage(for: .failed, failed: false)
        #expect(failure?.contains("copy the address") == true)
        for result in [MFMailComposeResult.sent, .saved, .cancelled, .failed] {
            #expect(SupportContact.completionMessage(for: result, failed: true) == failure)
        }
    }

    @Test func unavailableMailHasActionableFallback() {
        #expect(SupportContact.unavailableMessage.contains("Copy the address"))
        #expect(SupportContact.unavailableMessage.contains("No email app could be opened"))
    }
}