import Foundation
import Result

private var taskRequestKey = 0

/// `Session` manages tasks for HTTP/HTTPS requests.
open class Session {
    /// The adapter that connects `Session` instance and lower level backend.
    public let adapter: SessionAdapter

    /// The default callback queue for `send(_:handler:)`.
    public let callbackQueue: CallbackQueue

    /// Returns `Session` instance that is initialized with `adapter`.
    /// - parameter adapter: The adapter that connects lower level backend with Session interface.
    /// - parameter callbackQueue: The default callback queue for `send(_:handler:)`.
    public init(adapter: SessionAdapter, callbackQueue: CallbackQueue = .main) {
        self.adapter = adapter
        self.callbackQueue = callbackQueue
    }

    // Shared session for class methods
    private static let privateSharedSession: Session = {
        let configuration = URLSessionConfiguration.default
        let adapter = URLSessionAdapter(configuration: configuration)
        return Session(adapter: adapter)
    }()

    /// The shared `Session` instance for class methods, `Session.send(_:handler:)` and `Session.cancelRequests(withType:passingTest:)`.
    open class var sharedSession: Session {
        return privateSharedSession
    }

    /// Calls `send(_:handler:)` of `sharedSession`.
    /// - parameter request: The request to be sent.
    /// - parameter callbackQueue: The queue where the handler runs. If this parameters is `nil`, default `callbackQueue` of `Session` will be used.
    /// - parameter handler: The closure that receives result of the request.
    /// - returns: The new session task.
    @discardableResult
    open class func send<Req: Request>(_ request: Req, callbackQueue: CallbackQueue? = nil, handler: @escaping (Result<Req.Response, SessionTaskError>) -> Void = { _ in }) -> SessionTaskType? {
        return sharedSession.send(request, callbackQueue: callbackQueue, handler: handler)
    }

    /// Calls `cancelRequests(withType:passingTest:)` of `sharedSession`.
    open class func cancelRequests<Req: Request>(withType requestType: Req.Type, passingTest test: @escaping (Req) -> Bool = { _ in true }) {
        sharedSession.cancelRequests(withType: requestType, passingTest: test)
    }

    /// Sends a request and receives the result as the argument of `handler` closure. This method takes
    /// a type parameter `Request` that conforms to `Request` protocol. The result of passed request is
    /// expressed as `Result<Request.Response, SessionTaskError>`. Since the response type
    /// `Request.Response` is inferred from `Request` type parameter, the it changes depending on the request type.
    /// - parameter request: The request to be sent.
    /// - parameter callbackQueue: The queue where the handler runs. If this parameters is `nil`, default `callbackQueue` of `Session` will be used.
    /// - parameter handler: The closure that receives result of the request.
    /// - returns: The new session task.
    @discardableResult
    open func send<Req: Request>(_ request: Req, callbackQueue: CallbackQueue? = nil, handler: @escaping (Result<Req.Response, SessionTaskError>) -> Void = { _ in }) -> SessionTaskType? {
        let callbackQueue = callbackQueue ?? self.callbackQueue

        let urlRequest: URLRequest
        do {
            urlRequest = try request.buildURLRequest()
        } catch {
            callbackQueue.execute {
                handler(.failure(.requestError(error)))
            }
            return nil
        }

        let task = adapter.createTask(with: urlRequest) { data, urlResponse, error in
            let result: Result<Req.Response, SessionTaskError>

            switch (data, urlResponse, error) {
            case (_, _, let error?):
                result = .failure(.connectionError(error))

            case (let data?, let urlResponse as HTTPURLResponse, _):
                do {
                    result = .success(try request.parse(data: data as Data, urlResponse: urlResponse))
                } catch {
                    result = .failure(.responseError(error))
                }

            default:
                result = .failure(.responseError(ResponseError.nonHTTPURLResponse(urlResponse)))
            }

            callbackQueue.execute {
                handler(result)
            }
        }

        setRequest(request, forTask: task)
        task.resume()

        return task
    }

    /// Cancels requests that passes the test.
    /// - parameter requestType: The request type to cancel.
    /// - parameter test: The test closure that determines if a request should be cancelled or not.
    open func cancelRequests<Req: Request>(withType requestType: Req.Type, passingTest test: @escaping (Req) -> Bool = { _ in true }) {
        adapter.getTasks { [weak self] tasks in
            return tasks
                .filter { task in
                    if let request = self?.requestForTask(task) as Req? {
                        return test(request)
                    } else {
                        return false
                    }
                }
                .forEach { $0.cancel() }
        }
    }

    private func setRequest<Req: Request>(_ request: Req, forTask task: SessionTaskType) {
        objc_setAssociatedObject(task, &taskRequestKey, request, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func requestForTask<Req: Request>(_ task: SessionTaskType) -> Req? {
        return objc_getAssociatedObject(task, &taskRequestKey) as? Req
    }
}
