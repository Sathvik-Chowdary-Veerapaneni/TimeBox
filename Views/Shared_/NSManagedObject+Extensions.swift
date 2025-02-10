import CoreData

extension NSManagedObject {
    var uriString: String {
        return self.objectID.uriRepresentation().absoluteString
    }
}
