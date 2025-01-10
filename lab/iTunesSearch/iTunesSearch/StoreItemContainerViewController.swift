
import UIKit

@MainActor
class StoreItemContainerViewController: UIViewController, UISearchResultsUpdating {
    
    @IBOutlet var tableContainerView: UIView!
    @IBOutlet var collectionContainerView: UIView!
    
    weak var collectionViewController: StoreItemCollectionViewController?

    
    let searchController = UISearchController()
    let storeItemController = StoreItemController()
    
    var tableViewDataSource: StoreItemTableViewDiffableDataSource!
    var collectionViewDataSource: UICollectionViewDiffableDataSource<String, StoreItem.ID>!

    var items = [StoreItem]()
    
    var itemIdentifiersSnapshot = NSDiffableDataSourceSnapshot<String, StoreItem.ID>()

    var selectedSearchScope: SearchScope {
        let selectedIndex = searchController.searchBar.selectedScopeButtonIndex
        let searchScope = SearchScope.allCases[selectedIndex]
        
        return searchScope
    }
    
    // keep track of async tasks so they can be cancelled if appropriate.
    var searchTask: Task<Void, Never>? = nil
    var tableViewImageLoadTasks: [IndexPath: Task<Void, Never>] = [:]
    var collectionViewImageLoadTasks: [IndexPath: Task<Void, Never>] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.searchController = searchController
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.automaticallyShowsSearchResultsController = true
        searchController.searchBar.showsScopeBar = true
        searchController.searchBar.scopeButtonTitles = SearchScope.allCases.map { $0.title }
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(fetchMatchingItems), object: nil)
        perform(#selector(fetchMatchingItems), with: nil, afterDelay: 0.3)
    }
                
    @IBAction func switchContainerView(_ sender: UISegmentedControl) {
        tableContainerView.isHidden.toggle()
        collectionContainerView.isHidden.toggle()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let tableViewController = segue.destination as? StoreItemListTableViewController {
            configureTableViewDataSource(tableViewController.tableView)
        }
        
        if let collectionViewController = segue.destination as? StoreItemCollectionViewController {
            collectionViewController.configureCollectionViewLayout(for: selectedSearchScope)
            configureCollectionViewDataSource(collectionViewController.collectionView)
            
            self.collectionViewController = collectionViewController
        }
    }

    func configureTableViewDataSource(_ tableView: UITableView) {
        tableViewDataSource = StoreItemTableViewDiffableDataSource(tableView: tableView, cellProvider: { [weak self] tableView, indexPath, itemIdentifier in
            guard let self,
                  let item = items.first(where: { $0.id == itemIdentifier }) else {
                return nil
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "Item", for: indexPath) as! ItemTableViewCell
            
            cell.configure(for: item, storeItemController: storeItemController)
            
            if cell.itemImageView.image == ItemTableViewCell.placeholder {
                tableViewImageLoadTasks[indexPath]?.cancel()
                tableViewImageLoadTasks[indexPath] = Task { [weak self] in
                    guard let self else { return }
                    defer {
                        tableViewImageLoadTasks[indexPath] = nil
                    }
                    do {
                        _ = try await storeItemController.fetchImage(from: item.artworkURL)
                        
                        var snapshot = tableViewDataSource.snapshot()
                        snapshot.reconfigureItems([itemIdentifier])
                        await tableViewDataSource.apply(snapshot, animatingDifferences: true)
                    } catch {
                        print("Error fetching image: \(error)")
                    }
                }
            }
            return cell
        })
    }
    
    func configureCollectionViewDataSource(_ collectionView: UICollectionView) {
        let nib = UINib(nibName: "ItemCollectionViewCell", bundle: Bundle(for: ItemCollectionViewCell.self))
        let cellRegistration = UICollectionView.CellRegistration<ItemCollectionViewCell, StoreItem.ID>(cellNib: nib) { [weak self] cell, indexPath, itemIdentifier in
            guard let self = self,
                  let item = self.items.first(where: { $0.id == itemIdentifier}) else {
                return
            }

            cell.configure(for: item, storeItemController: storeItemController)
            
            if cell.itemImageView.image == ItemCollectionViewCell.placeholder {
                collectionViewImageLoadTasks[indexPath]?.cancel()
                collectionViewImageLoadTasks[indexPath] = Task { [weak self] in
                    guard let self else { return }
                    defer {
                        collectionViewImageLoadTasks[indexPath] = nil
                    }
                    do {
                        _ = try await storeItemController.fetchImage(from: item.artworkURL)
                        
                        var snapshot = collectionViewDataSource.snapshot()
                        snapshot.reconfigureItems([itemIdentifier])
                        await collectionViewDataSource.apply(snapshot, animatingDifferences: true)
                    } catch {
                        print("Error fetching image: \(error)")
                    }
                }
            }
        }
        let headerRegistration = UICollectionView.SupplementaryRegistration<StoreItemCollectionViewSectionHeader>(elementKind: "Header") { [weak self] headerView, elementKind, indexPath in
            guard let self else { return }
            
            let title = itemIdentifiersSnapshot.sectionIdentifiers[indexPath.section]
            headerView.setTitle(title)
        }
        collectionViewDataSource = UICollectionViewDiffableDataSource<String, StoreItem.ID>(collectionView: collectionView) { (collectionView, indexPath, identifier) -> UICollectionViewCell? in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: identifier)
        }
        collectionViewDataSource.supplementaryViewProvider = { collectionView, kind, indexPath -> UICollectionReusableView? in return
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }

    @objc func fetchMatchingItems() {
        
        itemIdentifiersSnapshot.deleteAllItems()
        
        self.items = []
                
        let searchTerm = searchController.searchBar.text ?? ""
        
        let searchScopes: [SearchScope]
        if selectedSearchScope == .all {
            searchScopes = [.movies, .music, .apps, .books]
        } else {
            searchScopes = [selectedSearchScope]
        }
        
        // cancel any images that are still being fetched and reset the imageTask dictionaries
        collectionViewImageLoadTasks.values.forEach { task in task.cancel() }
        collectionViewImageLoadTasks = [:]
        tableViewImageLoadTasks.values.forEach { task in task.cancel() }
        tableViewImageLoadTasks = [:]
        
        // cancel existing task since we will not use the result
        searchTask?.cancel()
        searchTask = Task {
            if !searchTerm.isEmpty {
                do {
                    try await fetchAndHandleItemsForSearchScopes(searchScopes, withSearchTerm: searchTerm)
                } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    // Ignore cancellation errors
                } catch {
                    // Otherwise, print an error to the console
                    print(error)
                }
            } else {
                await self.tableViewDataSource.apply(itemIdentifiersSnapshot, animatingDifferences: true)
                await self.collectionViewDataSource.apply(itemIdentifiersSnapshot, animatingDifferences: true)
            }
            searchTask = nil
        }

    }
    
    func handleFetchedItems(_ items: [StoreItem]) async {
        self.items += items
        
        itemIdentifiersSnapshot = createSectionedSnapshot(from: self.items)
        
        collectionViewController?.configureCollectionViewLayout(for: selectedSearchScope)
        
        await tableViewDataSource.apply(itemIdentifiersSnapshot, animatingDifferences: true)
        await collectionViewDataSource.apply(itemIdentifiersSnapshot, animatingDifferences: true)
    }
    
    func fetchAndHandleItemsForSearchScopes(_ searchScopes: [SearchScope], withSearchTerm searchTerm: String) async throws {
        try await withThrowingTaskGroup(of: (SearchScope, [StoreItem]).self) { group in
            for searchScope in searchScopes {
                group.addTask {
                    try Task.checkCancellation()
                    // Set up query dictionary
                    let query = [
                        "term": searchTerm,
                        "media": searchScope.mediaType,
                        "lang": "en_us",
                        "limit": "50"
                    ]
                    return (searchScope, try await self.storeItemController.fetchItems(matching: query))
                }
            }
            
            for try await (searchScope, items) in group {
                try Task.checkCancellation()
                if searchTerm == self.searchController.searchBar.text &&
                   (self.selectedSearchScope == .all || searchScope == self.selectedSearchScope) {
                    await handleFetchedItems(items)
                }
            }
        }
    }
    
    func createSectionedSnapshot(from items: [StoreItem]) -> NSDiffableDataSourceSnapshot<String, StoreItem.ID> {
        let movies = items.filter { $0.kind == "feature-movie" }
        let music = items.filter { $0.kind == "song" || $0.kind == "album" }
        let apps = items.filter { $0.kind == "software" }
        let books = items.filter { $0.kind == "ebook" }

        let grouped: [(SearchScope, [StoreItem])] = [
            (.movies, movies),
            (.music, music),
            (.apps, apps),
            (.books, books)
        ]

        var snapshot = NSDiffableDataSourceSnapshot<String, StoreItem.ID>()
        grouped.forEach { (scope, items) in
            if items.count > 0 {
                snapshot.appendSections([scope.title])
                snapshot.appendItems(items.map(\.id), toSection: scope.title)
            }
        }

        return snapshot
    }


}

