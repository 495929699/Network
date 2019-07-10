import Foundation
import RxSwift
import Moya

#if canImport(UIKit)
    import UIKit.UIImage
#elseif canImport(AppKit)
    import AppKit.NSImage
#endif

// MARK: - 解析 Response
extension ObservableType where E == Response {
    /// 将 Response -> Result<Value>
    func map<T>(_ dataKey : String, _ codeKey: String, _ messageKey: String, _ successCode: Int) -> Observable<NetworkResult<T>> where T : Codable {
        return self.map({ response in
            guard let code = try? response.map(Int.self, atKeyPath: codeKey) else {
                let error = "服务器code解析错误\n\(String(data: response.data, encoding: .utf8) ?? "")"
                return .failure(.error(value: error))
            }
            guard code == successCode else {
                handleServiceCode(code)
                let message = (try? response.map(String.self, atKeyPath: messageKey)) ?? "code不等于\(successCode)"
                return .failure(.service(code: code, message: message))
            }
            do {
                let data = try response.map(T.self, atKeyPath: dataKey)
                return .success(data)
            } catch let error {
                return .failure(.error(value: "请求成功，但data解析错误\nerror: \(error)"))
            }
        })
    }
    
    /// 将 Response -> Result<Void>
    func map(_ codeKey: String, _ messageKey: String, _ successCode: Int) -> Observable<NetworkResult<Void>> {
        return self.map({ response in
            guard let code = try? response.map(Int.self, atKeyPath: codeKey) else {
                let error = "服务器code解析错误\n\(String(data: response.data, encoding: .utf8) ?? "")"
                return .failure(.error(value: error))
            }
            guard code == successCode else {
                handleServiceCode(code)
                let message = (try? response.map(String.self, atKeyPath: messageKey)) ?? "code不等于\(successCode)"
                return .failure(.service(code: code, message: message))
            }
            
            return .success(())
        })
    }
}

/// 处理服务器Code
private func handleServiceCode(_ code: Int) {
    switch code {
    case 401:
        NotificationCenter.default.post(name: .networkService_401, object: nil)
        
    default: break
    }
}

// MARK: - Extension for processing raw NSData generated by network access
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
