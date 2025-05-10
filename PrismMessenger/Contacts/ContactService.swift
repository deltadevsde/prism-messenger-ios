//
//  ContactService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

class ContactService: ObservableObject {
    private let contactRepository: ContactRepository
    private let userGateway: UserGateway

    init(contactRepository: ContactRepository, userGateway: UserGateway) {
        self.contactRepository = contactRepository
        self.userGateway = userGateway
    }

    func fetchContact(byUsername username: String) async throws -> Contact? {
        // First check if there is a local entry for the contact
        if let localContact = try await contactRepository.getContact(byUsername: username) {
            return localContact
        }

        // If no local entry exists, fetch from remote
        do {
            // If username is unknown in backend, return nil
            guard let accountId = try await userGateway.fetchAccountId(for: username) else {
                return nil
            }

            // If backend gave us the user's ID, create and save a new contact
            let contact = Contact(
                accountId: accountId,
                username: username
            )

            try await contactRepository.saveContact(contact)
            return contact
        } catch {
            // If remote fetch fails, return nil
            return nil
        }
    }

    func deleteContact(_ contact: Contact) async throws {
        try await contactRepository.deleteContact(contact)
    }
}
