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
        NSLog(@"BatteryRendererTests passed");
    }
    return 0;
}
