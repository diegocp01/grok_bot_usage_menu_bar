#import "BatteryRenderer.h"

#import <math.h>

NSImage *GrokBatteryIconWithLabel(NSImage *grokIcon, double percent, NSString *label) {
    double clamped = MAX(0.0, MIN(100.0, percent));
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(67.0, 18.0)];
    [image lockFocus];

    [NSColor.blackColor set];
    if (grokIcon != nil) {
        [grokIcon drawInRect:NSMakeRect(0.0, 0.0, 18.0, 18.0)];
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

    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:8.5 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: NSColor.blackColor
    };
    NSSize labelSize = [label sizeWithAttributes:attributes];
    NSPoint labelPoint = NSMakePoint(NSMidX(body) - labelSize.width / 2.0,
                                     NSMidY(body) - labelSize.height / 2.0 - 0.5);

    // Template images are tinted as a single color by macOS. Keep the label opaque
    // over the empty area, then punch it out over the fill so each side always has
    // the opposite menu-bar color and remains readable in light and dark modes.
    [label drawAtPoint:labelPoint withAttributes:attributes];
    if (fillPath != nil) {
        [NSGraphicsContext saveGraphicsState];
        [fillPath addClip];
        NSGraphicsContext.currentContext.compositingOperation = NSCompositingOperationClear;
        [label drawAtPoint:labelPoint withAttributes:attributes];
        [NSGraphicsContext restoreGraphicsState];
    }

    [image unlockFocus];
    image.template = YES;
    return image;
}

NSImage *GrokBatteryIcon(NSImage *grokIcon, double percent) {
    double clamped = MAX(0.0, MIN(100.0, percent));
    return GrokBatteryIconWithLabel(grokIcon,
                                    clamped,
                                    [NSString stringWithFormat:@"%.0f", clamped]);
}
