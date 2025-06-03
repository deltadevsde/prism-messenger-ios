//
//  InMemoryStore.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import OrderedCollections

class InMemoryStore<T: Identifiable> {
    private var items: OrderedDictionary<T.ID, T> = [:]

    func get(byId id: T.ID) -> T? {
        return items[id]
    }

    func first(where predicate: (T) -> Bool) -> T? {
        return items.values.first(where: predicate)
    }

    func filter(where predicate: (T) -> Bool) -> [T] {
        return items.values.filter(predicate)
    }

    func getAll() -> [T] {
        return items.values.elements
    }

    func save(_ item: T) {
        items[item.id] = item
    }

    func remove(byId id: T.ID) {
        items.removeValue(forKey: id)
    }

    func remove(where predicate: (T) -> Bool) {
        items = items.filter { !predicate($0.value) }
    }
}

class InMemoryStoreProvider {

    private var storesByType: [ObjectIdentifier: Any] = [:]

    func provideTypedStore<T: Identifiable>() -> InMemoryStore<T> {
        let typeId = ObjectIdentifier(T.self)
        if let store = storesByType[typeId] {
            return store as! InMemoryStore<T>
        }

        let store = InMemoryStore<T>()
        storesByType[typeId] = store
        return store
    }
}
