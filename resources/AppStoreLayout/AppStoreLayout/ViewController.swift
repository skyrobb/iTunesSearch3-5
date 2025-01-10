
import UIKit

class ViewController: UIViewController {
    
    // MARK: Section Definitions
    enum Section: Hashable {
        case promoted
        case standard(String)
        case categories
    }
    
    enum SupplementaryViewKind {
        static let header = "header"
        static let topLine = "topLine"
        static let bottomLine = "bottomLine"
    }

    @IBOutlet var collectionView: UICollectionView!
    
    var dataSource: UICollectionViewDiffableDataSource<Section, Item.ID>!
    
    var sections = [Section]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // MARK: Collection View Setup
        collectionView.collectionViewLayout = createLayout()
                
        configureDataSource()
    }
    
    func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment -> NSCollectionLayoutSection? in
            
            let section = self.sections[sectionIndex]
            
            let headerItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.92), heightDimension: .estimated(44))
            let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerItemSize, elementKind: SupplementaryViewKind.header, alignment: .top)
            headerItem.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
            
            switch section {
            case .promoted:
                // MARK: Promoted Section Layout
                
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalWidth(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
                
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.92), heightDimension: .estimated(300))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .groupPagingCentered
                
                return section
                
            case .standard:
                // MARK: Standard Section Layout
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1/3))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
                
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.92), heightDimension: .estimated(250))
                let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, repeatingSubitem: item, count: 3)
                
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .groupPagingCentered
                section.boundarySupplementaryItems = [headerItem]
                
                return section
            case .categories:
                // MARK: Categories Section Layout
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                let availableLayoutWidth = layoutEnvironment.container.effectiveContentSize.width
                let groupWidth = availableLayoutWidth * 0.92
                let remainingWidth = availableLayoutWidth - groupWidth
                let halfOfRemainingWidth = remainingWidth / 2
                let nonCategorySectionItemInset = CGFloat(4)
                let itemLeadingAndTrailingInset = halfOfRemainingWidth + nonCategorySectionItemInset
                
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: itemLeadingAndTrailingInset, bottom: 0, trailing: itemLeadingAndTrailingInset)
                
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44))
                let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
                
                let section = NSCollectionLayoutSection(group: group)
                section.boundarySupplementaryItems = [headerItem]
                
                return section
            }
        }
        
        return layout
    }
    
    func configureDataSource() {
        // MARK: Data Source Initialization
        let promotedAppCellRegistration = UICollectionView.CellRegistration<PromotedAppCollectionViewCell, Item.ID> { cell, indexPath, itemIdentifier in
            guard let item = Item.promotedApps.first(where: { $0.id == itemIdentifier }) else { return }
            
            cell.configureCell(item.app!)
        }
        
        let standardAppCellRegistration = UICollectionView.CellRegistration<StandardAppCollectionViewCell, Item.ID> { cell, indexPath, itemIdentifier in
            let possibleApps = Item.essentialApps + Item.popularApps
            guard let item = possibleApps.first(where: { $0.id == itemIdentifier }) else { return }
            
            let isThirdItem = (indexPath.row + 1).isMultiple(of: 3)
            cell.configureCell(item.app!, hideBottomLine: isThirdItem)
        }
        
        let categoryCellRegistration = UICollectionView.CellRegistration<CategoryCollectionViewCell, Item.ID> { [weak self] cell, indexPath, itemIdentifier in
            guard let self, let item = Item.categories.first(where: { $0.id == itemIdentifier }) else { return }
            
            let isLastItem = collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1
            cell.configureCell(item.category!, hideBottomLine: isLastItem)
        }
        
        dataSource = .init(collectionView: collectionView, cellProvider: { collectionView, indexPath, itemIdentifier -> UICollectionViewCell? in
            let section = self.sections[indexPath.section]
            switch section {
            case .promoted:
                return collectionView.dequeueConfiguredReusableCell(using: promotedAppCellRegistration, for: indexPath, item: itemIdentifier)
            case .standard:
                return collectionView.dequeueConfiguredReusableCell(using: standardAppCellRegistration, for: indexPath, item: itemIdentifier)
            case .categories:
                return collectionView.dequeueConfiguredReusableCell(using: categoryCellRegistration, for: indexPath, item: itemIdentifier)
            }
        })
        
        // MARK: Supplemantary View Provider
        let sectionHeaderRegistration = UICollectionView.SupplementaryRegistration<SectionHeaderView>(elementKind: SupplementaryViewKind.header) { [weak self] headerView, elementKind, indexPath in
            
            guard  let self else { return }
            
            let section = sections[indexPath.section]
            
            let sectionName: String
            
            switch section {
            case .promoted:
                sectionName = ""
            case .standard(let name):
                sectionName = name
            case .categories:
                sectionName = "Top Categories"
            }
            
            headerView.setTitle(sectionName)
        }
        
        let lineRegistration: UICollectionView.SupplementaryRegistration<LineView>.Handler = { _, _, _ in }
        
        let topLineRegistration = UICollectionView.SupplementaryRegistration(elementKind: SupplementaryViewKind.topLine, handler: lineRegistration)
        
        let bottomLineRegistration = UICollectionView.SupplementaryRegistration(elementKind: SupplementaryViewKind.bottomLine, handler: lineRegistration)
        
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath -> UICollectionReusableView? in
            
            guard let self else { return nil }
            
            switch kind {
            case SupplementaryViewKind.header:
                guard sections[indexPath.section] != .promoted else { return nil }
                
                return collectionView.dequeueConfiguredReusableSupplementary(using: sectionHeaderRegistration, for: indexPath)
            
            case SupplementaryViewKind.topLine:
                return collectionView.dequeueConfiguredReusableSupplementary(using: topLineRegistration, for: indexPath)
                
            case SupplementaryViewKind.bottomLine:
                return collectionView.dequeueConfiguredReusableSupplementary(using: bottomLineRegistration, for: indexPath)
                
            default:
                return nil
            }
            
        }
        
        // MARK: Snapshot Definition
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item.ID>()
        snapshot.appendSections([.promoted])
        snapshot.appendItems(Item.promotedApps.map(\.id), toSection: .promoted)
        
        let popularSection = Section.standard("Popular this week")
        let essentialSection = Section.standard("Essential picks")
        
        snapshot.appendSections([popularSection, essentialSection])
        snapshot.appendItems(Item.popularApps.map(\.id), toSection: popularSection)
        snapshot.appendItems(Item.essentialApps.map(\.id), toSection: essentialSection)
        
        let categoriesSection = Section.categories
        snapshot.appendSections([categoriesSection])
        snapshot.appendItems(Item.categories.map(\.id), toSection: categoriesSection)
        
        sections = snapshot.sectionIdentifiers
        dataSource.apply(snapshot)
    }
}

