//
//  Item+CoreDataClass.swift
//  MergePolicyExperiments
//
//  Created by Andrey Chuprina on 1/24/19.
//  Copyright © 2019 Andriy Chuprina. All rights reserved.
//
//

import Foundation
import CoreData
import SerializationKit

@objc(Item)
public class Item: NSManagedObject, Decodable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Item> {
        return NSFetchRequest<Item>(entityName: "Item")
    }

    @NSManaged public var id: String?
    @NSManaged public var name: String?
    @NSManaged public var info: String?
    @NSManaged public var linkedContacts: Set<LinkedContacts>?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case info
        case linkedContacts
    }
    
    public required convenience init(from decoder: Decoder) throws {
        let context = decoder.userInfo[CodingUserInfoKey.context!] as! NSManagedObjectContext
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(context: context)

        self.id = "\(try container.decode(Int32.self, forKey: .id))"
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.info = try container.decodeIfPresent(String.self, forKey: .info)
        self.linkedContacts = try container.decodeIfPresent(Set<LinkedContacts>.self, forKey: .linkedContacts)
    }

    public override func prepareForDeletion() {
        // self.linkedContacts = nil
    }
}

extension CodingUserInfoKey {
    
    static let context = CodingUserInfoKey(rawValue: "context")
    
}
