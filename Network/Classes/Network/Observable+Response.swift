import Foundation
import RxSwift
import Moya

#if canImport(UIKit)
    import UIKit.UIImage
#elseif canImport(AppKit)
    import AppKit.NSImage
#endif

// MARK: - 对 Response 序列扩展，转成Result<T,Error>
extension ObservableType where E == Response {
    
    /// 将内容 map成 Result<T,NetworkError>
    public func mapResult<T : Codable>(dataKey : String, codeKey : String,
                                       messageKey : String, successCode : Int)
        -> NetworkObservable<T> {
            
            let errorHandle : (Response) -> NetworkObservable<T> = { response in
                let error = String(data: response.data, encoding: .utf8) ?? "没有错误信息"
                return .just(.failure(.error(value: error)))
            }
            
            return self
                .do(onNext: { handleCode(codeKey, response: $0) })
                .flatMap({ response -> NetworkObservable<T> in
                    guard let code = try? response.map(Int.self, atKeyPath: codeKey) else {
                        return errorHandle(response)
                    }
                    guard code == successCode else {
                        let message = (try? response.map(String.self, atKeyPath: messageKey)) ?? ""
                        return .just(.failure(.service(code: code, message: message)))
                    }
                    guard let data = try? response.map(T.self, atKeyPath: dataKey) else {
                        return errorHandle(response)
                    }
                    
                    return .just(.success(data))
                })
                .catchError({ .just(.failure(.network(value: $0))) })
    }
    
    /// 将内容 map成 Result<Void,NetworkError>
    public func mapSuccess(codeKey : String, messageKey : String, successCode : Int)
        -> NetworkVoidObservable {
            return self
                .do(onNext: { handleCode(codeKey, response: $0) })
                .flatMap({ response -> NetworkVoidObservable in
                    guard let code = try? response.map(Int.self, atKeyPath: codeKey) else {
                        let error = String(data: response.data, encoding: .utf8) ?? "没有错误信息"
                        return .just(.failure(.error(value: error)))
                    }
                    guard code == successCode else {
                        let message = (try? response.map(String.self, atKeyPath: messageKey)) ?? ""
                        return .just(.failure(.service(code: code, message: message)))
                    }
                    
                    return .just(.success(()))
                })
                .catchError({ .just(.failure(.network(value: $0))) })
    }
    
}

/// 处理服务器Code
private func handleCode(_ codeKey : String, response : Response) {
    guard let code = try? response.map(Int.self, atKeyPath: codeKey) else { return }
    switch code {
    case 401:
        NotificationCenter.default.post(name: .networkService_401, object: nil)
        
    default: break
    }
}



/// Extension for processing raw NSData generated by network access.
extension ObservableType where E == Response {

    /// Filters out responses that don't fall within the given range, generating errors when others are encountered.
    public func filter<R: RangeExpression>(statusCodes: R) -> Observable<E> where R.Bound == Int {
        return flatMap { Observable.just(try $0.filter(statusCodes: statusCodes)) }
    }

    /// Filters out responses that has the specified `statusCode`.
    public func filter(statusCode: Int) -> Observable<E> {
        return flatMap { Observable.just(try $0.filter(statusCode: statusCode)) }
    }

    /// Filters out responses where `statusCode` falls within the range 200 - 299.
    public func filterSuccessfulStatusCodes() -> Observable<E> {
        return flatMap { Observable.just(try $0.filterSuccessfulStatusCodes()) }
    }

    /// Filters out responses where `statusCode` falls within the range 200 - 399
    public func filterSuccessfulStatusAndRedirectCodes() -> Observable<E> {
        return flatMap { Observable.just(try $0.filterSuccessfulStatusAndRedirectCodes()) }
    }

    /// Maps data received from the signal into an Image. If the conversion fails, the signal errors.
    public func mapImage() -> Observable<Image> {
        return flatMap { Observable.just(try $0.mapImage()) }
    }

    /// Maps data received from the signal into a JSON object. If the conversion fails, the signal errors.
    public func mapJSON(failsOnEmptyData: Bool = true) -> Observable<Any> {
        return flatMap { Observable.just(try $0.mapJSON(failsOnEmptyData: failsOnEmptyData)) }
    }

    /// Maps received data at key path into a String. If the conversion fails, the signal errors.
    public func mapString(atKeyPath keyPath: String? = nil) -> Observable<String> {
        return flatMap { Observable.just(try $0.mapString(atKeyPath: keyPath)) }
    }

    /// Maps received data at key path into a Decodable object. If the conversion fails, the signal errors.
    public func map<D: Decodable>(_ type: D.Type, atKeyPath keyPath: String? = nil, using decoder: JSONDecoder = JSONDecoder(), failsOnEmptyData: Bool = true) -> Observable<D> {
        return flatMap { Observable.just(try $0.map(type, atKeyPath: keyPath, using: decoder, failsOnEmptyData: failsOnEmptyData)) }
    }
}

extension ObservableType where E == ProgressResponse {

    /**
     Filter completed progress response and maps to actual response

     - returns: response associated with ProgressResponse object
     */
    public func filterCompleted() -> Observable<Response> {
        return self
            .filter { $0.completed }
            .flatMap { progress -> Observable<Response> in
                // Just a formatlity to satisfy the compiler (completed progresses have responses).
                switch progress.response {
                case .some(let response): return .just(response)
                case .none: return .empty()
                }
            }
    }

    /**
     Filter progress events of current ProgressResponse

     - returns: observable of progress events
     */
    public func filterProgress() -> Observable<Double> {
        return self.filter { !$0.completed }.map { $0.progress }
    }
}