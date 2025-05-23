//
//  FakeClient+ProfileGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

extension FakeClient: ProfileGateway {
    func fetchProfile(byAccountId accountId: UUID) async throws -> Profile? {
        store.firstInList(Profile.self) { $0.id == accountId }
    }

    func fetchProfile(byUsername username: String) async throws -> Profile? {
        store.firstInList(Profile.self) { $0.username == username }
    }

    func updateProfile(_ request: UpdateProfileRequest) async throws
        -> ProfilePictureUploadResponse?
    {
        guard let user = userService.currentUser else {
            throw FakeClientError.authenticationRequired
        }

        guard let profile = store.firstInList(Profile.self, where: { $0.accountId == user.id })
        else {
            throw ProfileGatewayError.requestFailed(404)
        }

        if let newDisplayName = request.displayName {
            profile.displayName = newDisplayName
        }

        switch request.profilePictureAction {
        case .clear:
            profile.picture = nil
            return nil
        case .noChange:
            return nil
        case .update:
            profile.picture = nil
            return ProfilePictureUploadResponse(
                uploadUrl: "http://some-upload-url.localhost",
                pictureUrl: URL(string: "http://some-picture-url.localhost")!.appending(
                    path: "/profiles"
                )
                .absoluteString,
                expiresIn: 300
            )
        }
    }
}
