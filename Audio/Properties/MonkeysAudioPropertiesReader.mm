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

#import "MonkeysAudioPropertiesReader.h"
#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/APEDecompress.h>
#include <mac/CharacterHelper.h>

@implementation MonkeysAudioPropertiesReader

- (BOOL) readProperties:(NSError **)error
{
	NSMutableDictionary				*propertiesDictionary;
	NSString						*path;
	IAPEDecompress					*decompressor;
	str_utf16						*chars;
	int								result;
	
	// Setup converter
	path			= [[self valueForKey:@"url"] path];
	chars			= GetUTF16FromANSI([path fileSystemRepresentation]);
	NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	
	decompressor	= CreateIAPEDecompress(chars, &result);	
	if(NULL == decompressor || ERROR_SUCCESS != result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid Monkey's Audio file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not a Monkey's Audio file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
														  code:AudioPropertiesReaderFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
				
		return NO;
	}

	propertiesDictionary			= [NSMutableDictionary dictionary];
	
	[propertiesDictionary setValue:@"Monkey's Audio" forKey:@"formatName"];
	[propertiesDictionary setValue:[NSNumber numberWithLongLong:decompressor->GetInfo(APE_DECOMPRESS_TOTAL_BLOCKS)] forKey:@"totalFrames"];
	//	[propertiesDictionary setValue:[NSNumber numberWithLong:bitrate] forKey:@"averageBitrate"];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:decompressor->GetInfo(APE_INFO_BITS_PER_SAMPLE)] forKey:@"bitsPerChannel"];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:decompressor->GetInfo(APE_INFO_CHANNELS)] forKey:@"channelsPerFrame"];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:decompressor->GetInfo(APE_INFO_SAMPLE_RATE)] forKey:@"sampleRate"];
	[propertiesDictionary setValue:[NSNumber numberWithDouble:(double)decompressor->GetInfo(APE_DECOMPRESS_TOTAL_BLOCKS) / decompressor->GetInfo(APE_INFO_SAMPLE_RATE)] forKey:@"duration"];
		
	[self setValue:propertiesDictionary forKey:@"properties"];
		
	delete [] chars;	
	delete decompressor;
	
	return YES;
}

@end
