#import <UIKit/UIKit.h>

// ══════════════════════════════════════════════════════════════════════
//  DELTA PROXY — Design System "OBSIDIAN"
//  Deep neutral dark · single cyan accent · premium enterprise
//  Radius: 10 chips/buttons · 16 cards · 20 sheets
// ══════════════════════════════════════════════════════════════════════

// ── Surfaces ──────────────────────────────────────────────────────────
#define BRAND_BG      [UIColor colorWithRed:0.039 green:0.043 blue:0.063 alpha:1.0]  // #0A0B10
#define BRAND_BG2     [UIColor colorWithRed:0.055 green:0.063 blue:0.090 alpha:1.0]  // #0E1017
#define BRAND_SURFACE [UIColor colorWithRed:0.075 green:0.082 blue:0.114 alpha:1.0]  // #13151D card/row
#define BRAND_TILE    [UIColor colorWithRed:0.106 green:0.118 blue:0.153 alpha:1.0]  // #1B1E27 icon tile
#define BRAND_LIGHT   [UIColor colorWithRed:0.910 green:0.918 blue:0.949 alpha:1.0]  // #E8EAF2 CTA surface

// ── Accent (single) + semantic states ────────────────────────────────
#define BRAND_CYAN    [UIColor colorWithRed:0.208 green:0.839 blue:1.000 alpha:1.0]  // #35D6FF accent
#define BRAND_GREEN   [UIColor colorWithRed:0.204 green:0.827 blue:0.600 alpha:1.0]  // #34D399 success
#define BRAND_RED     [UIColor colorWithRed:0.973 green:0.443 blue:0.443 alpha:1.0]  // #F87171 danger
#define BRAND_YELLOW  [UIColor colorWithRed:0.984 green:0.749 blue:0.141 alpha:1.0]  // #FBBF24 warning

// ── Text / icons ──────────────────────────────────────────────────────
#define BRAND_TEXT    [UIColor colorWithRed:0.961 green:0.965 blue:0.980 alpha:1.0]  // #F5F6FA body
#define BRAND_MUTED   [UIColor colorWithRed:0.541 green:0.565 blue:0.635 alpha:1.0]  // #8A90A2 secondary
#define BRAND_ICON    [UIColor colorWithRed:0.431 green:0.455 blue:0.529 alpha:1.0]  // #6E7487 glyph idle

// Hairline border: rgba(255,255,255,0.07)
#define BRAND_HAIR    [UIColor colorWithWhite:1 alpha:0.07]

// BRAND_PURPLE giữ tên cho tương thích code cũ — giờ là trung tính (muted icon)
#define BRAND_PURPLE  BRAND_ICON

// ── Typography — SF Pro Rounded: chữ bo góc mượt (iOS 13+) ──────────────
static inline UIFont *DELTA_FONT(CGFloat size, UIFontWeight weight) {
    UIFont *system = [UIFont systemFontOfSize:size weight:weight];
    UIFontDescriptor *d = [system.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    if (!d) return system;
    return [UIFont fontWithDescriptor:d size:size];
}
static inline UIFont *DELTA_FONT_REG(CGFloat size)  { return DELTA_FONT(size, UIFontWeightRegular); }
static inline UIFont *DELTA_FONT_BOLD(CGFloat size) { return DELTA_FONT(size, UIFontWeightBold); }

// ── Elevation: soft shadow, opacity ≤ 0.2 (không neon) ────────────────
static inline void DeltaSoftShadow(UIView *v, UIColor *color, CGFloat opacity, CGFloat radius, CGFloat dy) {
    v.layer.shadowColor   = color.CGColor;
    v.layer.shadowOpacity = opacity;
    v.layer.shadowRadius  = radius;
    v.layer.shadowOffset  = CGSizeMake(0, dy);
}

// Legacy gradient helpers (giữ để không vỡ code cũ; UI mới không dùng)
static inline CAGradientLayer *BrandGradient(void) {
    CAGradientLayer *g = [CAGradientLayer layer];
    g.colors = @[(id)BRAND_CYAN.CGColor, (id)BRAND_CYAN.CGColor];
    g.startPoint = CGPointMake(0.0, 0.0);
    g.endPoint   = CGPointMake(1.0, 1.0);
    return g;
}

// ── Carbon-fiber texture (rất nhẹ, cho nền) ─────────────────────────────
static inline UIColor *DeltaCarbonTexture(void) {
    CGFloat s = 16;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(s, s)];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
        CGContextRef cg = ctx.CGContext;
        CGContextSetStrokeColorWithColor(cg, [UIColor colorWithWhite:1 alpha:0.028].CGColor);
        CGContextSetLineWidth(cg, 0.5);
        // Weave chéo 2 hướng
        CGContextMoveToPoint(cg, 0, 0);     CGContextAddLineToPoint(cg, s, s);
        CGContextMoveToPoint(cg, 0, s/2);   CGContextAddLineToPoint(cg, s/2, s);
        CGContextMoveToPoint(cg, s/2, 0);   CGContextAddLineToPoint(cg, s, s/2);
        CGContextMoveToPoint(cg, 0, s);     CGContextAddLineToPoint(cg, s, 0);
        CGContextStrokePath(cg);
        // Nút dệt sáng hơn một chút
        CGContextSetFillColorWithColor(cg, [UIColor colorWithWhite:1 alpha:0.05].CGColor);
        CGContextFillRect(cg, CGRectMake(s/2 - 0.4, s/2 - 0.4, 0.8, 0.8));
    }];
    return [UIColor colorWithPatternImage:img];
}
static inline CAGradientLayer *BrandRadialGlow(UIColor *color) {
    CAGradientLayer *g = [CAGradientLayer layer];
    g.type = kCAGradientLayerRadial;
    g.colors = @[(id)color.CGColor, (id)[color colorWithAlphaComponent:0].CGColor];
    g.startPoint = CGPointMake(0.5, 0.5);
    g.endPoint   = CGPointMake(1.0, 1.0);
    return g;
}
static inline UIColor *BrandGridPattern(void) {
    CGFloat s = 26;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(s, s)];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
        CGContextSetStrokeColorWithColor(ctx.CGContext, [UIColor colorWithWhite:1 alpha:0.02].CGColor);
        CGContextSetLineWidth(ctx.CGContext, 0.5);
        CGContextMoveToPoint(ctx.CGContext, s, 0);  CGContextAddLineToPoint(ctx.CGContext, s, s);
        CGContextMoveToPoint(ctx.CGContext, 0, s);  CGContextAddLineToPoint(ctx.CGContext, s, s);
        CGContextStrokePath(ctx.CGContext);
    }];
    return [UIColor colorWithPatternImage:img];
}
