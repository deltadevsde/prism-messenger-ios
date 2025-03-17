class InMemoryStore {
    private var items: [ObjectIdentifier: Any] = [:]

    // Single item storage
    func set<T>(_ value: T, for type: T.Type) {
        items[ObjectIdentifier(type)] = value
    }

    func get<T>(_ type: T.Type) -> T? {
        return items[ObjectIdentifier(type)] as? T
    }

    // List storage
    func setList<T>(_ list: [T]) {
        items[ObjectIdentifier(T.self)] = list
    }

    func getList<T>(_ type: T.Type) -> [T] {
        return (items[ObjectIdentifier(type)] as? [T]) ?? []
    }

    func addToList<T>(_ item: T) {
        var currentList = getList(T.self)
        currentList.append(item)
        setList(currentList)
    }

    func removeFromList<T: Equatable>(_ item: T, for type: T.Type) {
        var currentList = getList(type)
        currentList.removeAll { $0 == item }
        setList(currentList)
    }

    func clearList<T>(_ type: T.Type) {
        items.removeValue(forKey: ObjectIdentifier(type))
    }
}
