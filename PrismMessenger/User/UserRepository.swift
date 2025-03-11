import Foundation
import SwiftData
import CryptoKit

protocol UserRepository {
    func getAllUsers() async throws -> [User]
    func getUser(byUsername username: String) async throws -> User?
    func saveUser(_ user: User) async throws
    func deleteUser(_ user: User) async throws
}

class ModelContextUserRepository: UserRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func getAllUsers() async throws -> [User] {
        let descriptor = FetchDescriptor<User>()
        return try modelContext.fetch(descriptor)
    }
    
    func getUser(byUsername username: String) async throws -> User? {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.username == username
            }
        )
        
        let users = try modelContext.fetch(descriptor)
        return users.first
    }
    
    func saveUser(_ user: User) async throws {
        modelContext.insert(user)
        try modelContext.save()
    }
    
    func deleteUser(_ user: User) async throws {
        modelContext.delete(user)
        try modelContext.save()
    }
}
