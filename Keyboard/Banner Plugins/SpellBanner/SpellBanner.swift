import Foundation
import Sentry
import DivvunSpell

protocol SpellBannerDelegate: class {
    var hasFullAccess: Bool { get }
    func didSelectSuggestion(banner: SpellBanner, text: String)
}

public final class SpellBanner: Banner {
    let bannerView: SpellBannerView
    lazy var suggestionService = SuggestionService(banner: self)

    weak var delegate: SpellBannerDelegate?

    var view: UIView {
        bannerView
    }

    fileprivate var dictionaryService: UserDictionaryService?
    fileprivate var archive: ThfstChunkedBoxSpellerArchive?
    fileprivate var speller: ThfstChunkedBoxSpeller? {
        return try? archive?.speller()
    }

    init(theme: ThemeType) {
        self.bannerView = SpellBannerView(theme: theme)
        bannerView.delegate = self

        loadBHFST()
    }

    public func setContext(_ context: CursorContext) {
        if let delegate = delegate,
            delegate.hasFullAccess {
            dictionaryService?.updateContext(WordContext(cursorContext: context))
        }

        let currentWord = context.current.1

        if currentWord.isEmpty {
            bannerView.setBannerItems([])
            return
        }

        suggestionService.getSuggestionsFor(currentWord) { (suggestions) in
            let suggestionItems = self.makeSuggestionBannerItems(currentWord: currentWord, suggestions: suggestions)
            self.bannerView.isHidden = false
            self.bannerView.setBannerItems(suggestionItems)
        }
    }

    private func makeSuggestionBannerItems(currentWord: String, suggestions: [String]) -> [SpellBannerItem] {
        var suggestions = suggestions
        // Don't show the current word twice; it will always be shown in the banner item created below
        suggestions.removeAll { $0 == currentWord }
        let suggestionItems = suggestions.map { SpellBannerItem(title: $0, value: $0) }

        let currentWordItem = SpellBannerItem(title: "\"\(currentWord)\"", value: currentWord)

        return [currentWordItem] + suggestionItems
    }

    func updateTheme(_ theme: ThemeType) {
        bannerView.updateTheme(theme: theme)
    }

    private func getPrimaryLanguage() -> String? {
        if let extensionInfo = Bundle.main.infoDictionary!["NSExtension"] as? [String: AnyObject] {
            if let attrs = extensionInfo["NSExtensionAttributes"] as? [String: AnyObject] {
                if let lang = attrs["PrimaryLanguage"] as? String {
                    return String(lang.split(separator: "-")[0])
                }
            }
        }

        return nil
    }

    private func loadBHFST() {
        print("Loading speller…")

        DispatchQueue.global(qos: .background).async {
            print("Dispatching request to load speller…")

            guard let bundle = Bundle.top.url(forResource: "dicts", withExtension: "bundle") else {
                print("No dict bundle found; BHFST not loaded.")
                return
            }

            guard let lang = self.getPrimaryLanguage() else {
                print("No primary language found for keyboard; BHFST not loaded.")
                return
            }

            let path = bundle.appendingPathComponent("\(lang).bhfst")

            if !FileManager.default.fileExists(atPath: path.path) {
                print("No speller at: \(path)")
                print("DivvunSpell **not** loaded.")
                return
            }

            do {
                self.archive = try ThfstChunkedBoxSpellerArchive.open(path: path.path)
                print("DivvunSpell loaded!")
            } catch {
                let error = Sentry.Event(level: .error)
                Client.shared?.send(event: error, completion: nil)
                print("DivvunSpell **not** loaded.")
                return
            }

            #if ENABLE_USER_DICTIONARY
            do {
                if let speller = try self.archive?.speller() {
                    self.dictionaryService = UserDictionaryService(speller: speller, locale: KeyboardLocale.current)
                }
            } catch {
                let error = Sentry.Event(level: .error)
                Client.shared?.send(event: error, completion: nil)
                print("DivvunSpell UserDictionaryService **not** loaded.")
                return
            }
            #endif
        }
    }
}

extension SpellBanner: SpellBannerViewDelegate {
    public func didSelectBannerItem(_ banner: SpellBannerView, item: SpellBannerItem) {
        delegate?.didSelectSuggestion(banner: self, text: item.value)
        suggestionService.cancelAllOperations()

        banner.setBannerItems([])
    }
}

typealias SuggestionCompletion = ([String]) -> Void

final class SuggestionService {
    let banner: SpellBanner
    let opQueue: OperationQueue = {
        let opQueue = OperationQueue()
        opQueue.underlyingQueue = DispatchQueue.global(qos: .userInteractive)
        opQueue.maxConcurrentOperationCount = 1
        return opQueue
    }()

    init(banner: SpellBanner) {
        self.banner = banner
    }

    public func getSuggestionsFor(_ word: String, completion: @escaping SuggestionCompletion) {
        cancelAllOperations()
        let suggestionOp = SuggestionOperation(banner: banner, word: word, completion: completion)
        opQueue.addOperation(suggestionOp)
    }

    public func cancelAllOperations() {
        opQueue.cancelAllOperations()
    }
}

final class SuggestionOperation: Operation {
    weak var banner: SpellBanner?
    let word: String
    let completion: SuggestionCompletion

    init(banner: SpellBanner, word: String, completion: @escaping SuggestionCompletion) {
        self.banner = banner
        self.word = word
        self.completion = completion
    }

    override func main() {
        if isCancelled {
            return
        }

        let suggestions = getSuggestions(for: word)
        if !isCancelled {
            DispatchQueue.main.async {
                self.completion(suggestions)
            }
        }
    }

    private func getSuggestions(for word: String) -> [String] {
        var suggestions: [String] = []

        if let dictionary = self.banner?.dictionaryService?.dictionary {
            let userSuggestions = dictionary.getSuggestions(for: word)
            suggestions.append(contentsOf: userSuggestions)
        }

        if let speller = self.banner?.speller {
            let spellerSuggestions = (try? speller
                .suggest(word: word)
                .prefix(3)) ?? []
            suggestions.append(contentsOf: spellerSuggestions)
        }

        return suggestions
    }
}
