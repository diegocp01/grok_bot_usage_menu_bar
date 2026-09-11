#import "BatteryRenderer.h"

#import <math.h>

double GrokOnPacePercent(NSTimeInterval now,
                         NSTimeInterval periodStart,
                         NSTimeInterval reset) {
    double duration = reset - periodStart;
    double remaining = reset - now;
    if (!isfinite(now) || !isfinite(periodStart) || !isfinite(reset) || duration <= 0.0) {
        return NAN;
    }
    return MAX(0.0, MIN(100.0, (remaining / duration) * 100.0));
}

static NSImage *BatteryIcon(NSImage *grokIcon,
                            double percent,
                            NSString *label,
                            double onPacePercent,
                            BOOL darkAppearance) {
    double clamped = MAX(0.0, MIN(100.0, percent));
    BOOL showsOnPaceLine = isfinite(onPacePercent);
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(67.0, 18.0)];
    [image lockFocus];

    NSColor *foreground = showsOnPaceLine
        ? (darkAppearance ? NSColor.whiteColor : NSColor.blackColor)
        : NSColor.blackColor;
    [foreground set];
    if (grokIcon != nil) {
        NSImage *drawableIcon = [grokIcon copy];
        drawableIcon.template = NO;
        [drawableIcon drawInRect:NSMakeRect(0.0, 0.0, 18.0, 18.0)];
        if (showsOnPaceLine) {
            [foreground setFill];
            NSRectFillUsingOperation(NSMakeRect(0.0, 0.0, 18.0, 18.0),
                                     NSCompositingOperationSourceAtop);
        }
    }

    NSRect body = NSMakeRect(25.0, 2.5, 35.0, 13.0);
    NSBezierPath *outline = [NSBezierPath bezierPathWithRoundedRect:body xRadius:2.3 yRadius:2.3];
    outline.lineWidth = 1.5;
    [outline stroke];

    NSRect nub = NSMakeRect(NSMaxX(body) + 1.2, 6.25, 2.2, 5.5);
    [[NSBezierPath bezierPathWithRoundedRect:nub xRadius:0.8 yRadius:0.8] fill];

    CGFloat available = body.size.width - 4.0;
    CGFloat fillWidth = available * (clamped / 100.0);
    NSBezierPath *fillPath = nil;
    if (fillWidth > 0.5) {
        NSRect fill = NSMakeRect(body.origin.x + 2.0, body.origin.y + 2.0,
                                 fillWidth, body.size.height - 4.0);
        fillPath = [NSBezierPath bezierPathWithRoundedRect:fill xRadius:1.1 yRadius:1.1];
        [fillPath fill];
    }

    if (showsOnPaceLine) {
        CGFloat pace = MAX(0.0, MIN(100.0, onPacePercent));
        NSRect interior = NSMakeRect(body.origin.x + 2.0, body.origin.y + 2.0,
                                     available, body.size.height - 4.0);
        CGFloat markerX = NSMinX(interior) + interior.size.width * (pace / 100.0);
        markerX = MAX(NSMinX(interior) + 0.5, MIN(NSMaxX(interior) - 0.5, markerX));
        NSRect marker = NSMakeRect(markerX - 0.5, NSMinY(interior), 1.0, NSHeight(interior));
        [NSGraphicsContext saveGraphicsState];
        [[NSBezierPath bezierPathWithRoundedRect:interior xRadius:1.1 yRadius:1.1] addClip];
        [[[NSColor systemGreenColor] colorWithAlphaComponent:0.65] setFill];
        NSRectFill(marker);
        [NSGraphicsContext restoreGraphicsState];
    }

    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:8.5 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: foreground
    };
    NSSize labelSize = [label sizeWithAttributes:attributes];
    NSPoint labelPoint = NSMakePoint(NSMidX(body) - labelSize.width / 2.0,
                                     NSMidY(body) - labelSize.height / 2.0 - 0.5);

    // Draw the percentage last so its glyphs mask both the fill and the pace marker.
    // Over the empty area the opaque foreground remains readable; over the fill the
    // glyph is punched out to reveal the menu-bar color beneath it.
    [label drawAtPoint:labelPoint withAttributes:attributes];
    if (fillPath != nil) {
        [NSGraphicsContext saveGraphicsState];
        [fillPath addClip];
        NSGraphicsContext.currentContext.compositingOperation = NSCompositingOperationClear;
        [label drawAtPoint:labelPoint withAttributes:attributes];
        [NSGraphicsContext restoreGraphicsState];
    }

    [image unlockFocus];
    image.template = !showsOnPaceLine;
    return image;
}

NSImage *GrokBatteryIconWithLabel(NSImage *grokIcon, double percent, NSString *label) {
    return BatteryIcon(grokIcon, percent, label, NAN, NO);
}

NSImage *GrokBatteryIconWithOnPaceLine(NSImage *grokIcon,
                                      double percent,
                                      NSString *label,
                                      double onPacePercent,
                                      BOOL darkAppearance) {
    return BatteryIcon(grokIcon, percent, label, onPacePercent, darkAppearance);
}

NSImage *GrokBatteryIcon(NSImage *grokIcon, double percent) {
    double clamped = MAX(0.0, MIN(100.0, percent));
    return GrokBatteryIconWithLabel(grokIcon,
                                    clamped,
                                    [NSString stringWithFormat:@"%.0f", clamped]);
}
