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

#import "FLACMetadataWriter.h"
#import "AudioStream.h"
#include <FLAC/metadata.h>

static void
setVorbisComment(FLAC__StreamMetadata		*block,
				 NSString					*key,
				 NSString					*value)
{
	FLAC__StreamMetadata_VorbisComment_Entry	entry;
	FLAC__bool									result;
	
	result			= FLAC__metadata_object_vorbiscomment_entry_from_name_value_pair(&entry, [key cStringUsingEncoding:NSASCIIStringEncoding], [value UTF8String]);
	NSCAssert1(YES == result, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Errors", @""), @"FLAC__metadata_object_vorbiscomment_entry_from_name_value_pair");	
	
	result = FLAC__metadata_object_vorbiscomment_replace_comment(block, entry, NO, NO);
	NSCAssert1(YES == result, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Errors", @""), @"FLAC__metadata_object_vorbiscomment_replace_comment");	
}

@implementation FLACMetadataWriter

- (BOOL) writeMetadata:(id)metadata error:(NSError **)error
{
	NSString						*path				= [_url path];
	FLAC__Metadata_Chain			*chain				= NULL;
	FLAC__Metadata_Iterator			*iterator			= NULL;
	FLAC__StreamMetadata			*block				= NULL;
	FLAC__bool						result;
				
	chain							= FLAC__metadata_chain_new();
	NSAssert(NULL != chain, @"Unable to allocate memory.");
	
	if(NO == FLAC__metadata_chain_read(chain, [path fileSystemRepresentation])) {
		
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			switch(FLAC__metadata_chain_status(chain)) {
				case FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE:
					[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid FLAC file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a FLAC file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
					
				case FLAC__METADATA_CHAIN_STATUS_BAD_METADATA:
					[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid FLAC file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a FLAC file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:NSLocalizedStringFromTable(@"The file contains bad metadata.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
					
				default:
					[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid FLAC file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a FLAC file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
			}
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		FLAC__metadata_chain_delete(chain);
		
		return NO;
	}
	
	FLAC__metadata_chain_sort_padding(chain);

	iterator					= FLAC__metadata_iterator_new();
	NSAssert(NULL != iterator, @"Unable to allocate memory.");
	
	FLAC__metadata_iterator_init(iterator, chain);
	
	// Seek to the vorbis comment block if it exists
	while(FLAC__METADATA_TYPE_VORBIS_COMMENT != FLAC__metadata_iterator_get_block_type(iterator)) {
		if(NO == FLAC__metadata_iterator_next(iterator)) {
			break; // Already at end
		}
	}
	
	// If there isn't a vorbis comment block add one
	if(FLAC__METADATA_TYPE_VORBIS_COMMENT != FLAC__metadata_iterator_get_block_type(iterator)) {
		
		// The padding block will be the last block if it exists; add the comment block before it
		if(FLAC__METADATA_TYPE_PADDING == FLAC__metadata_iterator_get_block_type(iterator)) {
			FLAC__metadata_iterator_prev(iterator);
		}
		
		block					= FLAC__metadata_object_new(FLAC__METADATA_TYPE_VORBIS_COMMENT);
		NSAssert(NULL != block, @"Unable to allocate memory.");
		
		// Add our metadata
		result					= FLAC__metadata_iterator_insert_block_after(iterator, block);
		if(NO == result) {
			if(nil != error) {
				NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
				NSString				*path				= [_url path];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid FLAC file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to write metadata", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
				
				*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
											 code:AudioMetadataWriterInputOutputError 
										 userInfo:errorDictionary];
			}
			
			FLAC__metadata_chain_delete(chain);
			FLAC__metadata_iterator_delete(iterator);

			return NO;
		}
	}
	else {
		block = FLAC__metadata_iterator_get_block(iterator);
	}
	
	// Album title
	NSString *album = [metadata valueForKey:MetadataAlbumTitleKey];
	if(nil != album) {
		setVorbisComment(block, @"ALBUM", album);
	}
	
	// Artist
	NSString *artist = [metadata valueForKey:MetadataArtistKey];
	if(nil != artist) {
		setVorbisComment(block, @"ARTIST", artist);
	}
	
	// Composer
	NSString *composer = [metadata valueForKey:MetadataComposerKey];
	if(nil != composer) {
		setVorbisComment(block, @"COMPOSER", composer);
	}
	
	// Genre
	NSString *genre = [metadata valueForKey:MetadataGenreKey];
	if(nil != genre) {
		setVorbisComment(block, @"GENRE", genre);
	}
	
	// Date
	NSString *date = [metadata valueForKey:MetadataDateKey];
	if(nil != date) {
		setVorbisComment(block, @"DATE", date);
	}
	
	// Comment
	NSString *comment = [metadata valueForKey:MetadataCommentKey];
	if(nil != comment) {
		setVorbisComment(block, @"DESCRIPTION", comment);
	}
	
	// Track title
	NSString *title = [metadata valueForKey:MetadataTitleKey];
	if(nil != title) {
		setVorbisComment(block, @"TITLE", title);
	}
	
	// Track number
	NSNumber *trackNumber = [metadata valueForKey:MetadataTrackNumberKey];
	if(nil != trackNumber) {
		setVorbisComment(block, @"TRACKNUMBER", [trackNumber stringValue]);
	}
	
	// Total tracks
	NSNumber *trackTotal = [metadata valueForKey:MetadataTrackTotalKey];
	if(nil != trackTotal) {
		setVorbisComment(block, @"TRACKTOTAL", [trackTotal stringValue]);
	}
	
	// Compilation
	NSNumber *compilation = [metadata valueForKey:MetadataCompilationKey];
	if(nil != compilation) {
		setVorbisComment(block, @"COMPILATION", [compilation stringValue]);
	}
	
	// Disc number
	NSNumber *discNumber = [metadata valueForKey:MetadataDiscNumberKey];
	if(nil != discNumber) {
		setVorbisComment(block, @"DISCNUMBER", [discNumber stringValue]);
	}
	
	// Discs in set
	NSNumber *discTotal = [metadata valueForKey:MetadataDiscTotalKey];
	if(nil != discTotal) {
		setVorbisComment(block, @"DISCTOTAL", [discTotal stringValue]);
	}
	
	// ISRC
	NSString *isrc = [metadata valueForKey:MetadataISRCKey];
	if(nil != isrc) {
		setVorbisComment(block, @"ISRC", isrc);
	}
	
	// MCN
	NSString *mcn = [metadata valueForKey:MetadataMCNKey];
	if(nil != mcn) {
		setVorbisComment(block, @"MCN", mcn);
	}
		
	// Write the new metadata to the file
	result = FLAC__metadata_chain_write(chain, YES, NO);
	if(NO == result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid FLAC file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to write metadata", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterInputOutputError 										
									 userInfo:errorDictionary];
		}

		FLAC__metadata_chain_delete(chain);
		FLAC__metadata_iterator_delete(iterator);

		return NO;
	}

	FLAC__metadata_chain_delete(chain);
	FLAC__metadata_iterator_delete(iterator);

	return YES;
}

@end
