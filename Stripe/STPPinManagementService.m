//
//  STPAPIClient+PinManagement.m
//  Stripe
//
//  Created by Arnaud Cavailhez on 4/29/19.
//  Copyright © 2019 Stripe, Inc. All rights reserved.
//

#import "STPPinManagementService.h"
#import "STPAPIRequest.h"
#import "STPIssuingCardPin.h"
#import "STPEphemeralKeyManager.h"
#import "STPAPIClient+Private.h"

@interface STPPinManagementService()
@property (nonatomic, strong) STPEphemeralKeyManager *keyManager;
@end

@implementation STPPinManagementService

- (instancetype)initWithKeyProvider:(id<STPIssuingCardEphemeralKeyProvider>)keyProvider {
    self = [super init];
    if (self) {
        _keyManager = [[STPEphemeralKeyManager alloc] initWithKeyProvider:keyProvider apiVersion:[STPAPIClient apiVersion] performsEagerFetching:NO];
    }
    return self;
}

- (void)retrievePin:(__unused NSString *) cardId
         verificationId:(__unused NSString *) verificationId
        oneTimeCode:(__unused NSString *) oneTimeCode
         completion:(__unused STPPinCompletionBlock) completion{
    [self.keyManager getOrCreateKey:^(__unused STPEphemeralKey * _Nullable ephemeralKey, __unused NSError * _Nullable keyError) {
        NSString *endpoint = [NSString stringWithFormat:@"issuing/cards/%@/pin", cardId];
        NSDictionary *parameters = @{
                                     @"verification": @{
                                             @"id": verificationId,
                                             @"one_time_code": oneTimeCode,
                                             },
                                     };
        STPAPIClient *client = [STPAPIClient apiClientWithEphemeralKey:ephemeralKey];
        [STPAPIRequest<STPIssuingCardPin *> getWithAPIClient:client
                                                    endpoint:endpoint
                                                  parameters:parameters
                                                deserializer:[STPIssuingCardPin new]
                                                  completion:^(
                                                               STPIssuingCardPin *details,
                                                               __unused     NSHTTPURLResponse *response,
                                                               NSError *error) {
                                                      // TODO handle errors
                                                      // Find if there were errors
                                                      if (details.error != nil) {
                                                          NSString* code = [details.error objectForKey:@"code"];
                                                          if ([@"api_key_expired" isEqualToString:code]) {
                                                              completion(nil, STPPinEphemeralKeyError, error);
                                                          }
                                                          else if ([@"already_redeemed" isEqualToString:code]) {
                                                              completion(nil, STPPinErrorVerificationAlreadyRedeemed, nil);
                                                          }
                                                          else {
                                                              completion(nil, STPPinUnknownError, error);
                                                          }
                                                          return;
                                                      }
                                                      completion(details, STPPinSuccess, nil);
                                                  }];
    }];
}

@end