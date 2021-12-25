//
//  TableViewController.swift
//  MergePolicyExperiments
//
//  Created by Andrey Chuprina on 1/24/19.
//  Copyright © 2019 Andriy Chuprina. All rights reserved.
//

import UIKit
import CoreData
import SwiftyJSON


class TableViewController: UITableViewController {

    private(set) var container: NSPersistentContainer!
    
    private lazy var fetchedResulstController: NSFetchedResultsController<Item> = {
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true), NSSortDescriptor(key: "name", ascending: true)]
        let controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: container.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        controller.delegate = self
        try? controller.performFetch()
        return controller
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)

        // setup(container: container)
        manualUpdate()
    }

    private func setup(container: NSPersistentContainer) {

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = container.persistentStoreCoordinator
        context.mergePolicy = MergePolicy.create()

        let data = Bundle.getData("setup", bundle: .main)
        let decoder = JSONDecoder()
        decoder.userInfo[CodingUserInfoKey.context!] = context
        do {
            _ = try decoder.decode([Item].self, from: data)
            try context.save()
        } catch {
            debugPrint(error)
        }
    }

    @objc private func refresh() {
        let data = Bundle.getData("update", bundle: .main)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = container.persistentStoreCoordinator
        context.mergePolicy = MergePolicy.create()

        let decoder = JSONDecoder()
        decoder.userInfo[CodingUserInfoKey.context!] = context
        do {
            _ = try decoder.decode([Item].self, from: data)
            try context.save()
            DispatchQueue.main.async {
                self.manualUpdate()
            }
        } catch {
            debugPrint(error)
        }
    }
    
    private func manualUpdate() {
        try? fetchedResulstController.performFetch()
        refreshControl?.endRefreshing()
        tableView.reloadData()
    }
    
}


extension TableViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResulstController.fetchedObjects?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let item = fetchedResulstController.fetchedObjects?[indexPath.row]
        item?.linkedContacts?.forEach { print("\($0.id!) - \($0.name ?? "")") }
    }
}


extension TableViewController {
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let item = fetchedResulstController.fetchedObjects?[indexPath.row]
        cell.textLabel?.text = item?.name
        cell.detailTextLabel?.text = "\(item?.info ?? "") - \(item?.linkedContacts?.first?.name ?? "Linked- Not Found")"
    }
}

extension TableViewController: NSFetchedResultsControllerDelegate {
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        tableView.reloadData()
    }
    
}
