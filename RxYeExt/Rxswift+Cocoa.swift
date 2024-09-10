
#if canImport(RxSwift) && canImport(UIKit)
import Foundation
import RxCocoa
import RxSwift

extension Reactive where Base == UIImpactFeedbackGenerator {
    
    var impactOccurred : Binder<Void> {
        return .init(base, scheduler: MainScheduler.asyncInstance) { target, _ in target.impactOccurred() }
    }
    
}

extension Reactive where Base == UIButton {
    
    public var touchDown: ControlEvent<Void> {
        return controlEvent(.touchDown)
    }
    
}

extension Reactive where Base == UIButton {
    
    public var touchUpInside: ControlEvent<Void> {
        return controlEvent(.touchUpInside)
    }
    
    public var touchUpOutside: ControlEvent<Void> {
        return controlEvent(.touchUpOutside)
    }
    
}
extension Reactive where Base : UICollectionViewCell{
    var isSelectedCP : ControlProperty<Bool>{
        let source = base.rx.methodInvoked(#selector(setter: base.isSelected)).compactMap{$0.first as? Bool}
        
        let binder = Binder<Bool>.init(base) { (target, value) in
            target.isSelected = value
        }
        
        return .init(values: source, valueSink: binder)
    }
}
extension Reactive where Base : UICollectionView{
    var itemSelecteBinder : Binder<(IndexPath,Bool,UICollectionView.ScrollPosition)>{
        return .init(base) { (target, arg) in
            target.selectItem(at: arg.0, animated: arg.1, scrollPosition: arg.2)
        }
    }
}

extension Reactive where Base : UIView{
    enum TouchEvent {
        case begin(_ touches: Set<UITouch>?,_ event: UIEvent?)
        case changed(_ touches: Set<UITouch>?,_ event: UIEvent?)
        case end(_ touches: Set<UITouch>?,_ event: UIEvent?)
        case cancel(_ touches: Set<UITouch>?,_ event: UIEvent?)
    }
    var frontTouchEvent : Observable<TouchEvent>{
        let begin = base.rx.sentMessage(#selector(base.touchesBegan(_:with:)))
            .map{
                TouchEvent.begin($0.first as? Set<UITouch>, $0.second as? UIEvent)
            }
        let changed = base.rx.sentMessage(#selector(base.touchesMoved(_:with:)))
            .map{
                TouchEvent.changed($0.first as? Set<UITouch>, $0.second as? UIEvent)
            }
        let end = base.rx.sentMessage(#selector(base.touchesEnded(_:with:)))
            .map{
                TouchEvent.end($0.first as? Set<UITouch>, $0.second as? UIEvent)
            }
        let cancel = base.rx.sentMessage(#selector(base.touchesCancelled(_:with:)))
            .map{
                TouchEvent.cancel($0.first as? Set<UITouch>, $0.second as? UIEvent)
            }
        return .merge(begin,changed,end,cancel)
    }
    var touchEvent : Observable<TouchEvent>{
        let begin = base.rx.methodInvoked(#selector(base.touchesBegan(_:with:)))
            .map{
                TouchEvent.begin($0.first as? Set<UITouch>, $0.second as? UIEvent)
            }
        let changed = base.rx.methodInvoked(#selector(base.touchesMoved(_:with:)))
            .map{
                TouchEvent.changed($0.first as? Set<UITouch>, $0.second as? UIEvent)
            }
        let end = base.rx.methodInvoked(#selector(base.touchesEnded(_:with:)))
            .map{
                TouchEvent.end($0.first as? Set<UITouch>, $0.second as? UIEvent)
            }
        let cancel = base.rx.methodInvoked(#selector(base.touchesCancelled(_:with:)))
            .map{
                TouchEvent.cancel($0.first as? Set<UITouch>, $0.second as? UIEvent)
            }
        return .merge(begin,changed,end,cancel)
    }
    var hitTest : Observable<(point:CGPoint,event:UIEvent)>{
        return base.rx.methodInvoked(#selector(base.hitTest(_:with:))).compactMap { (value) -> (point:CGPoint,event:UIEvent)? in
            if let point = value.first as? CGPoint,let event = value.last as? UIEvent{
                return (point,event)
            }
            return nil
        }
    }
    func hitTestInView(_ view:UIView) -> Observable<Bool>{
        return base.rx.hitTest.mapTarget(view).mapTarget(base).map { (target,arg) -> Bool in
            let (view,(point,_)) = arg
            
            let frame = view.superview?.convert(view.frame, to: target) ?? .zero
            
            if frame.contains(point){
                return true
            }
            
            return false
        }
    }
}



extension Array{
    var second : Element?{
        if self.count > 1{
            return self[1]
        }
        return nil
    }
}

extension Reactive where Base: UIView {
    public var isShow: Binder<Bool> {
        return Binder(self.base) { (view, hidden) in
            view.isHidden = !hidden
        }
    }
    
    public var hidden: Observable<Bool> {
        return self.methodInvoked(#selector(setter: self.base.isHidden))
            .map { event -> Bool in
                guard let isHidden = event.first as? Bool else {
                    fatalError()
                }
                return isHidden
            }
            .startWith(self.base.isHidden)
    }
}
#endif



