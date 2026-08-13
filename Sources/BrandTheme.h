#import <UIKit/UIKit.h>

// ── DELTA PROTECT palette (khớp index.php) ──────────────
#define BRAND_BG      [UIColor colorWithRed:0.024 green:0.027 blue:0.039 alpha:1.0]  // #06070a
#define BRAND_BG2     [UIColor colorWithRed:0.043 green:0.075 blue:0.161 alpha:1.0]  // #0b1329
#define BRAND_PURPLE  [UIColor colorWithRed:0.655 green:0.545 blue:0.980 alpha:1.0]  // #a78bfa
#define BRAND_CYAN    [UIColor colorWithRed:0.133 green:0.827 blue:0.933 alpha:1.0]  // #22d3ee
#define BRAND_MUTED   [UIColor colorWithRed:0.561 green:0.561 blue:0.659 alpha:1.0]
#define BRAND_TEXT    [UIColor colorWithRed:0.941 green:0.941 blue:0.961 alpha:1.0]
#define BRAND_GREEN   [UIColor colorWithRed:0.290 green:0.871 blue:0.502 alpha:1.0]  // #4ade80
#define BRAND_RED     [UIColor colorWithRed:0.973 green:0.443 blue:0.443 alpha:1.0]  // #f87171

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
