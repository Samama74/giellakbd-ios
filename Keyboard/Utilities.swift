//
//  Utilities.swift
//  TastyImitationKeyboard
//
//  Created by Alexei Baboulevitch on 10/22/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import Foundation
import UIKit

// from https://gist.github.com/berkus/8a9e104f8aac5d025eb5
//func memoize<T: Hashable, U>( body: ( (T)->U, T ) -> U ) -> (T) -> U {
//    var memo = Dictionary<T, U>()
//    var result: ((T)->U)!
//    
//    result = { x in
//        if let q = memo[x] { return q }
//        let r = body(result, x)
//        memo[x] = r
//        return r
//    }
//    
//    return result
//}

//func memoize<S:Hashable, T:Hashable, U>(fn : (S, T) -> U) -> (S, T) -> U {
//    var cache = Dictionary<FunctionParams<S,T>, U>()
//    func memoized(val1 : S, val2: T) -> U {
//        let key = FunctionParams(x: val1, y: val2)
//        if cache.indexForKey(key) == nil {
//            cache[key] = fn(val1, val2)
//        }
//        return cache[key]!
//    }
//    return memoized
//}

func memoize<T:Hashable, U>(_ fn : @escaping (T) -> U) -> (T) -> U {
    var cache = [T:U]()
    return {
        (val : T) -> U in
        let value = cache[val]
        if value != nil {
            return value!
        } else {
            let newValue = fn(val)
            cache[val] = newValue
            return newValue
        }
    }
}

//let fibonacci = memoize {
//    fibonacci, n in
//    n < 2 ? Double(n) : fibonacci(n-1) + fibonacci(n-2)
//}

//func memoize<T:Hashable, U>(fn : T -> U) -> (T -> U) {
//    var cache = Dictionary<T, U>()
//    func memoized(val : T) -> U {
//        if !cache.indexForKey(val) {
//            cache[val] = fn(val)
//        }
//        return cache[val]!
//    }
//    return memoized
//}

var profile: ((_ id: String) -> Double?) = {
    var counterForName = Dictionary<String, Double>()
    var isOpen = Dictionary<String, Double>()
    
    return { (id: String) -> Double? in
        if let startTime = isOpen[id] {
            let diff = CACurrentMediaTime() - startTime
            if let currentCount = counterForName[id] {
                counterForName[id] = (currentCount + diff)
            }
            else {
                counterForName[id] = diff
            }
            
            isOpen[id] = nil
        }
        else {
            isOpen[id] = CACurrentMediaTime()
        }
        
        return counterForName[id]
    }
}()

// From https://stackoverflow.com/a/52821290
public extension UIDevice {
    
    public var isXFamily: Bool {
        return [UIDevice.Kind.iPhone_X_Xs,UIDevice.Kind.iPhone_Xr,UIDevice.Kind.iPhone_Xs_Max].contains(self.kind)
    }
    
    public enum Kind {
        case iPad
        case iPhone_unknown
        case iPhone_5_5S_5C
        case iPhone_6_6S_7_8
        case iPhone_6_6S_7_8_PLUS
        case iPhone_X_Xs
        case iPhone_Xs_Max
        case iPhone_Xr
    }
    
    public var kind: Kind {
        if userInterfaceIdiom == .phone {
            switch UIScreen.main.nativeBounds.height {
            case 1136:
                return .iPhone_5_5S_5C
            case 1334:
                return .iPhone_6_6S_7_8
            case 1920, 2208:
                return .iPhone_6_6S_7_8_PLUS
            case 2436:
                return .iPhone_X_Xs
            case 2688:
                return .iPhone_Xs_Max
            case 1792:
                return .iPhone_Xr
            default:
                return .iPhone_unknown
            }
        }
        return .iPad
    }
}

extension UIView {
    func fillSuperview(_ other: UIView, margins: UIEdgeInsets = .zero) {
        leftAnchor.constraint(equalTo: other.leftAnchor, constant: margins.left).isActive = true
        rightAnchor.constraint(equalTo: other.rightAnchor, constant: -margins.right).isActive = true
        topAnchor.constraint(equalTo: other.topAnchor, constant: margins.top).isActive = true
        bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -margins.bottom).isActive = true
    }
}

class SystemKeys {
    static func systemKeyRowsForCurrentDevice(spaceName: String, returnName: String) -> [KeyDefinition] {
        var keys = [KeyDefinition]()
        
        keys.append(KeyDefinition(type: .symbols))
        keys.append(KeyDefinition(type: .keyboard))
        keys.append(KeyDefinition(type: .spacebar(name: spaceName), size: CGSize(width: 5.0, height: 1.0)))
        keys.append(KeyDefinition(type: .returnkey(name: returnName), size: CGSize(width: 2.0, height: 1.0)))
        
        return keys
    }
    
    static var symbolKeysFirstPage: [[KeyDefinition]] {
        let currencySign = "kr"
        return [
            [
                "1",
                "2",
                "3",
                "4",
                "5",
                "6",
                "7",
                "8",
                "9",
                "0"
                ].compactMap { KeyDefinition(input: $0) },
            
            [
                "-",
                "/",
                ":",
                ";",
                "(",
                ")",
                currencySign,
                "&",
                "@",
                "\""
                ].compactMap { KeyDefinition(input: $0) },
            
            ([
                KeyDefinition(type: .shiftSymbols, size: CGSize(width: 0.9, height: 1.0)),
                KeyDefinition(type: .spacer, size: CGSize(width: 0.1, height: 1.0))
                ]
                +
                [
                    ".",
                    ",",
                    "?",
                    "!",
                    "'",
                    ].compactMap { KeyDefinition(input: $0) }
                +
                [
                    KeyDefinition(type: .spacer, size: CGSize(width: 0.1, height: 1.0)),
                    KeyDefinition(type: .backspace, size: CGSize(width: 0.9, height: 1.0))
                ])
        ]
    }
    
    static var symbolKeysSecondPage: [[KeyDefinition]] {
        return [
            [
                "[",
                "]",
                "{",
                "}",
                "#",
                "%",
                "^",
                "*",
                "+",
                "="
                ].compactMap { KeyDefinition(input: $0) },
            
            [
                "_",
                "\\",
                "|",
                "~",
                "<",
                "?",
                "€",
                "$",
                "£",
                "•"
                ].compactMap { KeyDefinition(input: $0) },
            
            ([
                KeyDefinition(type: .shiftSymbols, size: CGSize(width: 0.9, height: 1.0)),
                KeyDefinition(type: .spacer, size: CGSize(width: 0.1, height: 1.0))
                ]
                +
                [
                    ".",
                    ",",
                    "?",
                    "!",
                    "'",
                    ].compactMap { KeyDefinition(input: $0) }
                +
                [
                    KeyDefinition(type: .spacer, size: CGSize(width: 0.1, height: 1.0)),
                    KeyDefinition(type: .backspace, size: CGSize(width: 0.9, height: 1.0))
                ])
        ]
    }
    
}
