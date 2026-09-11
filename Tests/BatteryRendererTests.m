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

        NSImage *paceInsideFill = GrokBatteryIconWithOnPaceLine(nil, 50.0, @"", 25.0);
        NSImage *paceOutsideFill = GrokBatteryIconWithOnPaceLine(nil, 25.0, @"", 75.0);
        Assert(paceInsideFill.template && paceOutsideFill.template,
               @"pace battery remains a light/dark adaptive template image");
        NSBitmapImageRep *paceInsideFillRep = BitmapForImage(paceInsideFill);
        NSBitmapImageRep *paceOutsideFillRep = BitmapForImage(paceOutsideFill);
        NSInteger markerX = 34;
        Assert(AlphaAt(paceInsideFillRep, markerX, 9) < 0.05,
               @"pace marker is a contrasting cutout inside the battery fill");
        Assert(AlphaAt(paceOutsideFillRep, 50, 9) > 0.95,
               @"pace marker uses the template tint outside the battery fill");

        NSBitmapImageRep *widthRep = BitmapForImage(
            GrokBatteryIconWithOnPaceLine(nil, 0.0, @"", 50.0));
        Assert(AlphaAt(widthRep, 42, 9) > 0.95,
               @"pace marker is visible outside the fill");
        Assert(AlphaAt(widthRep, 41, 9) < 0.05 && AlphaAt(widthRep, 43, 9) < 0.05,
               @"pace marker is one pixel wide");

        NSBitmapImageRep *softOutsideFillRep = BitmapForImage(
            GrokBatteryIconWithOnPaceLine(nil, 0.0, @"  ", 50.0));
        CGFloat softOutsideAlpha = AlphaAt(softOutsideFillRep, 42, 9);
        Assert(softOutsideAlpha >= 0.50 && softOutsideAlpha <= 0.60,
               @"marker softens to 55 percent opacity beneath the label outside the fill");

        NSBitmapImageRep *softInsideFillRep = BitmapForImage(
            GrokBatteryIconWithOnPaceLine(nil, 100.0, @"  ", 50.0));
        CGFloat softInsideAlpha = AlphaAt(softInsideFillRep, 42, 9);
        Assert(softInsideAlpha >= 0.40 && softInsideAlpha <= 0.50,
               @"marker softens its cutout beneath the label inside the fill");

        NSImage *sampleIcon = [[NSImage alloc] initWithSize:NSMakeSize(18.0, 18.0)];
        [sampleIcon lockFocus];
        [NSColor.blackColor setFill];
        NSRectFill(NSMakeRect(2.0, 2.0, 14.0, 14.0));
        [sampleIcon unlockFocus];
        sampleIcon.template = YES;
        NSBitmapImageRep *iconRep = BitmapForImage(
            GrokBatteryIconWithOnPaceLine(sampleIcon, 50.0, @"", 25.0));
        Assert(AlphaAt(iconRep, 9, 9) > 0.9,
               @"pace rendering retains the supplied template icon");

        NSImage *labelOverPace = GrokBatteryIconWithOnPaceLine(nil, 0.0, @"1", 50.0);
        NSImage *labelWithoutPace = GrokBatteryIconWithLabel(nil, 0.0, @"1");
        NSBitmapImageRep *labelOverPaceRep = BitmapForImage(labelOverPace);
        NSBitmapImageRep *labelWithoutPaceRep = BitmapForImage(labelWithoutPace);
        BOOL foundLabelPixelAtMarker = NO;
        for (NSInteger x = 40; x <= 45; x++) {
            for (NSInteger y = 5; y <= 12; y++) {
                CGFloat referenceAlpha = AlphaAt(labelWithoutPaceRep, x, y);
                if (referenceAlpha > 0.1) {
                    Assert(fabs(AlphaAt(labelOverPaceRep, x, y) - referenceAlpha) < 0.12,
                           @"pace marker does not change percentage glyph pixels");
                    if (x == 42) {
                        foundLabelPixelAtMarker = YES;
                    }
                }
            }
        }
        Assert(foundLabelPixelAtMarker,
               @"percentage glyph crosses and masks the pace marker");
        NSLog(@"BatteryRendererTests passed");
    }
    return 0;
}
