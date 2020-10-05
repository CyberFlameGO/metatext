// Copyright © 2020 Metabolist. All rights reserved.

import Combine
import Foundation
import Mastodon
import ServiceLayer

final public class ProfileViewModel {
    @Published public private(set) var accountViewModel: AccountViewModel?
    @Published public var collection = ProfileCollection.statuses
    @Published public var alertItem: AlertItem?

    private let profileService: ProfileService
    private let collectionViewModel: CurrentValueSubject<ListViewModel, Never>
    private var cancellables = Set<AnyCancellable>()

    init(profileService: ProfileService) {
        self.profileService = profileService

        collectionViewModel = CurrentValueSubject(
            ListViewModel(collectionService: profileService.statusListService(profileCollection: .statuses)))

        profileService.accountServicePublisher
            .map(AccountViewModel.init(accountService:))
            .assignErrorsToAlertItem(to: \.alertItem, on: self)
            .assign(to: &$accountViewModel)

        $collection.dropFirst()
            .map(profileService.statusListService(profileCollection:))
            .map(ListViewModel.init(collectionService:))
            .sink { [weak self] in
                guard let self = self else { return }

                self.collectionViewModel.send($0)
                $0.$alertItem.assign(to: &self.$alertItem)
            }
            .store(in: &cancellables)
    }
}

extension ProfileViewModel: CollectionViewModel {
    public var sections: AnyPublisher<[[CollectionItemIdentifier]], Never> {
        collectionViewModel.flatMap(\.sections).eraseToAnyPublisher()
    }

    public var title: AnyPublisher<String?, Never> {
        $accountViewModel.map { $0?.accountName }.eraseToAnyPublisher()
    }

    public var alertItems: AnyPublisher<AlertItem, Never> {
        collectionViewModel.flatMap(\.alertItems).eraseToAnyPublisher()
    }

    public var loading: AnyPublisher<Bool, Never> {
        collectionViewModel.flatMap(\.loading).eraseToAnyPublisher()
    }

    public var navigationEvents: AnyPublisher<NavigationEvent, Never> {
        $accountViewModel.compactMap { $0 }
            .flatMap(\.events)
            .flatMap { $0 }
            .map(NavigationEvent.init)
            .compactMap { $0 }
            .assignErrorsToAlertItem(to: \.alertItem, on: self)
            .merge(with: collectionViewModel.flatMap(\.navigationEvents))
            .eraseToAnyPublisher()
    }

    public var nextPageMaxID: String? {
        collectionViewModel.value.nextPageMaxID
    }

    public var maintainScrollPositionOfItem: CollectionItemIdentifier? {
        collectionViewModel.value.maintainScrollPositionOfItem
    }

    public func request(maxID: String?, minID: String?) {
        if case .statuses = collection, maxID == nil {
            profileService.fetchPinnedStatuses()
                .assignErrorsToAlertItem(to: \.alertItem, on: self)
                .sink { _ in }
                .store(in: &cancellables)
        }

        collectionViewModel.value.request(maxID: maxID, minID: minID)
    }

    public func select(identifier: CollectionItemIdentifier) {
        collectionViewModel.value.select(identifier: identifier)
    }

    public func canSelect(identifier: CollectionItemIdentifier) -> Bool {
        collectionViewModel.value.canSelect(identifier: identifier)
    }

    public func viewModel(identifier: CollectionItemIdentifier) -> CollectionItemViewModel? {
        collectionViewModel.value.viewModel(identifier: identifier)
    }
}
