//
//  NPOManager.swift
//  NPOKit
//
//  Created by Jeroen Wesbeek on 13/07/16.
//  Copyright © 2016 Jeroen Wesbeek. All rights reserved.
//

import Foundation
import Alamofire
import AlamofireImage
import RealmSwift
import CocoaLumberjack

public enum Watched: Int {
    case Unwatched
    case Partially
    case Fully
}

public enum NPOError: ErrorType {
    case ModelMappingError(String)//, JSON)
    case TokenError(String)
    case NetworkError(String)
    case NoImageError
    case NoMIDError
    case NoEpisodeError
}

public enum NPOGenre: String {
    case Amusement = "Amusement"
    case Crime = "Misdaad"
    case Cultural = "Kunst/Cultuur"
    case Comedy = "Comedy"
    case Documentary = "Documentaire"
    case Drama = "Drama"
    case Film = "Film"
    case Health = "Gezondheid"
    case Informative = "Informatief"
    case Music = "Muziek"
    case Nature = "Natuur"
    case News = "Nieuws/actualiteiten"
    case Religious = "Religieus"
    case Series = "Serie/soap"
    case Sport = "Sport"
    case Youth = "Jeugd"
    
    static let all = [Amusement, Crime, Cultural, Comedy, Documentary, Drama, Film, Health, Informative, Music, Nature, News, Religious, Series, Sport, Youth]
}

public enum NPOBroadcaster: String {
    case VARA = "VARA"
    case NOS = "NOS"
    case KRO = "KRO"
    case NCRV = "NCRV"
    case KRONCRV = "KRO-NCRV"
    case AVRO = "AVRO"
    case TROS = "TROS"
    case AVROTROS = "AVROTROS"
    case BNN = "BNN"
    case EO = "EO"
    case HUMAN = "HUMAN"
    case IKON = "IKON"
    case MAX = "MAX"
    case NTR = "NTR"
    case NPS = "NPS"
    case OHM = "OHM"
    case VPRO = "VPRO"
    case WNL = "WNL"
    case PowNed = "PowNed"
    case BOS = "BOS"
    case ZAPP = "NPO Zapp"
    case ZAPPELIN = "NPO Zappelin"
    case JoodseOmroep = "Joodse Omroep"
    
    static let all = [VARA, NOS, KRO, NCRV, KRONCRV, AVRO, TROS, AVROTROS, BNN, EO, HUMAN, IKON, MAX, NTR, NPS, OHM, VPRO, WNL, PowNed, BOS, JoodseOmroep, ZAPP, ZAPPELIN]
}

public class NPOManager {
    public static let sharedInstance = NPOManager()
    internal let baseURL = "http://apps-api.uitzendinggemist.nl"
    private let infoDictionary = NSBundle.mainBundle().infoDictionary
    
    //MARK: Init
    
    init() {
        upgradeIfNeeded()
    }
    
    //swiftlint:disable force_unwrapping
    private func upgradeIfNeeded() {
        Realm.Configuration.defaultConfiguration = Realm.Configuration(
            // Set the new schema version. This must be greater than the previously used
            // version (if you've never set a schema version before, the version is 0).
            schemaVersion: 1,
            
            // Set the block which will be called automatically when opening a Realm with
            // a schema version lower than the one set above
            migrationBlock: { migration, oldSchemaVersion in
                // We haven’t migrated anything yet, so oldSchemaVersion == 0
                if oldSchemaVersion < 1 {
                    DDLogDebug("Performing schema upgrade \(oldSchemaVersion) to 1")
                    
                    // migrate NPOProgram object
                    migration.enumerate(RealmProgram.className()) { oldObject, newObject in
                        newObject!["watched"] = Watched.Unwatched.rawValue
                    }
                
                    // migrate NPOEpisode object
                    migration.enumerate(RealmEpisode.className()) { oldObject, newObject in
                        if let watched = oldObject!["watched"] as? Bool, watchDuration = oldObject!["watchDuration"] as? Int {
                            if watched {
                                newObject!["watched"] = Watched.Fully.rawValue
                            } else if watchDuration > 59 {
                                newObject!["watched"] = Watched.Partially.rawValue
                            } else {
                                newObject!["watched"] = Watched.Unwatched.rawValue
                            }
                        } else {
                            newObject!["watched"] = Watched.Unwatched.rawValue
                        }
                    }
                }
        })

        // Realm will automatically perform the migration and opening the Realm will succeed
        do {
            let _ = try Realm()
        } catch let error as NSError {
            DDLogError("Realm schema upgrade error (\(error.localizedDescription))")
        }
    }
    //swiftlint:enable force_unwrapping
    
    //MARK: Get url
    
    internal func getURL(forPath path: String) -> String {
        return "\(self.baseURL)/\(path)"
    }
    
    //MARK: Request headers
    
    internal func getHeaders() -> [String:String] {
        return [
            //"User-Agent"        : "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_5) AppleWebKit/601.2.7 (KHTML, like Gecko) Version/9.0.1 Safari/601.2.7",
            "DNT"               : "1",
            "Accept-Encoding"   : "gzip, deflate, sdch",
            "Accept"            : "*/*",
            "X-UitzendingGemist-Version"        : (infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"),
            "X-UitzendingGemist-Source"         : "https://github.com/4np/NPOKit",
            "X-UitzendingGemist-Platform"       : (infoDictionary?["DTSDKName"] as? String ?? "unknown"),
            "X-UitzendingGemist-PlatformVersion": (infoDictionary?["DTPlatformVersion"] as? String ?? "unknown")
        ]
    }

    //MARK: Image caching
    
    lazy internal var imageCache: AutoPurgingImageCache = {
        let imageCache = AutoPurgingImageCache(
            memoryCapacity: 500 * 1024 * 1024,
            preferredMemoryUsageAfterPurge: 120 * 1024 * 1024
        )
        //DDLogDebug("memory usage: \(imageCache.memoryUsage), capacity: \(imageCache.memoryCapacity), prefered after purge: \(imageCache.preferredMemoryUsageAfterPurge)")
        return imageCache
    }()
}
