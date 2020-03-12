import UIKit
import RxSwift
import RxCocoa


class ViewController: UIViewController {

    private var disposeBag = DisposeBag()

   override func viewDidLoad() {
       super.viewDidLoad()
   }

    @IBAction func onStart(_ sender: Any) {
        disposeBag = DisposeBag()
        
        getUserID().flatMapLatest { value -> Completable in
            assert(Thread.isMainThread)
            return API.save(userID: value, timeout: 5)
        }
        .subscribeOn(MainScheduler.instance)
        .subscribe { event in
            print(event)
        }
        .disposed(by: disposeBag)
    }

    @IBAction func onStop(_ sender: Any) {
        disposeBag = DisposeBag()
    }
       
}

class Foobar { // A dummy class
    public let v: Int
    init(_ v: Int) {
        self.v = v
    }
    deinit {
        assert(Thread.isMainThread)
        print("Foobar deinit")
    }
}

func getUserID() -> Observable<Int> {
    let obj = Foobar(23)
    return Observable.just(42).map {  obj.v + $0 }
}




struct API {
    
    // Wrap network call in an observable
    static func save(userID: Int, timeout: Int) -> Completable {

        return Completable.create { completion -> Disposable in

            NetworkLibrary.saveIntAsync(value: userID, timeout: timeout) { result in
                // assert(Thread.isMainThread) Not main thread here

                // Foobar instance will be deleted when completion is called here!
                // So, if we want Foobar to be deinited on main thread, we need to DispatchQueue.main.async here!
                switch result {
                case .success:
                    completion(.completed)
                case .failure(let error):
                    completion(.error(error))
                }
            }
            
            let dis =  Disposables.create {
                // assert(Thread.isMainThread) Not main thread here
                print("save int observeable disposed")
            }

            return dis
        }
        .observeOn(MainScheduler.instance)
    }
}

struct NetworkLibrary {
    // Some network library that performs work on background thread.
    // We have no control of on what thread the completion block will execute on
    static func saveIntAsync(value: Int, timeout: Int, completion: @escaping (Result<Void, Error>)->Void) {
        print("NetworkLibrary: Will save int: \(value)")
        DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + .seconds(timeout)) {
            // Call completion on background thread
            completion(.success(()))
        }
    }
}
