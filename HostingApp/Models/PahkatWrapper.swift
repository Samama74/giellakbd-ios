import Foundation
import PahkatClient

final class PahkatWrapper {
    private let store: PrefixPackageStore
    private let storePath = KeyboardSettings.pahkatStoreURL.path
    private let repoURL = "https://x.brendan.so/divvun-pahkat-repo"
    private var downloadTask: URLSessionDownloadTask?
    private let ipc = IPC()
    private var currentDownloadId: String?
    private var installCompletion: (() -> Void)?

    init?() {
        do {
            store = try PrefixPackageStore.create(path: storePath)
        } catch {
            do {
                store = try PrefixPackageStore.open(path: storePath)
            } catch {
                print(error)
                return nil
            }
        }
    }

    func setBackgroundURLSessionCompletion(_ completion: @escaping (() -> Void)) {
        store.backgrounURLSessionCompletion = completion
    }

    func forceRefreshRepos() {
        do {
            try store.forceRefreshRepos()
        } catch {
            print("Error force refreshing repos: \(error)")
        }
    }

    func installSpellersForNewlyEnabledKeyboards() {
        let enabledKeyboards = Bundle.enabledKeyboardBundles
        let packageIds = Set(enabledKeyboards.compactMap { $0.divvunPackageId })
        let packageKeys = packageIds.map { packageKey(from: $0) }
        let notInstalled = packageKeys.filter { tryToGetStatus(for: $0) == .notInstalled }
        downloadAndInstallPackagesSequentially(packageKeys: notInstalled)
    }

    private func tryToGetStatus(for packageKey: PackageKey) -> PackageInstallStatus {
        do {
            return try store.status(for: packageKey)
        } catch {
            fatalError("Error getting status for pahkat package key: \(error)")
        }
    }

    private func packageKey(from packageId: String) -> PackageKey {
        let path = "/packages/\(packageId)?platform=ios"
        return PackageKey(from: URL(string: repoURL + path)!)
    }

    private func downloadAndInstallPackagesSequentially(packageKeys: [PackageKey]) {
        guard packageKeys.isEmpty == false else {
            return
        }

        downloadAndInstallPackage(packageKey: packageKeys[0]) {
            self.downloadAndInstallPackagesSequentially(packageKeys: Array(packageKeys.dropFirst()))
        }
    }

    private func downloadAndInstallPackage(packageKey: PackageKey, completion: (() -> Void)?) {
        print("INSTALLING: \(packageKey)")
        do {
            downloadTask = try store.download(packageKey: packageKey) { (error, _) in
                if let error = error {
                    print(error)
                    return
                }

                self.installCompletion = completion
                let action = TransactionAction.install(packageKey)

                do {
                    let transaction = try self.store.transaction(actions: [action])
                    transaction.process(delegate: self)
                } catch {
                    print(error)
                }
                print("Done!")
            }
            ipc.startDownload(id: packageKey.id)
            currentDownloadId = packageKey.id
        } catch {
            print(error)
        }
    }
}

extension PahkatWrapper: PackageTransactionDelegate {
    func isTransactionCancelled(_ id: UInt32) -> Bool {
        return false
    }

    func transactionWillInstall(_ id: UInt32, packageKey: PackageKey) {
        print(#function, "\(id)")
    }

    func transactionWillUninstall(_ id: UInt32, packageKey: PackageKey) {
        print(#function, "\(id)")
    }

    func transactionDidComplete(_ id: UInt32) {
        if let currentDownloadId = currentDownloadId {
            ipc.finishDownload(id: currentDownloadId)
            self.currentDownloadId = nil
        }
        print(#function, "\(id)")
        installCompletion?()
    }

    func transactionDidCancel(_ id: UInt32) {
        print(#function, "\(id)")
    }

    func transactionDidError(_ id: UInt32, packageKey: PackageKey?, error: Error?) {
        print(#function, "\(id) \(String(describing: error))")
    }

    func transactionDidUnknownEvent(_ id: UInt32, packageKey: PackageKey, event: UInt32) {
        print(#function, "\(id)")
    }
}
