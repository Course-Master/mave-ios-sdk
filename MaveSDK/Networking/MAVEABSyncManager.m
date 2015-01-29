//
//  MAVEABSyncManager.m
//  MaveSDK
//
//  Created by Danny Cosson on 1/23/15.
//
//

#import <zlib.h>
#import "MAVEABSyncManager.h"
#import "MAVEABPerson.h"
#import "MAVEConstants.h"
#import "MAVECompressionUtils.h"
#import "MAVEAPIInterface.h"
#import "MAVEHashingUtils.h"
#import "MaveSDK.h"

NSUInteger const MAVEABSyncMerkleTreeHeight = 11;

@implementation MAVEABSyncManager

- (instancetype)initWithAddressBookData:(NSArray *)addressBook {
    if (self = [super init]) {
        self.addressBook = addressBook;
    }
    return self;
}

// Use dispatch_once to make sure we only call syncContacts once per session. This
// way we don't need any logic to decide where to call it, we can just hook into
// wherever we access the contacts and call it there.
static dispatch_once_t syncOnceToken;

- (void)syncContacts:(NSArray *)contacts {
    dispatch_once(&syncOnceToken, ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            @try {
                [self doSyncContactsInCurrentThread:contacts];
            }
            @catch (NSException *exception) {
                MAVEErrorLog(@"Caught exception %@ running contacts sync", exception);
            }
        });
    });
}


- (void)doSyncContactsInCurrentThread:(NSArray *)contacts {
    MAVEMerkleTree *merkleTree = [[MAVEMerkleTree alloc]initWithHeight:MAVEABSyncMerkleTreeHeight arrayData:contacts];

    BOOL done = [self shouldSkipSyncCompareRemoteTreeRootToTree:merkleTree];
    if (done) {
        return;
    }

    NSArray *changeset = [self changesetComparingFullRemoteTreeToTree:merkleTree];
    // If roots were different changeset should not be empty, but if something got out of sync or
    // timed out we'll get here
    if ([changeset count] == 0) {
        MAVEErrorLog(@"Contact sync changeset unexpectedly zero");
        return;
    }

    [[MaveSDK sharedInstance].APIInterface sendContactsMerkleTree:merkleTree
                                                        changeset:changeset];
}


- (BOOL)shouldSkipSyncCompareRemoteTreeRootToTree:(MAVEMerkleTree *)merkleTree {
    // Fetch the merkle tree root from the server
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSString *remoteHashString;
    [[MaveSDK sharedInstance].APIInterface getRemoteContactsMerkleTreeRootWithCompletionBlock:^(NSError *error, NSDictionary *responseData) {
        remoteHashString = [responseData objectForKey:@"data"];
        if (remoteHashString == (id)[NSNull null]) {
            remoteHashString = nil;
        }
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 30*NSEC_PER_SEC));
    // server response was invalid or timed out
    if ([remoteHashString length] == 0) {
        return YES;
    }

    NSString *localHashString = [MAVEHashingUtils hexStringFromData:[merkleTree.root hashValue]];
    return ([remoteHashString isEqualToString: localHashString]);
}


- (NSArray *)changesetComparingFullRemoteTreeToTree:(MAVEMerkleTree *)merkleTree {
    // Fetch the merkle tree dictionary from the server
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    NSInteger semaWaitCode;
    __block BOOL ok = YES;
    __block NSDictionary *returnedData;
    [[MaveSDK sharedInstance].APIInterface getRemoteContactsFullMerkleTreeWithCompletionBlock:^(NSError *error, NSDictionary *responseData) {
        if (error) {
            ok = NO;
        }
        returnedData = responseData;
        dispatch_semaphore_signal(sema);
    }];
    semaWaitCode = dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 30*NSEC_PER_SEC));
    if (semaWaitCode != 0) {
        ok = NO;
    }
    if (!ok) {
        return nil;
    }

    // Build remote tree object & compare to our own tree
    NSDictionary *remoteTreeDict = [returnedData objectForKey:@"data"];
    MAVEMerkleTree *remoteTree = [[MAVEMerkleTree alloc] initWithJSONObject:remoteTreeDict];
    NSArray *changeset = [merkleTree changesetForOtherTreeToMatchSelf:remoteTree];
    if ([changeset count] == 0) {
        MAVEInfoLog(@"Contacts already in sync with remote");
    }
    return changeset;
}



- (NSData *)serializeAndCompressAddressBook {
    NSMutableArray *dictPeople = [[NSMutableArray alloc] initWithCapacity:[self.addressBook count]];
    MAVEABPerson *person; NSDictionary *dictPerson;

    NSArray *sortedAddressBook = [self.addressBook sortedArrayUsingSelector:@selector(compareRecordIDs:)];

    for (person in sortedAddressBook) {
        dictPerson = [person toJSONDictionary];
        if (dictPerson) {
            [dictPeople addObject:dictPerson];
        }
    }

    NSError *err;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictPeople
                                                   options:0
                                                     error:&err];
    if (err) {
        MAVEErrorLog(@"error serializing JSON for address book sync: %@", err);
        return nil;
    }
    return [MAVECompressionUtils gzipCompressData:data];
}


@end