#import <UIKit/UIKit.h>

// ── DELTA PROTECT palette — "Aurora Frost" (khớp index.php) ────────────
// Aurora Frost: không gian indigo-đen sâu + surface navy băng + neon accents
#define BRAND_BG      [UIColor colorWithRed:0.020 green:0.024 blue:0.055 alpha:1.0]  // #05060E
#define BRAND_BG2     [UIColor colorWithRed:0.043 green:0.063 blue:0.149 alpha:1.0]  // #0B1026
#define BRAND_PURPLE  [UIColor colorWithRed:0.612 green:0.420 blue:1.000 alpha:1.0]  // #9C6BFF
#define BRAND_CYAN    [UIColor colorWithRed:0.220 green:0.871 blue:1.000 alpha:1.0]  // #38DEFF
#define BRAND_MUTED   [UIColor colorWithRed:0.545 green:0.584 blue:0.741 alpha:1.0]  // #8B95BD
#define BRAND_TEXT    [UIColor colorWithRed:0.953 green:0.957 blue:0.988 alpha:1.0]  // #F3F4FC
#define BRAND_GREEN   [UIColor colorWithRed:0.173 green:0.855 blue:0.545 alpha:1.0]  // #2CDA8B
#define BRAND_RED     [UIColor colorWithRed:1.000 green:0.427 blue:0.451 alpha:1.0]  // #FF6D73

// ── Typography — SF Pro Rounded: chữ bo góc mượt (iOS 13+) ──────────────
// Dùng cho toàn bộ UI thay [UIFont systemFontOfSize:...] để có nét tròn, hiện đại.
static inline UIFont *DELTA_FONT(CGFloat size, UIFontWeight weight) {
    UIFont *system = [UIFont systemFontOfSize:size weight:weight];
    UIFontDescriptor *d = [system.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    if (!d) return system;
    return [UIFont fontWithDescriptor:d size:size];
}
static inline UIFont *DELTA_FONT_REG(CGFloat size)  { return DELTA_FONT(size, UIFontWeightRegular); }
static inline UIFont *DELTA_FONT_BOLD(CGFloat size) { return DELTA_FONT(size, UIFontWeightBold); }

// Gradient thương hiệu: tím → cyan (nút chính)
static inline CAGradientLayer *BrandGradient(void) {
    CAGradientLayer *g = [CAGradientLayer layer];
    g.colors = @[(id)BRAND_PURPLE.CGColor, (id)BRAND_CYAN.CGColor];
    g.startPoint = CGPointMake(0.0, 0.0);
    g.endPoint   = CGPointMake(1.0, 1.0);
    return g;
}

// Quầng sáng radial (glow nền)
static inline CAGradientLayer *BrandRadialGlow(UIColor *color) {
    CAGradientLayer *g = [CAGradientLayer layer];
    g.type = kCAGradientLayerRadial;
    g.colors = @[(id)color.CGColor, (id)[color colorWithAlphaComponent:0].CGColor];
    g.startPoint = CGPointMake(0.5, 0.5);
    g.endPoint   = CGPointMake(1.0, 1.0);
    return g;
}

// Ảnh pattern lưới mờ (nền)
static inline UIColor *BrandGridPattern(void) {
    CGFloat s = 26;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(s, s)];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
        CGContextSetStrokeColorWithColor(ctx.CGContext, [UIColor colorWithWhite:1 alpha:0.04].CGColor);
        CGContextSetLineWidth(ctx.CGContext, 0.5);
        CGContextMoveToPoint(ctx.CGContext, s, 0);  CGContextAddLineToPoint(ctx.CGContext, s, s);
        CGContextMoveToPoint(ctx.CGContext, 0, s);  CGContextAddLineToPoint(ctx.CGContext, s, s);
        CGContextStrokePath(ctx.CGContext);
    }];
    return [UIColor colorWithPatternImage:img];
}
