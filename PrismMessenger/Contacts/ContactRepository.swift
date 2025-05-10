//
//  ContactRepository.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

@MainActor
protocol ContactRepository {
    func getContact(byUsername username: String) async throws -> Contact?
    func saveContact(_ contact: Contact) async throws
    func deleteContact(_ contact: Contact) async throws
}

@MainActor
class SwiftDataContactRepository: ContactRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getContact(byUsername username: String) async throws -> Contact? {
        let descriptor = FetchDescriptor<Contact>(
            predicate: #Predicate<Contact> { contact in
                contact.username == username
            }
        )

        let contacts = try modelContext.fetch(descriptor)
        return contacts.first
    }

    func saveContact(_ contact: Contact) async throws {
        modelContext.insert(contact)
        try modelContext.save()
    }

    func deleteContact(_ contact: Contact) async throws {
        modelContext.delete(contact)
        try modelContext.save()
    }
}
