//
//  LinkedContacts+CoreDataProperties.swift
//  MergePolicyExperiments
//
//  Created by Karthik on 25/12/21.
//  Copyright © 2021 Andriy Chuprina. All rights reserved.
//
//

import Foundation
import CoreData
import SerializationKit

@objc(LinkedContacts)
public class LinkedContacts: NSManagedObject, Decodable {

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case info
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LinkedContacts> {
        return NSFetchRequest<LinkedContacts>(entityName: "LinkedContacts")
    }

    @NSManaged public var id: String?
    @NSManaged public var name: String?

    public required convenience init(from decoder: Decoder) throws {
        let context = decoder.userInfo[CodingUserInfoKey.context!] as! NSManagedObjectContext
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(context: context)

        self.id = "\(try container.decode(Int32.self, forKey: .id))"
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
    }
}
