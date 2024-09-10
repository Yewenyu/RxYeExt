


#if canImport(RxSwift) && canImport(UIKit)
import UIKit
import RxSwift

public protocol ReuseIdentifierDelegate {
    
}

public extension ReuseIdentifierDelegate {
    static var reuseIdentifier : String {
        return String(describing: self)
    }
}

extension UICollectionReusableView: ReuseIdentifierDelegate {
    
}

extension UITableViewCell: ReuseIdentifierDelegate {
    
}
extension UITableViewHeaderFooterView: ReuseIdentifierDelegate {
    
}

// tableview cell 绑定
extension Reactive where Base: UITableView {
    public func items<S: Sequence, T: UITableViewCell, O: ObservableType>
        (_: T.Type)
        -> (_ source: O)
        -> (_ configureCell: @escaping (Int, S.Iterator.Element, T) -> Void)
        -> Disposable
        where O.Element == S {
            return items(cellIdentifier: T.reuseIdentifier, cellType: T.self)
    }
}

extension Reactive where Base: UICollectionView {
    public func items<S: Sequence, Cell: UICollectionViewCell, O : ObservableType>
        (_: Cell.Type)
        -> (_ source: O)
        -> (_ configureCell: @escaping (Int, S.Iterator.Element, Cell) -> Void)
        -> Disposable
        where O.Element == S {
            return items(cellIdentifier: Cell.reuseIdentifier, cellType: Cell.self)
    }
    
}

extension Reactive where Base: UIScrollView {
    
    public var contentSize : Observable<CGSize>{
        return base.rx.observe(CGSize.self, "contentSize").compactMap{$0}
    }
}


#endif
