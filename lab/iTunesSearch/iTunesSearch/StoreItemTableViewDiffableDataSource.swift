//
//  StoreItemTableViewDiffableDataSource.swift
//  iTunesSearch
//
//  Created by Skyler Robbins on 1/9/25.
//

import UIKit

@MainActor
class StoreItemTableViewDiffableDataSource: UITableViewDiffableDataSource<String, StoreItem.ID> {
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return snapshot().sectionIdentifiers[section]
    }
}
