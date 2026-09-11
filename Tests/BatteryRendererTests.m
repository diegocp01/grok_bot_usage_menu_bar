#import <Cocoa/Cocoa.h>
#import "BatteryRenderer.h"

static void Assert(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static CGFloat AlphaAt(NSBitmapImageRep *rep, NSInteger x, NSInteger y) {
    return [[rep colorAtX:x y:y] alphaComponent];
}

static NSColor *ColorAt(NSBitmapImageRep *rep, NSInteger x, NSInteger y) {
    return [[rep colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
}

static NSBitmapImageRep *BitmapForImage(NSImage *image) {
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    Assert(cgImage != NULL, @"renderer produces a bitmap image");
    return [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
}

int main(void) {
    @autoreleasepool {
        double day = 24.0 * 60.0 * 60.0;
        Assert(fabs(GrokOnPacePercent(3.0 * day, 0.0, 7.0 * day) - (4.0 / 7.0 * 100.0)) < 0.000001,
               @"pace uses the selected window's real seven-day duration");
        Assert(fabs(GrokOnPacePercent(2.0 * day, 0.0, 10.0 * day) - 80.0) < 0.000001,
               @"pace uses a non-weekly window's real duration");
        Assert(GrokOnPacePercent(-day, 0.0, 7.0 * day) == 100.0,
               @"pace clamps dates before the window to 100 percent");
        Assert(GrokOnPacePercent(8.0 * day, 0.0, 7.0 * day) == 0.0,
               @"pace clamps dates after reset to zero percent");
        Assert(isnan(GrokOnPacePercent(day, day, day)),
               @"pace is unavailable for an invalid zero-duration window");

        NSImage *empty = GrokBatteryIconWithLabel(nil, 0.0, @"50");
        NSImage *half = GrokBatteryIconWithLabel(nil, 50.0, @"50");
        NSImage *full = GrokBatteryIconWithLabel(nil, 100.0, @"50");
        Assert(empty.template && half.template && full.template,
               @"battery remains an appearance-adaptive template image");

        NSBitmapImageRep *emptyRep = BitmapForImage(empty);
        NSBitmapImageRep *halfRep = BitmapForImage(half);
        NSBitmapImageRep *fullRep = BitmapForImage(full);
        NSInteger splitX = 42;
        BOOL foundFilledSideGlyph = NO;
        BOOL foundEmptySideGlyph = NO;

        // At zero fill, opaque pixels inside the battery interior belong only to
        // the label. Reuse those pixels to verify both sides of the 50% boundary.
        for (NSInteger y = 5; y <= 12; y++) {
            for (NSInteger x = 30; x <= 56; x++) {
                CGFloat emptyAlpha = AlphaAt(emptyRep, x, y);
                if (emptyAlpha < 0.55) {
                    continue;
                }

                CGFloat punchedAlphaLimit = 1.0 - emptyAlpha + 0.12;
                if (x < splitX && AlphaAt(halfRep, x, y) <= punchedAlphaLimit) {
                    foundFilledSideGlyph = YES;
                }
                if (x > splitX && AlphaAt(halfRep, x, y) >= emptyAlpha - 0.12) {
                    foundEmptySideGlyph = YES;
                }
                Assert(AlphaAt(fullRep, x, y) <= punchedAlphaLimit,
                       @"full battery punches the entire label out of the fill");
            }
        }

        Assert(foundFilledSideGlyph,
               @"half battery punches out the label over its filled side");
        Assert(foundEmptySideGlyph,
               @"half battery keeps the label opaque over its empty side");

        NSImage *paceLight = GrokBatteryIconWithOnPaceLine(nil, 50.0, @"", 25.0, NO);
        NSImage *paceDark = GrokBatteryIconWithOnPaceLine(nil, 50.0, @"", 25.0, YES);
        Assert(!paceLight.template && !paceDark.template,
               @"colored pace batteries are not flattened into monochrome template images");
        NSBitmapImageRep *paceLightRep = BitmapForImage(paceLight);
        NSBitmapImageRep *paceDarkRep = BitmapForImage(paceDark);
        NSInteger markerX = 35;
        NSColor *lightMarker = ColorAt(paceLightRep, markerX, 9);
        NSColor *darkMarker = ColorAt(paceDarkRep, markerX, 9);
        Assert(lightMarker.greenComponent > lightMarker.redComponent,
               @"light appearance retains the green pace marker");
        Assert(darkMarker.greenComponent > darkMarker.redComponent,
               @"dark appearance retains the green pace marker");

        NSBitmapImageRep *opacityRep = BitmapForImage(
            GrokBatteryIconWithOnPaceLine(nil, 0.0, @"", 50.0, NO));
        NSColor *opacityMarker = ColorAt(opacityRep, 42, 9);
        Assert(opacityMarker.alphaComponent >= 0.60 && opacityMarker.alphaComponent <= 0.70,
               @"pace marker is approximately 65 percent opaque");
        Assert(AlphaAt(opacityRep, 41, 9) < 0.05 && AlphaAt(opacityRep, 43, 9) < 0.05,
               @"pace marker is one pixel wide");

        NSImage *sampleIcon = [[NSImage alloc] initWithSize:NSMakeSize(18.0, 18.0)];
        [sampleIcon lockFocus];
        [NSColor.blackColor setFill];
        NSRectFill(NSMakeRect(2.0, 2.0, 14.0, 14.0));
        [sampleIcon unlockFocus];
        sampleIcon.template = YES;
        NSBitmapImageRep *darkIconRep = BitmapForImage(
            GrokBatteryIconWithOnPaceLine(sampleIcon, 50.0, @"", 25.0, YES));
        NSColor *darkIconPixel = ColorAt(darkIconRep, 9, 9);
        Assert(darkIconPixel.alphaComponent > 0.9 && darkIconPixel.redComponent > 0.9,
               @"dark appearance retains and lightens the supplied template icon");

        NSImage *labelOverPace = GrokBatteryIconWithOnPaceLine(nil, 50.0, @"1", 50.0, NO);
        NSImage *paceWithoutLabel = GrokBatteryIconWithOnPaceLine(nil, 50.0, @"", 50.0, NO);
        NSBitmapImageRep *labelOverPaceRep = BitmapForImage(labelOverPace);
        NSBitmapImageRep *paceWithoutLabelRep = BitmapForImage(paceWithoutLabel);
        BOOL foundMaskedMarkerPixel = NO;
        for (NSInteger x = 41; x <= 44 && !foundMaskedMarkerPixel; x++) {
            for (NSInteger y = 5; y <= 12; y++) {
                NSColor *withoutLabel = ColorAt(paceWithoutLabelRep, x, y);
                NSColor *withLabel = ColorAt(labelOverPaceRep, x, y);
                if (withoutLabel.greenComponent > withoutLabel.redComponent &&
                    withLabel.alphaComponent + 0.1 < withoutLabel.alphaComponent) {
                    foundMaskedMarkerPixel = YES;
                    break;
                }
            }
        }
        Assert(foundMaskedMarkerPixel,
               @"percentage glyph masks the pace marker where they overlap");
        NSLog(@"BatteryRendererTests passed");
    }
    return 0;
}
