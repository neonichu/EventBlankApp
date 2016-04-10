//
//  RealmManager.m
//  ContentfulSDK
//
//  Created by Boris Bügling on 08/12/14.
//
//

#import <objc/runtime.h>
#import <Realm/Realm.h>

#import "CDAUtilities.h"
#import "RealmAsset.h"
#import "RealmManager.h"
#import "RealmSpace.h"

static inline BOOL CDAIsKindOfClass(Class class1, Class class2) {
    while (class1) {
        if (class1 == class2) return YES;
        class1 = class_getSuperclass(class1);
    }
    return NO;
}

@interface RealmManager ()

@property (nonatomic, readonly) RLMRealm* currentRealm;
@property (nonatomic) NSMutableDictionary* relationshipsToResolve;

@end

#pragma mark -

@implementation RealmManager

-(Class)classForAssets {
    return [RealmAsset class];
}

-(Class)classForSpaces {
    return [RealmSpace class];
}

-(RLMRealm *)currentRealm {
    return [RLMRealm defaultRealm];
}

-(id<CDAPersistedAsset>)createPersistedAsset {
    id<CDAPersistedAsset> asset = [super createPersistedAsset];
    [self.currentRealm addObject:asset];
    return asset;
}

-(id<CDAPersistedEntry>)createPersistedEntryForContentTypeWithIdentifier:(NSString *)identifier {
    id<CDAPersistedEntry> entry = [super createPersistedEntryForContentTypeWithIdentifier:identifier];

    if (entry) {
        [self.currentRealm addObject:entry];
    }
    
    return entry;
}

-(id<CDAPersistedSpace>)createPersistedSpace {
    id<CDAPersistedSpace> space = [super createPersistedSpace];
    [self.currentRealm addObject:space];
    return space;
}

-(void)deleteAssetWithIdentifier:(NSString *)identifier {
    NSPredicate* predicate = [self predicateWithIdentifier:identifier];
    [self.currentRealm deleteObjects:[self.classForAssets objectsWithPredicate:predicate]];
}

-(void)deleteEntryWithIdentifier:(NSString *)identifier {
    NSPredicate* predicate = [self predicateWithIdentifier:identifier];

    [self forEachEntryClassDo:^(__unsafe_unretained Class entryClass) {
        [self.currentRealm deleteObjects:[(id)entryClass objectsWithPredicate:predicate]];
    }];
}

-(NSArray *)fetchAssetsFromDataStore {
    NSMutableArray* assets = [@[] mutableCopy];
    for (id asset in [self.classForAssets allObjects]) {
        [assets addObject:asset];
    }
    return [assets copy];
}

-(id<CDAPersistedAsset>)fetchAssetWithIdentifier:(NSString *)identifier {
    return [self.classForAssets objectsWithPredicate:[self predicateWithIdentifier:identifier]].firstObject;
}

-(NSArray *)fetchEntriesFromDataStore {
    NSMutableArray* allEntries = [@[] mutableCopy];

    [self forEachEntryClassDo:^(__unsafe_unretained Class entryClass) {
        for (RLMObject* object in [(id)entryClass allObjects]) {
            [allEntries addObject:object];
        }
    }];

    return [allEntries copy];
}

-(id<CDAPersistedEntry>)fetchEntryWithIdentifier:(NSString *)identifier {
    __block id<CDAPersistedEntry> result = nil;
    NSPredicate* predicate = [self predicateWithIdentifier:identifier];

    [self forEachEntryClassDo:^(__unsafe_unretained Class entryClass) {
        RLMResults* results = [(id)entryClass objectsWithPredicate:predicate];
        if (results.count > 0) {
            result = results.firstObject;
        }
    }];

    return result;
}

-(id<CDAPersistedSpace>)fetchSpaceFromDataStore {
    return [self.classForSpaces allObjects].firstObject;
}

-(void)forEachEntryClassDo:(void (^)(Class entryClass))entryClassHandler {
    NSParameterAssert(entryClassHandler);

    NSMutableSet* classes = [NSMutableSet set];
    for (NSString* identifier in self.identifiersOfHandledContentTypes) {
        [classes addObject:[self classForEntriesOfContentTypeWithIdentifier:identifier]];
    }

    for (Class clazz in classes) {
        entryClassHandler(clazz);
    }
}

-(NSDictionary *)mappingForEntriesOfContentTypeWithIdentifier:(NSString *)identifier {
    NSMutableDictionary* mapping = [[super mappingForEntriesOfContentTypeWithIdentifier:identifier] mutableCopy];
    NSArray* relationships = [self relationshipsForClass:[self classForEntriesOfContentTypeWithIdentifier:identifier]];

    [mapping enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSString* value, BOOL *stop) {
        if ([relationships containsObject:value]) {
            [mapping removeObjectForKey:key];
        }
    }];

    return mapping;
}

-(void)performSynchronizationWithSuccess:(void (^)())success failure:(CDARequestFailureBlock)failure {
    self.relationshipsToResolve = [@{} mutableCopy];

    [self.currentRealm beginWriteTransaction];
    [super performSynchronizationWithSuccess:success failure:failure];
}

-(NSPredicate*)predicateWithIdentifier:(NSString*)identifier {
    return [NSPredicate predicateWithFormat:@"identifier = %@", identifier];
}

- (NSArray *)propertiesForEntriesOfContentTypeWithIdentifier:(NSString *)identifier {
    Class class = [self classForEntriesOfContentTypeWithIdentifier:identifier];
    RLMObjectSchema* schema = [[[class allObjects] firstObject] objectSchema];
    return [schema.properties valueForKey:@"name"];
}

-(NSArray*)relationshipsForClass:(Class)clazz {
    NSMutableArray* relationships = [@[] mutableCopy];

    RLMObjectSchema* schema = [[[clazz allObjects] firstObject] objectSchema];
    NSMutableArray* properties = [schema.properties mutableCopy];
    for (RLMProperty* property in schema.properties) {
        if (property.type == RLMPropertyTypeObject || property.type == RLMPropertyTypeArray) {
            [relationships addObject:property.name];
        }
    }

    return relationships;
}

- (id)resolveResource:(CDAResource*)rsc {
    if (CDAClassIsOfType([rsc class], CDAAsset.class)) {
        return [self fetchAssetWithIdentifier:rsc.identifier];
    }

    if (CDAClassIsOfType([rsc class], CDAEntry.class)) {
        return [self fetchEntryWithIdentifier:rsc.identifier];
    }

    NSAssert(false, @"Unexpectly, %@ is neither an Asset nor an Entry.", rsc);
    return nil;
}

-(void)saveDataStore {
    for (id<CDAPersistedEntry> entry in [self fetchEntriesFromDataStore]) {
        NSDictionary* relationships = self.relationshipsToResolve[entry.identifier];

        [relationships enumerateKeysAndObjectsUsingBlock:^(NSString* keyPath, id value, BOOL *s) {
            if ([value isKindOfClass:NSArray.class]) {
                NSMutableArray* resolvedResources = [@[] mutableCopy];

                for (id resource in value) {
                    id resolvedResource = [self resolveResource:resource];
                    if (resolvedResource) {
                        [resolvedResources addObject:resolvedResource];
                    }
                }

                value = [resolvedResources copy];
            } else {
                value = [self resolveResource:value];
            }

            [(NSObject*)entry setValue:value forKeyPath:keyPath];
        }];
    }

    [self.currentRealm commitWriteTransaction];
}

-(void)setClassForAssets:(Class)classForAssets {
    NSLog(@"%@ does not need a user-provided class for Assets.", NSStringFromClass(self.class));
}

-(void)setClassForSpaces:(Class)classForSpaces {
    NSLog(@"%@ does not need a user-provided class for Spaces.", NSStringFromClass(self.class));
}

-(void)updatePersistedEntry:(id<CDAPersistedEntry>)persistedEntry withEntry:(CDAEntry *)entry {
    [super updatePersistedEntry:persistedEntry withEntry:entry];

    Class clazz = [self classForEntriesOfContentTypeWithIdentifier:entry.contentType.identifier];
    NSMutableDictionary* relationships = [@{} mutableCopy];

    for (NSString* relationshipName in [self relationshipsForClass:clazz]) {
        NSDictionary* mappingForEntries = [super mappingForEntriesOfContentTypeWithIdentifier:entry.contentType.identifier];
        NSString* entryKeyPath = [[mappingForEntries allKeysForObject:relationshipName] firstObject];

        if (!entryKeyPath) {
            return;
        }

        id relationshipTarget = [entry valueForKeyPath:entryKeyPath];

        if (!relationshipTarget) {
            return;
        }

        relationships[relationshipName] = relationshipTarget;
    }

    self.relationshipsToResolve[entry.identifier] = [relationships copy];
}

@end
