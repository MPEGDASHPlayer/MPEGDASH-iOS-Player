//
//  ANSegmentLoader.m
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANMpdManager.h"
#import "MPD.h"
#import "ANHttpClient.h"


@interface ANMpdManager () <NSXMLParserDelegate> {
    NSXMLParser *xmlParser;
    MPD *mpd;
    AdaptationSet *currentAdaptionSet;
    Representation *currentRepresentation;
    SegmentTimeline *currentSegmentTimeline;
    NSMutableArray *elementsList;
    BOOL isInProgramInformationElement;
}

@property (nonatomic, strong) NSURL *mpdUrl;
@property (nonatomic, strong) NSXMLParser *xmlParser;
@property (nonatomic, strong) MPD *mpd;
@property (nonatomic, assign) BOOL isInProgramInformationElement;
@property (nonatomic, strong) AdaptationSet *currentAdaptionSet;
@property (nonatomic, strong) Representation *currentRepresentation;
@property (nonatomic, strong) SegmentTimeline *currentSegmentTimeline;
@property (nonatomic, strong) NSMutableArray *elementsList;

@property (nonatomic, strong) ANHttpClient *client;
@property (nonatomic, strong) NSCondition *condition;

@property (nonatomic, strong) ANCompletionBlock completionBlock;

- (NSString *)previousElement;
- (NSString *)currentElement;
- (NSString *)elementAtIndex:(NSUInteger)idx reverseOrder:(BOOL)order;
@end

@implementation ANMpdManager

@synthesize xmlParser = xmlParser;
@synthesize mpd = mpd;
@synthesize currentAdaptionSet = currentAdaptionSet;
@synthesize currentRepresentation = currentRepresentation;
@synthesize currentSegmentTimeline = currentSegmentTimeline;
@synthesize elementsList = elementsList;
@synthesize isInProgramInformationElement = isInProgramInformationElement;

- (id)initWithMpdUrl:(NSURL *)mpdUrl {
    self = [super init];
    if (self){
        self.client = [ANHttpClient sharedHttpClient];
        self.mpdUrl = mpdUrl;
    }
    return self;
}
- (id)initWithMpdUrl:(NSURL *)mpdUrl parserThread:(NSThread *)thread {
    self = [self initWithMpdUrl:mpdUrl];
    if (self){
        self.currentThread = thread;
    }
    return self;
}
- (void)checkMpdWithCompletionBlock:(ANCompletionBlock)completion {
    self.completionBlock = completion;
    [self updateMpd];
}

#pragma mark - public
- (void)updateMpd {
    elementsList = [NSMutableArray array];
    
    mpd = [[MPD alloc] init];

    __weak ANMpdManager *theWeakSelf = self;
    [self.client downloadFile:self.mpdUrl
                     withSuccess:^(id response){
                         [theWeakSelf performSelector:@selector(processXmlFromData:)
                                             onThread:theWeakSelf.currentThread
                                           withObject:response
                                        waitUntilDone:NO];
                     }
                         failure:^(NSError *error){
                             DLog(@"Error %@", error);
                             if (theWeakSelf.completionBlock){
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     theWeakSelf.completionBlock(NO, error);
                                 });
                             }
                         }];
}

#pragma mark - private
- (void)processXmlFromData:(NSData * )data {
    DLog(@"processXmlFromData");
    xmlParser = [[NSXMLParser alloc] initWithData:data];
    xmlParser.delegate = self;
    [xmlParser parse];
}

- (NSString *)previousElement {
    return [self elementAtIndex:1 reverseOrder:YES];
}

- (NSString *)currentElement {
    return [self elementAtIndex:0 reverseOrder:YES];
}

- (NSString *)elementAtIndex:(NSUInteger)idx reverseOrder:(BOOL)order {
    NSUInteger count = elementsList.count;
    if (count > idx){
        return order ? elementsList[count - idx - 1] : elementsList[idx];
    } else {
        return nil;
    }
}

#pragma mark - NSXMLParserDelegate
- (void)parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validationError{
    // TODO: Notify delegate
    NSLog(@"ANMpdManager - validationError error: %@", validationError);
    if (self.completionBlock){
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completionBlock(NO, validationError);
        });
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    // TODO: Notify delegate
    NSLog(@"ANMpdManager - parse error: %@", parseError);
    if (self.completionBlock){
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completionBlock(NO, parseError);
        });
    }
}

- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qualifiedName
    attributes:(NSDictionary *)attributeDict
{
    [elementsList addObject:elementName];
    
    if ([elementName isEqualToString:@"MPD"]) {
        mpd.type = [attributeDict objectForKey:@"type"];
        [mpd setAvailabilityEndTimeFromString:[attributeDict objectForKey:@"availabilityEndTime"]];
        [mpd setAvailabilityStartTimeFromString:[attributeDict objectForKey:@"availabilityStartTime"]];
        [mpd setMediaPresentationDurationFromString:[attributeDict objectForKey:@"mediaPresentationDuration"]];
        [mpd setMinBufferTimeFromString:[attributeDict objectForKey:@"minBufferTime"]];
        
        [mpd setMinimumUpdatePeriodFromString:[attributeDict objectForKey:@"minimumUpdatePeriod"]];
        [mpd setTimeShiftBufferDepthFromString:[attributeDict objectForKey:@"timeShiftBufferDepth"]];
        
    } else if ([elementName isEqualToString:@"Period"]){
        Period *period = [[Period alloc] init];
        period.id = [attributeDict objectForKey:@"id"];
        [period setStartFromString:[attributeDict objectForKey:@"start"]];
        [period setDurationFromString:[attributeDict objectForKey:@"duration"]];
        mpd.period = period;
    } else if ([elementName isEqualToString:@"ProgramInformation"]){
        self.isInProgramInformationElement = YES;
        mpd.programInformation = [[ProgramInformation alloc] init];
    } else if ([elementName isEqualToString:@"Title"] || [elementName isEqualToString:@"Source"]){
    } else if ([elementName isEqualToString:@"AdaptationSet"]){
        AdaptationSet *adaptionSet = [[AdaptationSet alloc] init];
        adaptionSet.id = [attributeDict objectForKey:@"id"];
        adaptionSet.lang = [attributeDict objectForKey:@"lang"];
        adaptionSet.mimeType = [attributeDict objectForKey:@"mimeType"];
        
        [adaptionSet setMaxFrameRateFromString:[attributeDict objectForKey:@"maxFrameRate"]];
        [adaptionSet setMaxHeightFromString:[attributeDict objectForKey:@"maxHeight"]];
        [adaptionSet setMaxWidthString:[attributeDict objectForKey:@"maxWidth"]];
        [adaptionSet setSegmentAlignmentFromString:[attributeDict objectForKey:@"segmentAlignment"]];
        [adaptionSet setAudioSamplingRateFromString:[attributeDict objectForKey:@"audioSamplingRate"]];
        
        [mpd.period addAdaptationSetElement:adaptionSet];
        currentAdaptionSet = adaptionSet;
    } else if ([elementName isEqualToString:@"ContentComponent"]){
        ContentComponent *contentComponent = [[ContentComponent alloc] init];
        contentComponent.id = [attributeDict objectForKey:@"id"];
        contentComponent.contentType = [attributeDict objectForKey:@"contentType"];
        currentAdaptionSet.contentComponent = contentComponent;
    } else if ([elementName isEqualToString:@"SegmentTemplate"]){
        SegmentTemplate *segmentTamplate = [[SegmentTemplate alloc] init];
        segmentTamplate.media = [attributeDict objectForKey:@"media"];
        segmentTamplate.initialization = [attributeDict objectForKey:@"initialization"];
        [segmentTamplate setStartNumberFromString:[attributeDict objectForKey:@"startNumber"]];
        [segmentTamplate setTimescaleFromString:[attributeDict objectForKey:@"timescale"]];
        [segmentTamplate setDurationFromString:[attributeDict objectForKey:@"duration"]];
        [segmentTamplate setPresentationTimeOffsetFromString:[attributeDict objectForKey:@"presentationTimeOffset"]];
        // TODO: change previous element logic
        if ([[self previousElement] isEqualToString:@"Representation"]){
            currentRepresentation.segmentTemplate = segmentTamplate;
        } else if ([[self previousElement] isEqualToString:@"AdaptationSet"]){
            currentAdaptionSet.segmentTemplate = segmentTamplate;
        }
    } else if ([elementName isEqualToString:@"Representation"]){
        Representation *representation = [[Representation alloc] init];
        representation.id = [attributeDict objectForKey:@"id"];
        representation.codecs = [attributeDict objectForKey:@"codecs"];
        representation.mimeType = [attributeDict objectForKey:@"mimeType"];
        [representation setWidthFromString:[attributeDict objectForKey:@"width"]];
        [representation setHeightFromString:[attributeDict objectForKey:@"height"]];
        [representation setBandwidthFromString:[attributeDict objectForKey:@"bandwidth"]];
        [representation setAudioSamplingRateFromString:[attributeDict objectForKey:@"audioSamplingRate"]];
        [currentAdaptionSet addRepresentation:representation];
        currentRepresentation = representation;
    } else if ([elementName isEqualToString:@"SegmentTimeline"]){
        currentSegmentTimeline = [[SegmentTimeline alloc] init];
        if ([@"Representation" isEqualToString:[self elementAtIndex:2 reverseOrder:YES]]){
            currentRepresentation.segmentTemplate.segmentTimeline = self.currentSegmentTimeline;
        } else if ([@"AdaptationSet" isEqualToString:[self elementAtIndex:1 reverseOrder:YES]]){
            currentAdaptionSet.segmentTemplate.segmentTimeline = self.currentSegmentTimeline;
        }
    } else if ([elementName isEqualToString:@"S"]){
        Segment *segment = [[Segment alloc] init];
        [segment setTimeFromString:[attributeDict objectForKey:@"t"]];
        [segment setDurationFromString:[attributeDict objectForKey:@"d"]];
        [currentSegmentTimeline addSegmentElement:segment];
    } else if ([elementName isEqualToString:@"AudioChannelConfiguration"]) {
        AudioChannelConfiguration *acc = [[AudioChannelConfiguration alloc] init];
        [acc setValueFromString:[attributeDict objectForKey:@"value"]];
        acc.schemeIdUri = [attributeDict objectForKey:@"schemeIdUri"];
        currentAdaptionSet.audioChannelConfiguration = acc;
    } else if ([elementName isEqualToString:@"SegmentBase"]){
        if (currentRepresentation && [[self previousElement] isEqualToString:@"Representation"]){
            SegmentBase *segmentBase = [[SegmentBase alloc] init];
            segmentBase.indexRange = [attributeDict objectForKey:@"indexRange"];
            currentRepresentation.segmentBase = segmentBase;
        }
    } else if ([elementName isEqualToString:@"Initialization"]){
        if (currentRepresentation && [[self previousElement] isEqualToString:@"SegmentBase"]){
            Initialization *initialization = [[Initialization alloc] init];
            initialization.range = [attributeDict objectForKey:@"range"];
            currentRepresentation.segmentBase.initialization = initialization;
        }
    } else if ([elementName isEqualToString:@"BaseURL"]){
        
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (self.isInProgramInformationElement){
        if ([self.currentElement isEqualToString:@"Title"]){
            mpd.programInformation.title = string;
        } else if ([self.currentElement isEqualToString:@"Source"]){
             mpd.programInformation.source = string;
        }
    } else {
        if (currentRepresentation != nil && [[self currentElement] isEqualToString:@"BaseURL"]){
            self.currentRepresentation.baseUrlString = string;
        }
    }
}

- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"ProgramInformation"]){
        isInProgramInformationElement = NO;
    } else if ([elementName isEqualToString:@"AdaptationSet"]){
        currentAdaptionSet = nil;
    } else if ([elementName isEqualToString:@"Representation"]){
        currentRepresentation = nil;
    } else if ([elementName isEqualToString:@"SegmentTimeline"]){
        currentSegmentTimeline = nil;
    }
    
    [self.elementsList removeLastObject];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
    if ([self.delegate respondsToSelector:@selector(mpdManager:didFinishParsingMpdFile:)]){
        [self.delegate mpdManager:self didFinishParsingMpdFile:mpd];
    }
    if (self.completionBlock){
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completionBlock(YES, nil);
        });
    }
}
- (BOOL)isVideoRanged {
    return self.mpd.isVideoRanged;
}
@end
