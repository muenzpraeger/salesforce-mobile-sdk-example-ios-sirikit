//
//  IntentHandler.swift
//  ChatterIntent
//
//  Created by René Winkelmeyer on 21/03/2017.
//  Copyright © 2017 Salesforce. All rights reserved.
//

import Intents
import SalesforceSDKCore

// As an example, this class is set up to handle Message intents.
// You will want to replace this or add other intents as appropriate.
// The intents you wish to handle must be declared in the extension's Info.plist.

// You can test your example integration by saying things to Siri like:
// "Send a message using <myApp>"
// "<myApp> John saying hello"
// "Search for messages in <myApp>"

let RemoteAccessConsumerKey = "4NVG98_Psg5cppyZaAWz07vl7mjhIiEfLk1ytsbSfdL.EPKmVKkToxqb4e8UfHOR_HvaSwtH4DQLItct5goGq";
let OAuthRedirectURI        = "sirikitexample://auth/success";

class IntentHandler: INExtension, INSendMessageIntentHandling, SFRestDelegate {
    
    var peopleResolutionResults = [INPersonResolutionResult]()
    var completionHandler: (([INPersonResolutionResult]) -> Void)?
    
    
    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        
        return self
    }
    
    // MARK: - INSendMessageIntentHandling
    
    // Implement resolution methods to provide additional information about your intent (optional).
    func resolveRecipients(forSendMessage intent: INSendMessageIntent, with completion: @escaping ([INPersonResolutionResult]) -> Void) {
        
        // Storing info that user is logged in within the app group's preferences
        // let defaults = UserDefaults(suiteName: "com.group.com.winkelmeyer.salesforce.sirikit.SiriKitExample")
        // if ((defaults?.object(forKey: "userIsLoggedIn")) != nil && (defaults?.object(forKey: "userIsLoggedIn")) as! Bool) {
            
            if let recipients = intent.recipients {
                
                SFSDKDatasharingHelper.sharedInstance().appGroupEnabled = true
                SFSDKDatasharingHelper.sharedInstance().appGroupName = "group.com.winkelmeyer.salesforce.sirikit.SiriKitExample"
                
                
                SalesforceSDKManager.shared().connectedAppId = RemoteAccessConsumerKey
                SalesforceSDKManager.shared().connectedAppCallbackUri = OAuthRedirectURI
                SalesforceSDKManager.shared().authScopes = ["full"];
                
                
                // If no recipients were provided we'll need to prompt for a value.
                if recipients.count == 0 {
                    completion([INPersonResolutionResult.needsValue()])
                    return
                }
                
                self.completionHandler = completion
                
                querySalesforceForUsers(forSendMessage: intent, with: completion)
            }
        // }
    }
    
    func resolveContent(forSendMessage intent: INSendMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let text = intent.content, !text.isEmpty {
            completion(INStringResolutionResult.success(with: text))
        } else {
            completion(INStringResolutionResult.needsValue())
        }
    }
    
    // Once resolution is completed, perform validation on the intent and provide confirmation (optional).
    
    func confirm(sendMessage intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        // Verify user is authenticated and your app is ready to send a message.
        
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
        let response = INSendMessageIntentResponse(code: .ready, userActivity: userActivity)
        completion(response)
    }
    
    // Handle the completed intent (required).
    
    func handle(sendMessage intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        
        postChatterMessage(message: intent.content!, userId: (intent.recipients?[0].personHandle?.value)!)
        
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
        let response = INSendMessageIntentResponse(code: .success, userActivity: userActivity)
        completion(response)
    }
    
    
    func querySalesforceForUsers(forSendMessage intent: INSendMessageIntent, with completion: @escaping ([INPersonResolutionResult]) -> Void) {
        let query = "SELECT Name, Id FROM User WHERE Name='" + (intent.recipients?[0].displayName)! + "' LIMIT 3"
        let request = SFRestAPI.sharedInstance().request(forQuery:query)
        SFRestAPI.sharedInstance().send(request, delegate: self)
    }
    
    func postChatterMessage(message: String, userId: String) {
        let request = SFRestRequest(method: SFRestMethod.POST, path: "/services/data/v39.0/chatter/feed-elements", queryParams: nil)
        
        let json = "{\"feedElementType\":\"FeedItem\",\"subjectId\":\"" + userId + "\",\"body\":{\"messageSegments\":[{\"type\":\"Text\",\"text\":\"" + message + "\"}]}}"
        
        request.setCustomRequestBodyData(json.data(using: .utf8)!, contentType: "application/json")
        SFRestAPI.sharedInstance().send(request, delegate: self)
    }
    
    
    func request(_ request: SFRestRequest, didLoadResponse jsonResponse: Any) {
        var matchingContacts: [NSDictionary]
        matchingContacts = (jsonResponse as! NSDictionary)["records"] as! [NSDictionary]
        let people = convertUserSearchToINPerson(matchingContacts: matchingContacts)
        
        
        switch people.count {
            
        case 2  ... Int.max:
            // We need Siri's help to ask user to pick one from the matches.
            self.peopleResolutionResults += [INPersonResolutionResult.disambiguation(with: people)]
            
        case 1:
            // We have exactly one matching contact
            self.peopleResolutionResults += [INPersonResolutionResult.success(with: people[0])]
            
        case 0:
            // We have no contacts matching the description provided
            self.peopleResolutionResults += [INPersonResolutionResult.unsupported()]
            
        default:
            break
            
        }
        
        self.completionHandler!(self.peopleResolutionResults)
        
    }
    
    func convertUserSearchToINPerson(matchingContacts:  [NSDictionary]) -> [INPerson] {
        var people = [INPerson]()
        
        if (matchingContacts.count>0) {
            let unidString = matchingContacts[0].value(forKey: "Id") as! String
            let handle = INPersonHandle(value: unidString, type: INPersonHandleType.unknown)
            let person = INPerson(personHandle: handle, nameComponents: nil, displayName: matchingContacts[0].value(forKey: "Name") as? String, image: nil, contactIdentifier: nil, customIdentifier: unidString)
            people.append(person)
        }
        
        
        return people
    }
    
}

