//
//  LaTeXView.mm
//  MicroTexdemo
//
//  Created by reikjiang on 2025/5/1.
//

#import "LaTeXView.h"
#import <memory> // For std::unique_ptr
#import <stdexcept>

// MicroTeX Headers
#import "microtex.h"
#import "render/render.h"
#import "graphic/graphic_basic.h"
#import "graphic_cg.h"

// Default values
static const CGFloat kDefaultLatexFontSize = 17.0f;
static const CGFloat kDefaultLineSpacing = 1.0f;

// Helper to convert UIColor to microtex::color
static microtex::color microtexColorFromUIColor(UIColor *uiColor) {
    CGFloat r, g, b, a;
    // Ensure color is in RGB color space for getRed:green:blue:alpha:
    UIColor *rgbColor = uiColor;
    if (CGColorGetNumberOfComponents(uiColor.CGColor) == 2) { // Grayscale
        CGFloat white, alpha;
        if ([uiColor getWhite:&white alpha:&alpha]) {
            rgbColor = [UIColor colorWithRed:white green:white blue:white alpha:alpha];
        } else {
            // Fallback or error handling if conversion fails
            rgbColor = [UIColor blackColor]; // Or some other default
        }
    }
    
    [rgbColor getRed:&r green:&g blue:&b alpha:&a];
    return microtex::argb(
        static_cast<int>(a * 255),
        static_cast<int>(r * 255),
        static_cast<int>(g * 255),
        static_cast<int>(b * 255)
    );
}

@implementation LaTeXView {
    // Declare renderInstance as a direct C++ instance variable
    std::unique_ptr<microtex::Render> _renderInstance;
}

#pragma mark – Init / Dealloc

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    _latexFontSize = kDefaultLatexFontSize;
    _lineSpacing   = kDefaultLineSpacing;
    _textColor     = [UIColor blackColor];
    _fillWidth     = YES;
    self.backgroundColor = [UIColor clearColor];
}

#pragma mark – Property Setters

- (void)handleRenderPropertyChanged {
    _renderInstance.reset(); // Invalidate the current C++ render object
    [self setNeedsDisplay];
    [self invalidateIntrinsicContentSize];
}

- (void)setLatexString:(nullable NSString *)latexString {
    // Ensure comparison handles nil correctly
    if (!(_latexString == latexString || [_latexString isEqualToString:latexString])) {
        _latexString = [latexString copy];
        [self handleRenderPropertyChanged];
    }
}

- (void)setLatexFontSize:(CGFloat)latexFontSize {
    if (_latexFontSize != latexFontSize) {
        _latexFontSize = latexFontSize;
        [self handleRenderPropertyChanged];
    }
}

- (void)setLineSpacing:(CGFloat)lineSpacing {
    if (_lineSpacing != lineSpacing) {
        _lineSpacing = lineSpacing;
        [self handleRenderPropertyChanged];
    }
}

- (void)setTextColor:(UIColor *)textColor {
    if (![_textColor isEqual:textColor]) {
        _textColor = textColor;
        [self handleRenderPropertyChanged];
    }
}

- (void)setFillWidth:(BOOL)fillWidth {
    if (_fillWidth != fillWidth) {
        _fillWidth = fillWidth;
        [self handleRenderPropertyChanged];
    }
}

#pragma mark – Render Management

- (std::unique_ptr<microtex::Render>)createRenderObjectForWidth:(float)width useFillWidthFlag:(BOOL)useFillWidthFlag {
    if (self.latexString.length == 0) {
        return nullptr;
    }

    const char *latexCString = [self.latexString UTF8String];
    if (!latexCString) { // self.latexString might be empty or contain non-UTF8 compatible chars
        NSLog(@"LaTeXView: Could not convert latexString to UTF8String: %@", self.latexString);
        return nullptr;
    }
    std::string latexStdString(latexCString);
    microtex::color txColor = microtexColorFromUIColor(self.textColor);
    microtex::Render* rawRender = nullptr;

    // Determine the actual width to pass to MicroTeX.
    // If useFillWidthFlag is true, and width > 0, MicroTeX uses it for wrapping.
    // If width is 0, MicroTeX calculates natural width.
    float effectiveParseWidth = useFillWidthFlag ? width : 0.0f;

    try {
        rawRender = microtex::MicroTeX::parse(
            latexStdString,
            effectiveParseWidth,
            self.latexFontSize,
            self.lineSpacing,
            txColor,
            useFillWidthFlag // This flag might control internal logic like line breaking even if width is 0
        );
    } catch (const std::exception &ex) {
        NSLog(@"MicroTeX parse exception: %s for LaTeX: %@", ex.what(), self.latexString);
    } catch (...) {
        NSLog(@"MicroTeX parse unknown exception for LaTeX: %@", self.latexString);
    }

    if (!rawRender) {
        // NSLog is good, but avoid flooding if it happens repeatedly for the same string.
        // Consider more robust error reporting or a placeholder render.
        NSLog(@"Failed to parse LaTeX: %@", self.latexString);
    }
    return std::unique_ptr<microtex::Render>(rawRender);
}

- (void)ensureRenderInstance {
    if (!_renderInstance) {
        float parseWidth = 0.0f;
        if (self.fillWidth) {
             // Only use bounds width if it's positive, otherwise, MicroTeX will use natural width.
            if (CGRectGetWidth(self.bounds) > 0) {
                parseWidth = CGRectGetWidth(self.bounds);
            }
        }
        // Pass self.fillWidth as the flag to MicroTeX::parse
        _renderInstance = [self createRenderObjectForWidth:parseWidth useFillWidthFlag:self.fillWidth];
    }
}

#pragma mark – Drawing

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    if (self.latexString.length == 0) {
        return;
    }

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        NSLog(@"LaTeXView: could not get CGContextRef");
        return;
    }

    [self ensureRenderInstance];
    if (!_renderInstance) {
        // Optionally draw an error message or placeholder if parsing failed
        return;
    }

    microtex::Graphics2D_cg g2(ctx);
    g2.setColor(microtexColorFromUIColor(self.textColor)); // Set color on the graphics context

    // Draw at the top-left of the view's bounds
    _renderInstance->draw(g2, 0.0f, 0.0f);
}

#pragma mark – Sizing

- (CGSize)sizeThatFits:(CGSize)size {
    if (self.latexString.length == 0) {
        return CGSizeZero;
    }

    float measureWidth = 0.0f; // Default to natural width
    BOOL useFillWidthForSizing = self.fillWidth;

    if (self.fillWidth && size.width > 0 && size.width != CGFLOAT_MAX) {
        measureWidth = size.width;
    } else if (!self.fillWidth) {
        // If not filling width, always measure natural width
        useFillWidthForSizing = false;
    }
    // If self.fillWidth is true but no specific width is given (size.width is 0 or CGFLOAT_MAX),
    // we still want to pass fillWidth=true to parse, but with measureWidth=0,
    // to let MicroTeX potentially calculate a "natural wrapped width" if it supports such a concept,
    // or just natural width. The key is `useFillWidthForSizing` informs the parsing call.

    std::unique_ptr<microtex::Render> tempRender = [self createRenderObjectForWidth:measureWidth useFillWidthFlag:useFillWidthForSizing];

    if (!tempRender) {
        return CGSizeZero;
    }
    return CGSizeMake(ceilf(tempRender->getWidth()), ceilf(tempRender->getHeight()));
}

- (CGSize)intrinsicContentSize {
    if (self.latexString.length == 0) {
        // For an empty string, if you want it to have *some* size (e.g., height of one line of default font size)
        // you could return that. For now, CGSizeZero is fine.
        return CGSizeZero;
    }
    
    float intrinsicMeasureWidth = 0.0f;
    BOOL useFillWidthForIntrinsic = self.fillWidth;

    if (self.fillWidth) {
        // If fillWidth is true, the intrinsic width is technically "as wide as it's allowed to be".
        // Auto Layout often provides a width constraint. If self.bounds.size.width is set, use it.
        if (CGRectGetWidth(self.bounds) > 0) {
            intrinsicMeasureWidth = CGRectGetWidth(self.bounds);
        } else {
            // If bounds width is not yet known and fillWidth is true, we have a dilemma.
            // Option 1: Return UIViewNoIntrinsicMetric for width. This tells Auto Layout
            // "I don't have an intrinsic width; you must constrain me." Height would be calculated
            // based on a conceptual "infinite" width or a default width.
            // Option 2: Calculate based on natural width (passing 0 for width).
            // Let's try to return natural width if bounds aren't set, but still indicate fillWidth to MicroTeX.
            // This makes `useFillWidthForIntrinsic = true` and `intrinsicMeasureWidth = 0.0f`.
        }
    } else {
        // Not filling width, so calculate natural width.
        useFillWidthForIntrinsic = false;
    }

    std::unique_ptr<microtex::Render> tempRender = [self createRenderObjectForWidth:intrinsicMeasureWidth useFillWidthFlag:useFillWidthForIntrinsic];

    if (!tempRender) {
        return CGSizeZero;
    }
    
    CGFloat calculatedWidth = ceilf(tempRender->getWidth());
    CGFloat calculatedHeight = ceilf(tempRender->getHeight());

    if (self.fillWidth && intrinsicMeasureWidth == 0.0f && CGRectGetWidth(self.bounds) == 0.0f) {
        // If we are filling width, but had to calculate based on natural width because no bounds were available,
        // the width is not truly "intrinsic" in a fixed sense. It's "intrinsic IF unconstrained".
        // For Auto Layout, this can be signaled by returning UIViewNoIntrinsicMetric for the width dimension.
        // This means height depends on the width Auto Layout gives us.
        // return CGSizeMake(UIViewNoIntrinsicMetric, calculatedHeight);
        // However, for simplicity and if MicroTeX handles width=0 with fillWidth=true sensibly (e.g. natural width),
        // returning the calculated natural width is often a practical approach.
        // If this causes layout issues (e.g., view becomes too wide), then UIViewNoIntrinsicMetric is better for width.
    }

    return CGSizeMake(calculatedWidth, calculatedHeight);
}

@end
