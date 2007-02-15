/*
 *  $Id$
 *
 *  Copyright (C) 2006 - 2007 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "ArtistsNode.h"
#import "CollectionManager.h"
#import "AudioStreamManager.h"
#import "AudioStream.h"
#import "ArtistNode.h"

@interface ArtistsNode (Private)
- (void) refreshData;
@end

@implementation ArtistsNode

- (id) init
{
	if((self = [super initWithName:NSLocalizedStringFromTable(@"Artists", @"General", @"")])) {
		[self refreshData];
		[[[CollectionManager manager] streamManager] addObserver:self 
													  forKeyPath:@"streams" 
														 options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) 
														 context:nil];
	}
	return self;
}

- (void) dealloc
{
	[[[CollectionManager manager] streamManager] removeObserver:self forKeyPath:@"streams"];
	
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self refreshData];

/*	BOOL	refresh		= NO;
	int		changeKind	= [[change valueForKey:NSKeyValueChangeKindKey] intValue];
	
	if(NSKeyValueChangeSetting == changeKind) {
		NSArray			*oldStreams		= [change valueForKey:NSKeyValueChangeOldKey];
		NSArray			*newStreams		= [change valueForKey:NSKeyValueChangeNewKey];
		AudioStream		*oldStream		= nil;
		AudioStream		*newStream		= nil;
		unsigned		i;

		NSAssert([oldStreams count] == [newStreams count], @"Unequal sized arrays passed to NSKeyValueChangeSetting");
		
		for(i = 0; i < [oldStreams count]; ++i) {
			oldStream = [oldStreams objectAtIndex:i];
			newStream = [newStreams objectAtIndex:i];
			NSLog(@"%@ vs %@", [oldStream valueForKey:MetadataArtistKey], [newStream valueForKey:MetadataArtistKey]);
			if(NO == [[oldStream valueForKey:MetadataArtistKey] isEqualToString:[newStream valueForKey:MetadataArtistKey]]) {
				NSLog(@"artists changed");
				refresh = YES;
				break;
			}
		}
	}
	else if(NSKeyValueChangeInsertion == changeKind) {
		refresh = YES;
	}
	else if(NSKeyValueChangeRemoval == changeKind) {
		refresh = YES;
	}
	else if(NSKeyValueChangeReplacement == changeKind) {
		refresh = YES;
	}
	
	// The streams in the library changed, so refresh them
	if(refresh) {
		NSLog(@"refreshing ArtistsNode");
		[self refreshData];
	}*/
}

@end

@implementation ArtistsNode (Private)

- (void) refreshData
{
	NSString		*keyName		= [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", MetadataArtistKey];
	NSArray			*artists		= [[[[CollectionManager manager] streamManager] streams] valueForKeyPath:keyName];
	NSEnumerator	*enumerator		= [artists objectEnumerator];
	NSString		*artist			= nil;
	ArtistNode		*node			= nil;
	
	[self willChangeValueForKey:@"children"];
	[_children makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
	[_children removeAllObjects];
	while((artist = [enumerator nextObject])) {
		node = [[ArtistNode alloc] initWithArtist:artist];
		[node setParent:self];
		[_children addObject:node];
	}
	[self didChangeValueForKey:@"children"];
}

@end