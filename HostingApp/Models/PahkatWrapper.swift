import Foundation
import PahkatClient
import Sentry
import RxSwift

final class PahkatWrapper {
    private let store: PrefixPackageStore
    private let storePath = KeyboardSettings.pahkatStoreURL.path
    private var downloadTask: URLSessionDownloadTask?
    let ipc = IPC()
    var currentDownloadId: String?
    let bag = DisposeBag()

    private var enabledKeyboardPackageKeys: [PackageKey] {
        let enabledKeyboards = Bundle.enabledKeyboardBundles
        let packageKeyStrings = Set(enabledKeyboards.compactMap { $0.spellerPackageKey })
        return packageKeyStrings.compactMap { try? PackageKey.from(url: $0) }
    }

    private var notInstalledKeyboardPackageKeys: [PackageKey] {
        return enabledKeyboardPackageKeys.filter { tryToGetStatus(for: $0) == .notInstalled }
    }

    public var needsInstall: Bool {
        return notInstalledKeyboardPackageKeys.count != 0
    }

    init?() {
        do {
            store = try PrefixPackageStore.create(path: storePath)
        } catch {
            do {
                store = try PrefixPackageStore.open(path: storePath)
            } catch {
                print("Error opening Pahkat PrefixPackageStore: \(error)")
                return nil
            }
        }
    }

    func setBackgroundURLSessionCompletion(_ completion: @escaping (() -> Void)) {
        store.backgroundURLSessionCompletion = completion
    }

    func forceRefreshRepos() {
        do {
            try store.forceRefreshRepos()
        } catch {
            print("Error force refreshing repos: \(error)")
        }
    }

    func installSpellersForNewlyEnabledKeyboards(completion: @escaping ((Error?) -> Void)) {
        let packageKeys = enabledKeyboardPackageKeys

        // Set package repos correctly
        let repoUrls = Set(packageKeys.map { $0.repositoryURL })
        var repoMap = [URL: RepoRecord]()
        for key in repoUrls {
            repoMap[key] = RepoRecord(channel: "nightly")
        }

        do {
            print("Setting repos: \(repoMap)")
            try store.set(repos: repoMap)
            try store.refreshRepos()
        } catch let error {
            // TODO use Sentry to catch this error
            print(error)
            return
        }

        print("Try to get status")
        let updates = packageKeys.filter { tryToGetStatus(for: $0) != .upToDate }

        let bulkDownload = Observable.from(updates)
            .flatMap { key -> Completable in self.downloadPackage(packageKey: key) }
            .toArray()
            .asCompletable()

        bulkDownload
            .andThen(Observable.of(updates)).flatMapLatest { keys -> Completable in
                self.install(packageKeys: keys)
            }.subscribe(
                onNext: { _ in completion(nil) },
                onError: { error in completion(error) })
            .disposed(by: bag)
    }

    private func tryToGetStatus(for packageKey: PackageKey) -> PackageInstallStatus {
        do {
            return try store.status(for: packageKey)
        } catch {
            fatalError("Error getting status for pahkat package key: \(error)")
        }
    }

    private func packageKey(from packageKey: String) -> PackageKey? {
        guard let url = URL(string: packageKey) else { return nil }
        return try? PackageKey.from(url: url)
    }

    private func install(packageKeys: [PackageKey]) -> Completable {
        let actions = packageKeys.map { TransactionAction.install($0) }

        return Completable.create(subscribe: { emitter in
            let delegate = TxDelegate(wrapper: self, callback: { error in
                if let error = error {
                    emitter(.error(error))
                } else {
                    emitter(.completed)
                }
            })

            do {
                let transaction = try self.store.transaction(actions: actions)
                transaction.process(delegate: delegate)
            } catch {
                print(error)
                emitter(.error(error))
            }
            return Disposables.create()
        })
    }

    private func downloadPackage(packageKey: PackageKey) -> Completable {
        return Completable.create(subscribe: { emitter in
            do {
                self.downloadTask = try self.store.download(packageKey: packageKey) { (error, _) in
                    if let error = error {
                        print(error)
                        emitter(.error(error))
                        return
                    }
                    emitter(.completed)
                }
                self.ipc.startDownload(id: packageKey.id)
                self.currentDownloadId = packageKey.id
            } catch {
                print("Pahkat download error: \(error)")
                emitter(.error(error))
            }

            return Disposables.create()
        })
    }
}

class TxDelegate: PackageTransactionDelegate {
    private weak var wrapper: PahkatWrapper?
    private let callback: (Error?) -> Void

    func isTransactionCancelled(_ id: UInt32) -> Bool {
        return false
    }

    func transactionWillInstall(_ id: UInt32, packageKey: PackageKey?) {
        print(#function, "\(id)")
    }

    func transactionWillUninstall(_ id: UInt32, packageKey: PackageKey?) {
        print(#function, "\(id)")
    }

    func transactionDidComplete(_ id: UInt32) {
        if let currentDownloadId = wrapper?.currentDownloadId {
            wrapper?.ipc.finishDownload(id: currentDownloadId)
            wrapper?.currentDownloadId = nil
        }
        print(#function, "\(id)")
//        installCompletion(nil)
        callback(nil)
    }

    func transactionDidCancel(_ id: UInt32) {
        print(#function, "\(id)")
//        installCompletion(nil)
        callback(nil)
    }

    func transactionDidError(_ id: UInt32, packageKey: PackageKey?, error: Error?) {
        print(#function, "\(id) \(String(describing: error))")
        callback(error)
    }

    func transactionDidUnknownEvent(_ id: UInt32, packageKey: PackageKey?, event: UInt32) {
        print(#function, "\(id)")
    }

    init(wrapper: PahkatWrapper, callback: @escaping (Error?) -> Void) {
        self.wrapper = wrapper
        self.callback = callback
    }
}
