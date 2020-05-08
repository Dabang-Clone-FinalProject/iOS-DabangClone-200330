//
//  APIManager.swift
//  DabangClone
//
//  Created by SEONGJUN on 2020/04/24.
//  Copyright © 2020 pandaman. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import KeychainSwift

enum LoginWays {
    case local
    case apple
    case kakao
    case facebook
}

enum Key {
    static let keyChain = "keyChain"
}

final class APIManager {
    
    // MARK: - Properties
    static let shared = APIManager()
    
    private let keyChain = KeychainSwift(keyPrefix: "DabangCloneUser_")
    var userPk = 0
    private let networkAccessManager = NetworkReachabilityManager(host: "http://dabang-loadbalancer-779366673.ap-northeast-2.elb.amazonaws.com")
    private let baseURL = "http://dabang-loadbalancer-779366673.ap-northeast-2.elb.amazonaws.com"
    
    var loginWay: LoginWays?
    
    private init() { monitorNetworkAccessStatus() }
    
    
    // MARK: - [ Monitoring Celluar Network Access Status ]
    private func monitorNetworkAccessStatus() {
        networkAccessManager?.startListening(onQueue: .init(label: "networkQueue"), onUpdatePerforming: { (status) in
            print("Network Status has been changed: \(status)")
        })
    }
    
    
    // MARK: - [ Manage JWT ]
    func getAccessTokenFromKeyChain() -> String {
        let accessToken = keyChain.get(Key.keyChain) ?? ""
        return accessToken
    }
    
    func setAccessTokenIntoKeyChain(token: String, key: String) -> Bool {
        return keyChain.set(token, forKey: key, withAccess: .accessibleWhenUnlocked)
    }
    
    func checkJWTExpiration() {
        let jwt = getAccessTokenFromKeyChain()
        var payloadString = jwt.components(separatedBy: ".")[1]
        while payloadString.count % 4 != 0 {
            payloadString += "="
        }

        let payloadData = Data(base64Encoded: payloadString, options: .ignoreUnknownCharacters)!

        guard let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String:Any] else { return }
        let exp = json["exp"] as! Int
        let expDate = Date(timeIntervalSince1970: TimeInterval(exp))
        if expDate <= Date() {
            refreshJWT()
        }
    }

    func refreshJWT() {

    }
    
    // MARK: - [ API CRUD ]

    // MARK: - GET
    
    //GET: 유저 정보
    func getUserProfile(completion: @escaping (Result<User, Error>) -> Void) {
        let header: HTTPHeaders = [.authorization(bearerToken: getAccessTokenFromKeyChain())]
        AF.request( baseURL + "/members/\(userPk)/", headers: header)
            .responseDecodable(of: User.self) { (response) in
                switch response.result {
                case .success(let user):
                    completion(.success(user))
                case .failure(let error):
                    completion(.failure(error))
                }
        }
    }
    
    //GET: 방 전체 리스트
    func getEntireRoomData(completion: @escaping (Result<[DabangElement], Error>) -> Void) {
        AF.request( baseURL + "/posts/list/")
          .responseDecodable(of: [DabangElement].self) { (response) in
                switch response.result {
                case .success(let rooms):
                    completion(.success(rooms))
                case .failure(let error):
                    completion(.failure(error))
                }
        }
    }
    
    //GET: pk를 기준으로 특정 방 1개
    func getCertainRoomData(pk: Int, completion: @escaping (Result<DabangElement, Error>) -> Void) {
        let parameter = ["pk" : pk]
        AF.request( baseURL + "/posts/list/", parameters: parameter)
            .responseDecodable(of: DabangElement.self) { (response) in
                switch response.result {
                case .success(let room):
                    completion(.success(room))
                case .failure(let error):
                    completion(.failure(error))
                }
        }
    }
    
    //GET: 최근 본 방 리스트
    func getRecentlyCheckedRooms(userPK: Int, completion: @escaping (Result<[DabangElement], Error>) -> Void) {
        let header: HTTPHeaders = [.authorization(bearerToken: getAccessTokenFromKeyChain())]
        AF.request( baseURL + "/members/\(userPK)/", method: .get, headers: header)
          .responseDecodable(of: User.self) { (response) in
                switch response.result {
                case .success(let user):
                    completion(.success(user.recentlyCheckedRooms ?? []))
                case .failure(let error):
                    completion(.failure(error))
                }
        }
    }
    
    
    //GET: 찜한 방 리스트
    func getMarkedRooms(completion: @escaping (Result<[DabangElement], Error>) -> Void) {
        
    }
    
    //GET: 전체 단지 정보 리스트
    func getComplexInfoList(completion: @escaping (Result<[Complex], Error>) -> Void) {
        AF.request( baseURL + "/posts/complex/", method: .get)
            .responseDecodable(of: [Complex].self) { (response) in
                switch response.result {
                case .success(let complex):
                    completion(.success(complex))
                case .failure(let error):
                    completion(.failure(error))
                }
        }
    }
    
    // MARK: - POST
    
    //POST: 유저 생성
    func postCreteUser(username: String, password: String, completion: @escaping (String,Bool) -> Void) {
        let userData = ["username" : username, "password" : password]
        AF.request( baseURL + "/members/", method: .post, parameters: userData)
            .responseJSON { (response) in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    let pk = json["pk"]
//                    let succecc = "아이디가 성공적으로 생성되었습니다."
                    completion("pkNumber: \(pk)", true)
                case .failure(_):
                    let fail = "해당 사용자 이름은 이미 존재합니다."
                    completion(fail, false)
                }
        }
    }
    
    //POST: 자체 로그인
    func postUserLogin(username: String, password: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let loginInfo = ["username" : username, "password" : password]
        AF.request( baseURL + "/members/jwt/", method: .post, parameters: loginInfo)
            .responseJSON { (response) in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    let accessToken = json["token"].stringValue
                    self.userPk = json["user"]["pk"].intValue
                    let result = self.setAccessTokenIntoKeyChain(token: accessToken, key: Key.keyChain)
                    completion(.success(result))
                case .failure(let error):
                    completion(.failure(error))
                }
        }
    }
  
    
    //POST: 방 내놓기
    func postRoomForSale(room: DabangElement, completion: @escaping (Result<DabangElement, Error>) -> Void) {
        AF.request( baseURL + "/posts/", method: .post, parameters: room, encoder: JSONParameterEncoder.default)
            .responseDecodable(of: DabangElement.self) { (response) in
                switch response.result {
                case .success(let room):
                    completion(.success(room))
                case .failure(let error):
                    completion(.failure(error))
                }
        }
    }
  func postMyRoomForSale(room: Testt, completion: @escaping ([String:Any]) -> Void) {
    let parameters = ["type":"투룸", "description":"원룸"]
    
    AF.upload(multipartFormData: { (multipartFormData) in
      for (key, value) in parameters {
        multipartFormData.append(value.data(using: .utf8)!, withName: key)
      }
    }, to: baseURL + "/posts/create/").responseJSON { response in
      guard let json = try? JSONSerialization.jsonObject(with: response.data ?? Data()) as? [String : Any] else { return }
//      guard let message = json["image"] as? String else { return }
      completion(json)
    }
//    AF.upload(multipartFormData: { (multipartFormData) in
//      <#code#>
//    }, to: baseURL, method: .post, headers: ["":""], requestModifier: <#T##Session.RequestModifier?##Session.RequestModifier?##(inout URLRequest) throws -> Void#>)
//    
  }
  
    
    //POST: 최근 본 방
    func postRecentlyCheckedRoom(roomPk: Int, completion: @escaping (String) -> Void) {
        let header: HTTPHeaders = [.authorization(bearerToken: getAccessTokenFromKeyChain())]
        let parameter = ["post" : roomPk]
        AF.request( baseURL + "/members/recently/", method: .post, parameters: parameter, headers: header )
            .responseData { (response) in
                guard let json = try? JSONSerialization.jsonObject(with: response.data ?? Data()) as? [String : Any] else { return }
                guard let message = json["message"] as? String else { return }
                completion(message)
            }
    }
    
    
    //POST: 찜한 방
    
  //POST: 사진 방
  func postPoto(image: UIImage, imageName : String, completion: @escaping (String) -> Void) {
    let imageData = image.jpegData(compressionQuality: 0.50)
    print(image, imageData!)
    let test = baseURL + "/posts/imageupload/"
    AF.upload(multipartFormData: { (multipartFormData) in
      multipartFormData.append(imageData!, withName: "image", fileName: imageName + ".png", mimeType: "image/png")
    }, to: test).responseJSON { response in
      guard let json = try? JSONSerialization.jsonObject(with: response.data ?? Data()) as? [String : Any] else { return }
      guard let message = json["image"] as? String else { return }
      completion(message)
    }
  }
    

    
    
    // MARK: - PATCH
    
    //PATCH: 유저 정보 수정
    func patchUpdateUserInfo(phone: String, image: String, completion: @escaping (Result<User, Error>) -> Void) {
        let header: HTTPHeaders = [.authorization(bearerToken: getAccessTokenFromKeyChain())]
        let parameters = ["phone" : phone, "profileImage" : image]
        AF.request( baseURL + "/members/\(userPk)/", method: .patch, parameters: parameters, headers: header )
            .responseDecodable(of: User.self) { (response) in
                switch response.result {
                case .success(let user):
                    completion(.success(user))
                case .failure(let error):
                    print(error)
                    completion(.failure(error))
                }
        }
    }
    
    
    // MARK: - DELETE
    
    
    
    
}
