//
//  TIPLRUCache.m
//  TwitterImagePipeline
//
//  Created on 10/27/15.
//  Copyright © 2015 Twitter. All rights reserved.
//

#import "TIP_Project.h"
#import "TIPLRUCache.h"

@interface TIPLRUCache ()

@property (nonatomic, readonly, nonnull) NSMutableDictionary<NSString *, id<TIPLRUEntry>> *cache;

- (void)clearEntry:(nonnull id<TIPLRUEntry>)entry;
- (void)moveEntryToFront:(nonnull id<TIPLRUEntry>)entry;

@end

NS_INLINE void TIPLRUCacheAssertHeadAndTail(TIPLRUCache *cache)
{
    if (gTwitterImagePipelineAssertEnabled) {
        TIPAssert(!cache.headEntry == !cache.tailEntry);
        if (cache.headEntry) {
            TIPAssert(cache.cache[cache.headEntry.LRUEntryIdentifier] == cache.headEntry);
        }
        if (cache.tailEntry) {
            TIPAssert(cache.cache[cache.tailEntry.LRUEntryIdentifier] == cache.tailEntry);
        }
    }
}

@implementation TIPLRUCache
{
    struct {
        BOOL delegateSupportsDidEvictSelector;
    } _flags;
    NSInteger _mutationCheckInteger;
}

- (instancetype)init
{
    return [self initWithEntries:nil delegate:nil];
}

- (instancetype)initWithEntries:(NSArray *)arrayOfLRUEntries delegate:(id<TIPLRUCacheDelegate>)delegate
{
    if (self = [super init]) {
        _cache = [[NSMutableDictionary alloc] init];
        [self internalSetDelegate:delegate];
        for (id<TIPLRUEntry> entry in arrayOfLRUEntries) {
            [self appendEntry:entry];
        }
    }
    return self;
}

- (void)internalSetDelegate:(id<TIPLRUCacheDelegate>)delegate
{
    _flags.delegateSupportsDidEvictSelector = (NO != [delegate respondsToSelector:@selector(tip_cache:didEvictEntry:)]);
    _delegate = delegate;
}

- (void)setDelegate:(id<TIPLRUCacheDelegate>)delegate
{
    [self internalSetDelegate:delegate];
}

#pragma mark Setting

- (void)addEntry:(nonnull id<TIPLRUEntry>)entry
{
    TIPAssert(entry != nil);
    if (entry == nil) {
        return;
    }

    if (entry == _headEntry) {
        return;
    }

    NSString *identifier = entry.LRUEntryIdentifier;
    TIPAssert(identifier != nil);
    if (gTwitterImagePipelineAssertEnabled && _cache[identifier]) {
        TIPAssert((id)_cache[identifier] == (id)entry);
    }

    [self moveEntryToFront:entry];
    _cache[identifier] = entry;

    TIPLRUCacheAssertHeadAndTail(self);
}

- (void)appendEntry:(nonnull id<TIPLRUEntry>)entry
{
    TIPAssert(entry != nil);
    if (entry == nil) {
        return;
    }

    if (entry == _tailEntry) {
        return;
    }

    NSString *identifier = entry.LRUEntryIdentifier;
    TIPAssert(identifier != nil);

    _tailEntry.nextLRUEntry = entry;
    entry.previousLRUEntry = _tailEntry;
    entry.nextLRUEntry = nil;
    _tailEntry = entry;
    _cache[identifier] = entry;

    if (!_headEntry) {
        _headEntry = _tailEntry;
    }

    _mutationCheckInteger++;
    TIPLRUCacheAssertHeadAndTail(self);
}

#pragma mark Getting

- (NSUInteger)numberOfEntries
{
    return _cache.count;
}

- (nullable id<TIPLRUEntry>)entryWithIdentifier:(nonnull NSString *)identifier canMutate:(BOOL)canMutate
{
    id<TIPLRUEntry> entry = _cache[identifier];
    if (canMutate && entry) {
        [self moveEntryToFront:entry];
    }
    return entry;
}

- (nullable id<TIPLRUEntry>)entryWithIdentifier:(nonnull NSString *)identifier
{
    return [self entryWithIdentifier:identifier canMutate:YES];
}

- (NSArray *)allEntries
{
    NSMutableArray *entries = [[NSMutableArray alloc] initWithCapacity:self.numberOfEntries];

    id<TIPLRUEntry> current = self.headEntry;
    while (current != nil) {
        [entries addObject:current];
        current = current.nextLRUEntry;
    }

    return entries;
}

#pragma mark Removal

- (void)removeEntry:(nonnull id<TIPLRUEntry>)entry
{
    if (!entry) {
        return;
    }

    NSString *identifier = entry.LRUEntryIdentifier;
    TIPAssert(identifier != nil);

    if (!identifier) {
        return;
    }

    TIPAssert(_cache[identifier] == entry);

    [self clearEntry:entry];
    [_cache removeObjectForKey:identifier];

    TIPLRUCacheAssertHeadAndTail(self);

    if (_flags.delegateSupportsDidEvictSelector) {
        [_delegate tip_cache:self didEvictEntry:entry];
    }
}

- (nullable id<TIPLRUEntry>)removeTailEntry
{
    id<TIPLRUEntry> tailEntry = _tailEntry;
    [self removeEntry:tailEntry];
    return tailEntry;
}

#pragma mark Other

- (void)clearAllEntries
{
    // removing all entries via weak dealloc chaining
    // can yield a stack overflow!
    // use iterative removal instead

    id<TIPLRUEntry> entryToRemove = _headEntry;
    while (entryToRemove) {
        id<TIPLRUEntry> nextEntry = entryToRemove.nextLRUEntry;
        entryToRemove.nextLRUEntry = nil;
        entryToRemove.previousLRUEntry = nil;
        entryToRemove = nextEntry;
    }

    _tailEntry = nil;
    _headEntry = nil;
    [_cache removeAllObjects];
    _mutationCheckInteger++;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len
{
    // Prep the number of enumerations made in this pass
    NSUInteger count = 0;

    // Initialization
    if (!state->state && !state->extra[0]) {
        // Track mutations using the current "start" location
        state->mutationsPtr = (void *)&_mutationCheckInteger;

        // Set the state as the current item to iterate on
        state->state = (unsigned long)_headEntry;

        // Flag that we started
        state->extra[0] = 1UL;
    }

    // Set the items pointer to the provided convenience buffer
    state->itemsPtr = buffer;

    // Now we provide items
    for ( ; state->state != 0UL && count < len; count++) {

        // Get the current entry
        __unsafe_unretained id<TIPLRUEntry> entry = (__bridge id<TIPLRUEntry>)(void *)state->state;

        // Add the current entry to the buffer
        buffer[count] = entry;

        // Get the next entry
        entry = entry.nextLRUEntry;

        // Update the state to the next entry
        state->state = (unsigned long)entry;
    }

    return count; // count of 0 ends the enumeration
}

#pragma mark Private

- (void)clearEntry:(nonnull id<TIPLRUEntry>)entry
{
    id<TIPLRUEntry> prev = entry.previousLRUEntry;
    id<TIPLRUEntry> next = entry.nextLRUEntry;
    prev.nextLRUEntry = next;
    next.previousLRUEntry = prev;
    entry.previousLRUEntry = nil;
    entry.nextLRUEntry = nil;
    if (entry == _tailEntry) {
        _tailEntry = prev;
    }
    if (entry == _headEntry) {
        _headEntry = next;
    }
    _mutationCheckInteger++;
}

- (void)moveEntryToFront:(nonnull id<TIPLRUEntry>)entry
{
    if (_headEntry == entry) {
        return;
    }

    id<TIPLRUEntry> previous = entry.previousLRUEntry;
    if (previous) {
        // in the linked list
        BOOL update = entry.shouldAccessMoveLRUEntryToHead;
        if (!update) {
            // don't update in LRU
            return;
        }
    }

    if (entry == _tailEntry) {
        _tailEntry = previous;
    }

    previous.nextLRUEntry = entry.nextLRUEntry;
    entry.nextLRUEntry.previousLRUEntry = previous;
    entry.previousLRUEntry = nil;
    entry.nextLRUEntry = _headEntry;
    _headEntry.previousLRUEntry = entry;
    _headEntry = entry;

    if (!_tailEntry) {
        _tailEntry = entry;
        TIPAssert(entry.nextLRUEntry == nil);
        TIPAssert(previous == nil);
    }

    _mutationCheckInteger++;
    TIPAssert(!_headEntry == !_tailEntry);
}

@end
