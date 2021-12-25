//
//  MergePolicy.swift
//  MergePolicyExample
//
//  Created by Andrey Chuprina on 1/23/19.
//  Copyright © 2019 Andriy Chuprina. All rights reserved.
//

import CoreData
import SwiftyJSON

class MergePolicy: NSMergePolicy {

    class func create() -> MergePolicy {
        return MergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }
    
    private override init(merge ty: NSMergePolicyType) {
        super.init(merge: ty)
    }

    /*
     1. even if we edit single property in the json -> all keys coming as changedKeys
     2. if json property become null or empty -> its not coming as changedKeys when resolving conflicts
     */
    override func resolve(constraintConflicts list: [NSConstraintConflict]) throws {
        for conflict in list {
            guard let storeObject = conflict.databaseObject else {
                try super.resolve(constraintConflicts: list)
                return
            }

            var allKeys = Array(storeObject.entity.attributesByName.keys)
            allKeys.append(contentsOf: storeObject.entity.relationshipsByName.keys)

            for conflicting in conflict.conflictingObjects {
                let changedKeys = conflicting.changedValues().keys
                let unchangedKeys = allKeys.filter { !changedKeys.contains($0) }

                func takeValueFromStoreForUnchangedKeys() {
                    for key in unchangedKeys {
                        let value = storeObject.value(forKey: key)
                        conflicting.setValue(value, forKey: key)
                    }
                }
                switch conflicting {
                case conflicting as? Item:
                    guard let storeObject = storeObject as? Item else { fallthrough }
                    let hasLinkedContactChanges = changedKeys.contains("linkedContacts")
                    let isLinkedContactNullified = !storeObject.linkedContacts.isNilOrEmpty && !hasLinkedContactChanges // #2
                    let hasChanges = hasLinkedContactChanges || isLinkedContactNullified
                    func deleteStoreLinkedContacts() {
                        storeObject.linkedContacts?.forEach { storeObject.managedObjectContext?.delete($0) }
                    }
                    hasChanges
                    ? deleteStoreLinkedContacts()
                    : takeValueFromStoreForUnchangedKeys() // this never executed - need to find scenario
                default:
                    takeValueFromStoreForUnchangedKeys()
                }
            }
        }

        try super.resolve(constraintConflicts: list)
    }
}

extension Optional where Wrapped: Collection {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}

extension NSManagedObjectContext {

    public func deleteWithPermanentID(_ managedObject: NSManagedObject) throws {
        do { try self.obtainPermanentIDs(for: [managedObject]) }
        catch { throw AppError.coredataerror }
        delete(managedObject)
    }
}

enum AppError: Error {
    case coredataerror
}

internal extension NSMergePolicy {

    private class NSMergeByPropertyNonNilObjectTrumpMergePolicy: NSMergePolicy {

        override init(merge ty: NSMergePolicyType) {
            super.init(merge: ty)
        }

        override func resolve(constraintConflicts list: [NSConstraintConflict]) throws {
            try super.resolve(constraintConflicts: list.compactMap { conflict in
                // don't customize context-level handling
                guard let databaseSnapshot = conflict.databaseSnapshot,
                      let conflictingObject = conflict.conflictingObjects.first else { return conflict }

                databaseSnapshot
                    .filter { conflictingObject.value(forKey: $0.key) == nil && !($0.value is NSNull) }
                    .forEach {
                        // to-one relationships
                        if let objectID = $0.value as? NSManagedObjectID {
                            conflictingObject.setValue(conflictingObject.managedObjectContext!.object(with: objectID), forKey: $0.key)
                        } else {
                            conflictingObject.setValue($0.value, forKey: $0.key)
                        }
                    }

                // to-many relationships
                let nilToManyRelationshipKeys = conflictingObject
                    .entity
                    .relationshipsByName
                    .compactMap { $0.value.isToMany ? $0.key : nil }
                    .filter { conflictingObject.value(forKey: $0) == nil }

                guard !nilToManyRelationshipKeys.isEmpty else {
                    return conflict
                }

                let request = NSFetchRequest<NSDictionary>()
                request.resultType = .dictionaryResultType
                request.propertiesToFetch = nilToManyRelationshipKeys
                request.includesPendingChanges = false
                request.fetchLimit = 1
                request.havingPredicate = NSComparisonPredicate(
                    leftExpression: .init(forConstantValue: conflictingObject.objectID),
                    rightExpression: .init(forKeyPath: \NSManagedObject.objectID),
                    modifier: .direct,
                    type: .equalTo
                )
                try request.execute().first!
                    .filter { !($0.value is NSNull) }
                    .forEach { conflictingObject.setValue($0.value, forKey: $0.key as! String) }

                return conflict
            })
        }
    }

    /// A policy that merges conflicts between the persistent store's version of the object and the current in-memory version by individual property, with the non-nil in-memory changes trumping external changes.
    static var mergeByPropertyNonNilObjectTrump: NSMergePolicy = NSMergeByPropertyNonNilObjectTrumpMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
}

//class MyMergePolicy : NSMergePolicy {
//    override func resolve(constraintConflicts list: [NSConstraintConflict]) throws {
//
//        for conflict in list {
//            for object in conflict.conflictingObjects {
//                if let client = object as? Client {
//                    if let addresses = client.addresses {
//                        for object in addresses {
//                            if let address = object as? Address {
//                                client.managedObjectContext?.delete(address)
//                            }
//                        }
//                    }
//                }
//            }
//        }
//
//        /* This is kind of like invoking super, except instead of super
//         we invoke a singleton in the CoreData framework.  Weird. */
//        try NSOverwriteMergePolicy.resolve(constraintConflicts: list)
//
//        /* This section is for development verification only.  Do not ship. */
//        for conflict in list {
//            for object in conflict.conflictingObjects {
//                if let client = object as? Client {
//                    print("Final addresses in Client \(client.identifier) \(client.objectID)")
//                    if let addresses = client.addresses {
//                        for object in addresses {
//                            if let address = object as? Address {
//                                print("   Address: \(address.city ?? "nil city") \(address.objectID)")
//                            }
//                        }
//                    }
//                }
//            }
//        }
//
//    }
//}
