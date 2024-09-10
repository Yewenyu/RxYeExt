

#if canImport(RxSwift)

import Foundation
import RxCocoa
import RxSwift

infix operator <-> : DefaultPrecedence

public func <-> <T>(property: ControlProperty<T>, relay: BehaviorRelay<T>) -> Disposable {
    if T.self == String.self {
        #if DEBUG && !os(macOS)
        fatalError("It is ok to delete this message, but this is here to warn that you are maybe trying to bind to some `rx.text` property directly to relay.\n" +
            "That will usually work ok, but for some languages that use IME, that simplistic method could cause unexpected issues because it will return intermediate results while text is being inputed.\n" +
            "REMEDY: Just use `textField <-> relay` instead of `textField.rx.text <-> relay`.\n" +
            "Find out more here: https://github.com/ReactiveX/RxSwift/issues/649\n"
        )
        #endif
    }
    
    let bindToUIDisposable = relay.bind(to: property)
    let bindToRelay = property
        .subscribe(onNext: { n in
            relay.accept(n)
        }, onCompleted:  {
            bindToUIDisposable.dispose()
        })
    
    return Disposables.create(bindToUIDisposable, bindToRelay)
}

public protocol OptionalType {
    associatedtype Wrapped
    var value: Wrapped? { get }
}

extension Optional: OptionalType {
    /// Cast `Optional<Wrapped>` to `Wrapped?`
    public var value: Wrapped? {
        return self
    }
}

extension ObservableType where Element: OptionalType {
    
    public func wrapper() -> Observable<Element.Wrapped> {
        
        return self.flatMapLatest({
            optionalValue -> Observable<Element.Wrapped> in

            guard let value = optionalValue.value else {
                return .empty()
            }

            return .just(value)
        })
        
    }
    
}

extension ObservableType where Element == Bool {
    /// Boolean not operator
    public func toggle() -> Observable<Bool> {
        return self.map(!)
    }
    
    public func onlyTrue() -> Observable<Bool> {
        return self.filter({ $0 == true })
    }
    
    public func onlyFalse() -> Observable<Bool> {
        return self.filter({ $0 == false })
    }
    
    
    
}

extension ObservableType where Element == Bool {
    /// Boolean not operator
    public func not() -> Observable<Bool> {
        return self.map(!)
    }
    
}

extension SharedSequenceConvertibleType {
    public func mapToVoid() -> SharedSequence<SharingStrategy, Void> {
        return map { _ in }
    }
    public var mapToTure : SharedSequence<SharingStrategy, Bool> {
        return map { _ in true }
    }
    public var mapToFalse : SharedSequence<SharingStrategy, Bool> {
        return map { _ in false }
    }
}

public class ObservableQueue{
    static let sendLastqueue = DispatchQueue(label: "Observable.sendLast")
    public static let waitQueue = DispatchQueue(label: "___.wait")
}

extension ObservableType {
    
    public func catchErrorJustComplete() -> Observable<Element> {
        return self.catch { _ in
            return Observable.empty()
        }
    }
    
    public func asDriverOnErrorJustComplete() -> Driver<Element> {
        return asDriver { error in
            return Driver.empty()
        }
    }
    
    public func observeOnMainQueueAsync(_ after:RxTimeInterval = .seconds(0)) -> Observable<Element>{
        return delay(after, scheduler: MainScheduler.asyncInstance).map{$0}
    }
    public func observeOnGlobalQueueAsync(_ after:RxTimeInterval = .seconds(0)) -> Observable<Element>{
        return delay(after, scheduler: ConcurrentDispatchQueueScheduler(qos: .userInitiated)).map{$0}
    }
    
    public func compactMapTarget<T:AnyObject>(_ target:T?) -> Observable<(T,Element)>{
        return compactMap { [weak target](value) -> (T,Element)? in
            if let target = target{
                return (target,value)
            }
            return nil
        }
    }
    
    public func arrayMoreThan0<T>(_ type:[T].Type) -> Observable<Element>{
        return compactMap {(element) -> Element? in
            if let e = element as? [T],e.count > 0{
                return element
            }
            return nil
        }
    }
    var maptToElementAndTrue : Observable<(element:Element,bool:Bool)>{
        return map{($0,true)}
    }
    var maptToElementAndFalse : Observable<(element:Element,bool:Bool)>{
        return map{($0,false)}
    }
    public func mapToType<T>(_ type:T.Type,_ block:((Element)->(T))? = nil) -> Observable<T>{
        return compactMap{
            block?($0)
        }
    }
    public var mapToTrue : Observable<Bool> {
        return map { _ in true }
    }
    public var mapToFalse : Observable<Bool> {
        return map { _ in false }
    }
    var stop : Observable<Element>{
        return self.compactMap { _ in
            nil
        }
    }
    var stopToVoid : Observable<Void>{
        return stop.mapToVoid()
    }
    public func stopToType<T>(_ type:T.Type) -> Observable<T>{
        return stop.compactMap {
            $0 as? T
        }
        
    }
    
    public func merge<T>(_ sources:Observable<T>...) -> Observable<Element>{
        var sources = sources.map{$0.compactMap{ $0 as? Element}}
        sources.insert(asObservable(), at: 0)
        return Observable.merge(sources)
    }
    
    public func merge(_ sources:Observable<Element>...) -> Observable<Element>{
        var sources = sources
        sources.insert(asObservable(), at: 0)
        return Observable.merge(sources)
    }
    
    public func mapToVoid() -> Observable<Void> {
        return map { _ in }
    }
    var mapToNil : Observable<Element>{
        return compactMap{_ in nil}
    }
    public func mapTarget<T:AnyObject>(_ target:T) -> Observable<(T,Element)>{
        return compactMapTarget(target)
    }
    
    public func debounceInMain(_ dueTime:RxTimeInterval) -> Observable<Element>{
        return debounce(dueTime, scheduler: MainScheduler.asyncInstance)
    }
    
    public func sendFirst(_ dueTime:RxTimeInterval) -> Observable<Element>{
        var element : Element?
        let pub = PublishRelay<Element?>()
        let queue = ObservableQueue.sendLastqueue
        
        let origin = self.compactMap { (e) -> Element? in
            
            queue.async {
                if element == nil{
                    pub.accept(e)
                    element = e
                    queue.asyncAfter(deadline: .now() + dueTime) {
                        element = nil
                    }
                }
            }
            
            return nil
        }
        
        return Observable.merge(origin,pub.compactMap{$0}.do(onNext: { (_) in
            NSLog("")
        }))
    }
    public func sendLast(_ dueTime:RxTimeInterval) -> Observable<Element>{
        
        var element : Element?
        let pub = PublishRelay<Element?>()
        let queue = ObservableQueue.sendLastqueue
        
        let origin = self.compactMap { (e) -> Element? in
            
            if element == nil{
                queue.asyncAfter(deadline: .now() + dueTime) {
                    pub.accept(element)
                    element = nil
                }
            }
            element = e
            return nil
        }
        
        return Observable.merge(origin,pub.compactMap{$0}.do(onNext: { (_) in
            NSLog("")
        }))
        
    }
    
    public func subscribe<T:AnyObject>(_ target:T,onNext: ((T,Element) -> Void)? = nil, onError: ((T,Swift.Error) -> Void)? = nil, onCompleted: ((T) -> Void)? = nil, onDisposed: ((T) -> Void)? = nil) -> Disposable{
        return subscribe(onNext: { [weak target](value) in
        guard let target = target else{return}
        onNext?(target,value)
            }, onError: { [weak target](error) in
                guard let target = target else{return}
                onError?(target,error)
            }, onCompleted: {
                [weak target] in
                guard let target = target else{return}
                onCompleted?(target)
        }) {
            [weak target] in
            guard let target = target else{return}
            onDisposed?(target)
        }
    }
    public func `do`<Observer:ObserverType,Value>(_ obserable:Observer,_ value:Value) -> Observable<Element> where Value == Observer.Element{
        return self.do(onNext: { (_) in
            obserable.onNext(value)
        })
    }
    public func `do`<Observer:ObserverType>(obserable:Observer) -> Observable<Element> where Observer.Element == Element{
        return self.do(onNext: { (element) in
            obserable.onNext(element)
        })
    }
    public func foreach<T>(_ foreach:((_ t:T)->())?) -> Observable<Element> where Element == [T]{
        return self.do(onNext: { (element) in
            element.forEach {
                foreach?($0)
            }
        })
    }

    
    public func `do`<T:AnyObject>(_ target:T,onNext: ((T,Element) throws -> Void)? = nil, afterNext: ((T,Element) throws -> Void)? = nil, onError: ((T,Swift.Error) throws -> Void)? = nil, afterError: ((T,Swift.Error) throws -> Void)? = nil, onCompleted: ((T) throws -> Void)? = nil, afterCompleted: ((T) throws -> Void)? = nil, onSubscribe: ((T) -> Void)? = nil, onSubscribed: ((T) -> Void)? = nil, onDispose: ((T) -> Void)? = nil) -> Observable<Element>{
        
        return self.do(onNext: { [weak target](value) in
            guard let target = target else{return}
            try? onNext?(target,value)
            }, afterNext: { [weak target](value) in
            guard let target = target else{return}
            try? afterNext?(target,value)
            }, onError: { [weak target](error) in
            guard let target = target else{return}
            try? onError?(target,error)
            }, afterError: { [weak target](error) in
            guard let target = target else{return}
            try? afterError?(target,error)
            }, onCompleted: {[weak target] in
                guard let target = target else{return}
                try? onCompleted?(target)
            }, afterCompleted: {
                [weak target] in
                guard let target = target else{return}
                try? afterCompleted?(target)
            }, onSubscribe: {
                [weak target] in
                guard let target = target else{return}
                onSubscribe?(target)
            }, onSubscribed: {
                [weak target] in
                guard let target = target else{return}
                onSubscribed?(target)
        }) {
            [weak target] in
            guard let target = target else{return}
            onDispose?(target)
        }
    }
    
    public func bind<T:AnyObject>(_ target:T,queue:DispatchQueue? = nil,onNext: @escaping (T,Self.Element) -> Void) -> Disposable{
        
        let binder = Binder<Element>.init(target) {(target,value) in
            if let queue = queue{
                queue.async {
                    onNext(target,value)
                }
            }else{
                onNext(target,value)
            }
            
        }
        
        return self.bind(to: binder)
    }
    public func bindToVoid<T:AnyObject>(_ target:T,queue:DispatchQueue? = nil,onNext: @escaping (T) -> Void) -> Disposable{
        
        return bind(target, queue: queue) { target, _ in
            onNext(target)
        }
    }
    public func doWithoutElement(_ doSomething:@escaping () -> Void) -> Observable<Element>{
        return self.do { (_) in
            doSomething()
        }

    }
    var disposable : Disposable{
        return self.bind(onNext: {_ in })
    }
    public func wait(by condition:((Element)->(Bool))?) -> Observable<Element>{
        return compactMap{ element -> Element? in
            if condition?(element) == true{
                return element
            }
            return nil
        }
    }
    public func wait(_ queue:DispatchQueue? = nil,timeout:Int = -1,timeoutHandle:((Element) ->(Bool))? = nil,handleElements:(([Element])->([Element]))? = nil,util condition:Observable<Bool>) -> Observable<Element>{
        let timeoutPb = BehaviorSubject(value: false)
        let queue = queue ?? .init(label: "\(self)")
        if timeout > 0{
            queue.asyncAfter(deadline: .now() + .milliseconds(timeout)){
                timeoutPb.onNext(true)
            }
        }
        
        return wait(queue,handleElements: handleElements,util: condition.merge(timeoutPb)).compactMap { e -> Element? in
            if (try? timeoutPb.value()) == true{
                if timeoutHandle?(e) == false{
                    return nil
                }
            }
            
            return e
        }
    }
    
    public func oneByone(_ queue:DispatchQueue? = nil,util condition:Observable<Bool>) -> Observable<Element>{
        var elements : [Element] = []
        let queue = DispatchQueue.init(label: "oneByoneAndwait")
        let canNextPb = BehaviorSubject(value: true)
        let ob = self.do { element in
            queue.async {
                elements.append(element)
            }
        }
        
        let nextOb = condition.do {
            canNextPb.onNext($0)
        }.onlyTrue()
        return ob.merge(nextOb).wait(queue,handleElements: { v in
            if elements.count > 0{
                canNextPb.onNext(false)
                return [elements.removeFirst()]
            }
            return []
        },util: canNextPb).observe(on: SerialDispatchQueueScheduler(queue: queue, internalSerialQueueName: queue.label))
    }
    
    public func wait(_ queue:DispatchQueue? = nil,handleElements:(([Element])->([Element]))? = nil,util condition:Observable<Bool>) -> Observable<Element>{

        let queue = queue ?? .init(label: "\(self)")
        let waitPb = PublishRelay<Void>()
        var canNext = false
        if let bj = condition as? BehaviorSubject<Bool>{
            canNext = (try? bj.value()) == true
        }
        
        var elements : [Element] = []
        
        let conditionOb = condition.do { (value) in
            queue.async {
                canNext = value
                if canNext{
                    waitPb.accept(())
                }
            }
        }.stopToType(Element.self)
        
        let waitOb = waitPb.observe(on: SerialDispatchQueueScheduler(queue: queue, internalSerialQueueName: queue.label)).compactMap { (_) -> [Element]? in
            if !canNext{
                return nil
            }
            let value = handleElements?(elements) ?? elements
            elements = []
            return value
        }
        .flatMap{
            Observable.merge($0.map{Observable.just($0)})
        }

        let actionOb =  self.do { (element) in
            
            queue.async {
                elements.append(element)
                waitPb.accept(())
            }
            
        }.stopToType(Element.self)

        return waitOb.merge(conditionOb,actionOb)

    }
    
    static public func create<T:AnyObject>(_ target:T?,_ subscribe:((_ target:T,_ observable:AnyObserver<Element>)->(Disposable))?) -> Observable<Element>{
        return create { [weak target](ob) -> Disposable in
            guard let target = target,let subscribe = subscribe else{
                return Disposables.create()
            }
            return subscribe(target,ob)
        }
    }
    
    #if canImport(UIKit)
    public func impactFeedback(_ style:UIImpactFeedbackGenerator.FeedbackStyle) -> Observable<Element>{
        return self.doWithoutElement {
            let gen = UIImpactFeedbackGenerator.init(style: style);//light震动效果的强弱
            gen.prepare();//反馈延迟最小化
            gen.impactOccurred()//触发效果
        }
    }
    #endif
}

extension ObservableType where Element == Bool{
    public func ifTrue(_ doSomething:@escaping () -> Void) -> Observable<Element>{
        
        return map{
            if $0{
                doSomething()
            }
            return $0
        }
    }
    public func ifFalse(_ doSomething:@escaping () -> Void) -> Observable<Element>{
        
        return map{
            if $0{
                doSomething()
            }
            return $0
        }
    }
}

extension PublishSubject{
    public func onNext(_ elements:[Element]){
        elements.forEach{
            onNext($0)
        }
    }
    public func onNext(_ element:Element,deleyMill:Int){
        if deleyMill > 0{
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(deleyMill)){
                self.onNext(element)
            }
        }else{
            onNext(element)
        }
    }
    public func on(Next elements:Element...){
        elements.forEach{
            onNext($0)
        }
    }
    
}
extension PublishRelay{
    public func onNext(_ elements:[Element]){
        elements.forEach{
            accept($0)
        }
    }
    public func on(Next elements:Element...){
        elements.forEach{
            accept($0)
        }
    }
}
extension BehaviorSubject{
    public func onNext(_ elements:[Element]){
        elements.forEach{
            onNext($0)
        }
    }
    public func on(Next elements:Element...){
        elements.forEach{
            onNext($0)
        }
    }
}
extension BehaviorRelay{
    public func onNext(_ elements:[Element]){
        elements.forEach{
            accept($0)
        }
    }
    public func on(Next elements:Element...){
        elements.forEach{
            accept($0)
        }
    }
}

extension Reactive {
    var asObservable : Observable<Base>{
        return Observable.just(base)
    }
    public func toBinder<T>(_ block: ((_ base:Base,T)->())?) -> Binder<T> where Base:AnyObject{
        return .init(base) { (target, T) in
            block?(target,T)
        }
    }
}

extension Reactive where Base : NotificationCenter{
    public func notifications(_ names:Notification.Name...) -> Observable<Notification>{
        let observers = names.map{notification($0)}
        let observer = Observable.merge(observers)
        return observer
    }
}


#if canImport(Lottie)
import Lottie

extension Reactive where Base : LottieAnimationView {
    
    public func isLoading(by isLoadingEndHidden: Bool = true) -> Binder<Bool> {
        return .init(base) {
            if $1 {
                $0.play()
                $0.isHidden = false
            } else {
                $0.pause()
                $0.isHidden = isLoadingEndHidden
            }
        }
    }
    
    var play : Binder<Void> {
        return .init(base) { target, _ in target.play() }
    }
    
    var pause : Binder<Void> {
        return .init(base) { target, _ in target.pause() }
    }
    
    var stop : Binder<Void> {
        return .init(base) { target, _ in target.stop() }
    }
    
}



#endif

#if canImport(RxDataSources)
import RxDataSources

extension Array where Element : SectionModelType{
    subscript(_ indexPath:IndexPath) -> Element.Item?{
        if indexPath.section < self.count{
            let item = self[indexPath.section].items
            if item.count > indexPath.row{
                return item[indexPath.row]
            }
        }
        return nil
    }
    public func indexPath(_ each:(Element.Item)->(Bool)) -> [IndexPath]{
        var indexPath : [IndexPath] = []
        for e in enumerated(){
            for ee in e.element.items.enumerated(){
                if each(ee.element){
                    indexPath.append(.init(item: ee.offset, section: e.offset))
                }
            }
        }
        return indexPath
    }
}

#endif

#if canImport(Kingfisher) && canImport(UIKit)

import Kingfisher

extension KingfisherManager : ReactiveCompatible { }

extension Reactive where Base == KingfisherManager {
    
    static public func retrieveImage(with resource: Resource,
                       options: KingfisherOptionsInfo? = nil) -> Observable<UIImage?> {
        
        return .create { (ob) -> Disposable in
            
            KingfisherManager.shared.retrieveImage(with: resource, options: options, progressBlock: nil) { (image, error, type, url) in
                ob.onNext(image)
                ob.onCompleted()
            }
            
            return Disposables.create {
            }
        }
        
    }
    
    
    
}

#endif


#endif
