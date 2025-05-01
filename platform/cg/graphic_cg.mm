#import "graphic_cg.h"

// --- FIX: Add missing MicroTeX includes ---
#include "graphic/graphic.h" // For color type AND likely Red/Green/Blue/Alpha accessors
#include "utils/log.h"       // For _log / _logv macros
#include "utils/exceptions.h" // For error handling (if used)
#include "utils/nums.h"
#include "utils/types.h"
#include "utils/utils.h"

// --- FIX: Add missing UIKit import ---
#import <UIKit/UIKit.h> // <-- Include full UIKit for UIFont etc.

#include <CoreText/CoreText.h>
#include <Foundation/Foundation.h>
#include <ImageIO/ImageIO.h> // For potential future use if loading fonts differently
#include <mutex> // For thread safety (recommended)
#include <cmath> // For M_PI
#include <iostream> // For error logging

#define _log(...)  {}
#define _logv(...)  {}

// Helper to convert microtex color to CGColorRef
// IMPORTANT: The caller must release the returned CGColorRef when done!
CGColorRef microtex::Gfx_CreateCGColor(microtex::color c) {
    // --- FIX: Use the correct accessor functions from graphic_basic.h ---
    CGFloat r = static_cast<CGFloat>(microtex::color_r(c)) / 255.0; // Use color_r
    CGFloat g = static_cast<CGFloat>(microtex::color_g(c)) / 255.0; // Use color_g
    CGFloat b = static_cast<CGFloat>(microtex::color_b(c)) / 255.0; // Use color_b
    CGFloat a = static_cast<CGFloat>(microtex::color_a(c)) / 255.0; // Use color_a

    // Using device-independent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = {r, g, b, a};
    CGColorRef colorRef = CGColorCreate(colorSpace, components);
    CGColorSpaceRelease(colorSpace);
    return colorRef;
}


namespace microtex {

// Static cache and mutex for Font_cg
std::map<std::string, CTFontRef> Font_cg::_fontCache;
// std::mutex Font_cg::_cacheMutex; // Uncomment and use lock_guard for thread safety

Font_cg::Font_cg(const std::string& file) {
    loadFont(file);
}

Font_cg::~Font_cg() {
    // Release the font ONLY if this instance created it and it's not in the cache
    // The cache should retain its own reference. A better approach uses smart pointers
    // or relies purely on the cache. For simplicity here, we assume cache owns it.
    // If _ctFont was assigned from cache, CFRelease would be wrong here.
    // Proper management needs ref counting or smart pointers for CF types.
    // Let's assume the cache correctly manages lifetime for now.
    // If _ctFont is non-null AND not in cache (e.g., loading failed but ptr assigned), release.
    // This simplified version assumes _ctFont is null if loading failed.
}

Font_cg::Font_cg(Font_cg&& other) noexcept : _ctFont(other._ctFont) {
    other._ctFont = nullptr; // Transfer ownership
}

Font_cg& Font_cg::operator=(Font_cg&& other) noexcept {
    if (this != &other) {
        // Release current font if necessary (complex with caching)
        // For simplicity, assume cache manages lifetime
        _ctFont = other._ctFont;
        other._ctFont = nullptr;
    }
    return *this;
}

void Font_cg::loadFont(const std::string& file) {
    // std::lock_guard<std::mutex> lock(_cacheMutex); // Lock for thread safety
    if (auto it = _fontCache.find(file); it != _fontCache.end()) {
        _ctFont = it->second; // Found in cache, use cached version (already retained)
        return;
    }

    NSString* nsFilePath = [NSString stringWithUTF8String:file.c_str()];
    if (!nsFilePath) {
        // --- FIX: Ensure _log is available ---
        _log("Error: Could not convert file path to NSString: %s\n", file.c_str());
        return;
    }

    NSURL* fontURL = [NSURL fileURLWithPath:nsFilePath];
    if (!fontURL) {
        // --- FIX: Ensure _log is available ---
        _log("Error: Could not create NSURL for path: %s\n", [nsFilePath UTF8String]);
        return;
    }

    CGDataProviderRef provider = CGDataProviderCreateWithURL((__bridge CFURLRef)fontURL);
    if (!provider) {
        // --- FIX: Ensure _log is available ---
        _log("Error: Could not create CGDataProvider for URL: %s\n", [[fontURL path] UTF8String]);
        return;
    }

    CGFontRef cgFont = CGFontCreateWithDataProvider(provider);
    CGDataProviderRelease(provider);

    if (!cgFont) {
       // --- FIX: Ensure _log is available ---
       _log("Error: Could not create CGFont from data provider for: %s\n", [[fontURL path] UTF8String]);
        return;
    }

    CTFontRef ctFont = CTFontCreateWithGraphicsFont(cgFont, 1.0, NULL, NULL);
    CGFontRelease(cgFont);

    if (!ctFont) {
        // --- FIX: Ensure _log is available ---
        _log("Error: Could not create CTFont from CGFont for: %s\n", [[fontURL path] UTF8String]);
        return;
    }

    _fontCache[file] = ctFont;
    _ctFont = ctFont;

    // --- FIX: Ensure _logv is available ---
    _logv("Successfully loaded font: %s\n", file.c_str());
}

bool Font_cg::operator==(const Font& f) const {
    const auto* other = dynamic_cast<const Font_cg*>(&f);
    if (!other) return false;
    // Comparing CTFontRefs directly should work if they point to the same underlying font object
    return _ctFont != nullptr && other->_ctFont != nullptr && CFEqual(_ctFont, other->_ctFont);
}

CTFontRef Font_cg::getCTFont() const {
    return _ctFont;
}

/**************************************************************************************************/

TextLayout_cg::TextLayout_cg(const std::string& src, FontStyle style, float size) :
    _textLen(src.length())
{
    NSString* nsString = [[NSString alloc] initWithUTF8String:src.c_str()];
    if (!nsString) {
        throw std::runtime_error("Failed to convert std::string to NSString");
    }

    // --- FIX: Now UIFont methods/constants should be available ---
    UIFont* uiFont = nil;
    if (isBold(style) && isItalic(style)) {
        // Use modern API if available, check deployment target
        if (@available(iOS 8.2, *)) {
            uiFont = [UIFont systemFontOfSize:size weight:UIFontWeightBold];
        } else {
            uiFont = [UIFont boldSystemFontOfSize:size]; // Fallback
        }
        // Apply italic trait
        UIFontDescriptor* descriptor = [uiFont.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic | UIFontDescriptorTraitBold];
        uiFont = [UIFont fontWithDescriptor:descriptor size:size];
    } else if (isBold(style)) {
        if (@available(iOS 8.2, *)) {
            uiFont = [UIFont systemFontOfSize:size weight:UIFontWeightBold];
        } else {
            uiFont = [UIFont boldSystemFontOfSize:size]; // Fallback
        }
    } else if (isItalic(style)) {
        uiFont = [UIFont italicSystemFontOfSize:size];
    } else {
        uiFont = [UIFont systemFontOfSize:size];
    }
    // Shouldn't need this check if UIKit.h is included, but good practice
    if (!uiFont) {
        // Fallback to a very basic system font if style application failed
        uiFont = [UIFont systemFontOfSize:size];
        if (!uiFont) { // If even that fails, something is very wrong
           throw std::runtime_error("Failed to create any UIFont instance");
        }
    }

    CTFontRef ctFont = (__bridge CTFontRef)uiFont;

    NSDictionary* attributes = @{
         (id)kCTFontAttributeName : (__bridge id)ctFont,
    };

    _attrString = [[NSAttributedString alloc] initWithString:nsString attributes:attributes];

    if (!_attrString) {
        throw std::runtime_error("Failed to create NSAttributedString");
    }

    _ctLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)_attrString);
    if (!_ctLine) {
        _attrString = nil;
        throw std::runtime_error("Failed to create CTLine");
    }

    calculateBounds();
}

TextLayout_cg::~TextLayout_cg() {
    if (_ctLine) {
        CFRelease(_ctLine);
        _ctLine = nullptr;
    }
    if (_attrString) {
        _attrString = nullptr;
     }
}

TextLayout_cg::TextLayout_cg(TextLayout_cg&& other) noexcept
    : _attrString(other._attrString),
      _ctLine(other._ctLine),
      _bounds(other._bounds),
      _textLen(other._textLen)
{
    other._attrString = nil;
    other._ctLine = nullptr;
}

TextLayout_cg& TextLayout_cg::operator=(TextLayout_cg&& other) noexcept {
    if (this != &other) {
        if (_ctLine) CFRelease(_ctLine);

        _attrString = other._attrString;
        _ctLine = other._ctLine;
        _bounds = other._bounds;
        _textLen = other._textLen;

        other._attrString = nil;
        other._ctLine = nullptr;
    }
    return *this;
}

void TextLayout_cg::calculateBounds() {
    if (!_ctLine) return;
    CGFloat ascent, descent, leading;
    double width = CTLineGetTypographicBounds(_ctLine, &ascent, &descent, &leading);

    // CTLineGetImageBounds gives visual bounds, might be tighter
    CGRect imageBounds = CTLineGetImageBounds(_ctLine, NULL);

    // MicroTeX Rect expects x, y (top-left), w, h
    // Core Text ascent is above baseline, descent below. Total typographical height = ascent + descent.
    // Image bounds y is typically negative (origin at baseline).
    _bounds.x = imageBounds.origin.x; // Often 0 for left alignment
    _bounds.y = -ascent; // Top relative to baseline (approx)
    _bounds.w = width; // Typographic width
    _bounds.h = ascent + descent; // Typographical height
}

void TextLayout_cg::getBounds(Rect& bounds) {
    bounds = _bounds;
}

void TextLayout_cg::draw(Graphics2D& g2, float x, float y) {
    if (!_ctLine) return;

    // Downcast to our CG implementation
    Graphics2D_cg& g = static_cast<Graphics2D_cg&>(g2);
    CGContextRef ctx = g.getCGContext();
    if (!ctx) return;

    // Save graphics state before drawing text
    CGContextSaveGState(ctx);

    // Core Graphics Y-axis is typically flipped compared to CT/Skia baseline origin.
    // We need to adjust the drawing position based on the context's CTM.
    // Assuming context is standard UIKit (Y=0 at top):
    // baseline = y
    // CTLineDraw expects position = bottom-left of the line's origin (baseline start)
    CGContextSetTextPosition(ctx, x, y);

    // Set the fill color from the graphics context
    // We assume the Graphics2D_cg has already set the correct CGFillColor.
    // If not, we'd apply it here: CGContextSetFillColorWithColor(ctx, g.getCurrentCGColor());

    // Draw the line
    CTLineDraw(_ctLine, ctx);

    // Restore graphics state
    CGContextRestoreGState(ctx);
}

/**************************************************************************************************/

sptr<Font> PlatformFactory_cg::createFont(const std::string& file) {
    try {
        return sptrOf<Font_cg>(file);
    } catch (const std::exception& e) {
        _log("Error creating font '%s': %s\n", file.c_str(), e.what());
        return nullptr;
    }
}

sptr<TextLayout> PlatformFactory_cg::createTextLayout(
    const std::string& src,
    FontStyle style,
    float size
) {
     try {
        return sptrOf<TextLayout_cg>(src, style, size);
     } catch (const std::exception& e) {
        _log("Error creating text layout: %s\n", e.what());
        return nullptr;
     }
}

/**************************************************************************************************/

Graphics2D_cg::Graphics2D_cg(CGContextRef context) :
    _context(context), // Non-owning reference
    _color(BLACK),
    _fontSize(10.f), // Default font size
    _sx(1.f), _sy(1.f)
{
    // Retain the context? No, assume external management.
    // Initialize default state
    setColor(_color); // Set initial CGColorRefs
    setStroke(Stroke()); // Set default stroke
    _path = CGPathCreateMutable();
}

Graphics2D_cg::~Graphics2D_cg() {
    releaseColorRefs();
    if (_path) {
        CGPathRelease(_path);
        _path = nullptr;
    }
}

void Graphics2D_cg::releaseColorRefs() {
    if (_cgFillColor) {
        CGColorRelease(_cgFillColor);
        _cgFillColor = nullptr;
    }
     if (_cgStrokeColor) {
        CGColorRelease(_cgStrokeColor);
        _cgStrokeColor = nullptr;
    }
}

CGContextRef Graphics2D_cg::getCGContext() const {
    return _context;
}

void Graphics2D_cg::applyFillColor() {
    if (_context && _cgFillColor) {
        CGContextSetFillColorWithColor(_context, _cgFillColor);
    }
}

void Graphics2D_cg::applyStrokeColor() {
     if (_context && _cgStrokeColor) {
        CGContextSetStrokeColorWithColor(_context, _cgStrokeColor);
    }
}

void Graphics2D_cg::applyStrokeStyle() {
    if (!_context) return;
    CGContextSetLineWidth(_context, _stroke.lineWidth);
    CGContextSetMiterLimit(_context, _stroke.miterLimit);

    CGLineCap cap;
    switch (_stroke.cap) {
        case CAP_BUTT:   cap = kCGLineCapButt; break;
        case CAP_ROUND:  cap = kCGLineCapRound; break;
        case CAP_SQUARE: cap = kCGLineCapSquare; break;
        default:         cap = kCGLineCapButt; break;
    }
    CGContextSetLineCap(_context, cap);

    CGLineJoin join;
    switch (_stroke.join) {
        case JOIN_MITER: join = kCGLineJoinMiter; break;
        case JOIN_ROUND: join = kCGLineJoinRound; break;
        case JOIN_BEVEL: join = kCGLineJoinBevel; break;
        default:         join = kCGLineJoinMiter; break;
    }
    CGContextSetLineJoin(_context, join);

    applyStrokeColor(); // Color is part of stroke style application
}

void Graphics2D_cg::setColor(microtex::color c) {
    _color = c;
    releaseColorRefs(); // Release old colors
    _cgFillColor = Gfx_CreateCGColor(c);
    _cgStrokeColor = Gfx_CreateCGColor(c); // Create separate stroke color ref
    // Apply immediately? Or wait until draw? Let's apply here.
    applyFillColor();
    applyStrokeColor();
}

color Graphics2D_cg::getColor() const {
    return _color;
}

void Graphics2D_cg::setStroke(const Stroke& s) {
    _stroke = s;
    // Apply immediately? Or wait until draw? Let's apply here.
    applyStrokeStyle();
}

const Stroke& Graphics2D_cg::getStroke() const {
    return _stroke;
}

void Graphics2D_cg::setStrokeWidth(float w) {
    _stroke.lineWidth = w;
    if (_context) {
      CGContextSetLineWidth(_context, w);
    }
}

void Graphics2D_cg::setDash(const std::vector<float>& dash) {
    _dash = dash;
    if (_context) {
        if (_dash.empty()) {
             // Phase 0, count 0, lengths NULL -> Solid line
             CGContextSetLineDash(_context, 0, NULL, 0);
        } else {
            // Need conversion to CGFloat array
            std::vector<CGFloat> cgDash;
            cgDash.reserve(_dash.size());
            for (float val : _dash) {
                cgDash.push_back(static_cast<CGFloat>(val));
            }
            CGContextSetLineDash(_context, 0, cgDash.data(), cgDash.size());
        }
    }
}

std::vector<float> Graphics2D_cg::getDash() {
    return _dash;
}

sptr<Font> Graphics2D_cg::getFont() const {
    return std::static_pointer_cast<Font>(_font);
}

void Graphics2D_cg::setFont(const sptr<Font>& font) {
    // Attempt to downcast to our CG implementation
    _font = std::dynamic_pointer_cast<Font_cg>(font);
    if (!font) {
        _log("Warning: Setting font failed, incorrect font type provided.\n");
    } else if (_font && !_font->getCTFont()) {
         _log("Warning: Set font is valid type but has no loaded CTFont.\n");
         _font = nullptr; // Treat as invalid
    }
}

float Graphics2D_cg::getFontSize() const {
    return _fontSize;
}

void Graphics2D_cg::setFontSize(float size) {
    _fontSize = size;
}

void Graphics2D_cg::translate(float dx, float dy) {
    if (_context) {
        CGContextTranslateCTM(_context, dx, dy);
    }
}

void Graphics2D_cg::scale(float sx, float sy) {
    _sx *= sx;
    _sy *= sy;
    if (_context) {
        CGContextScaleCTM(_context, sx, sy);
    }
}

void Graphics2D_cg::rotate(float angle) {
    if (_context) {
        CGContextRotateCTM(_context, angle); // Angle in radians for CG
    }
}

void Graphics2D_cg::rotate(float angle, float px, float py) {
    if (_context) {
        // CG rotation is around the origin (0,0) of the current transform matrix
        // To rotate around (px, py): Translate origin to (px,py), rotate, translate back
        CGContextTranslateCTM(_context, px, py);
        CGContextRotateCTM(_context, angle);
        CGContextTranslateCTM(_context, -px, -py);
    }
}

void Graphics2D_cg::reset() {
    // This is tricky. CG contexts don't have a simple "reset matrix".
    // Best practice is to use CGContextSaveGState at the beginning
    // and CGContextRestoreGState when done.
    // Simulating reset requires getting the current CTM, inverting it,
    // and concatenating the inverse, which can be complex and error-prone.
    // A simpler reset here might just reset internal scale factors.
     _log("Warning: Graphics2D_cg::reset() cannot fully reset CTM. Use Save/Restore GState externally.\n");
     _sx = 1.0f;
     _sy = 1.0f;
     // Reset color, stroke, etc. to defaults?
     // setColor(BLACK);
     // setStroke(Stroke());
}

float Graphics2D_cg::sx() const {
    return _sx; // Return tracked scale factor
}

float Graphics2D_cg::sy() const {
     return _sy; // Return tracked scale factor
}

void Graphics2D_cg::drawGlyph(u16 glyph, float x, float y) {
    if (!_context || !_font || !_font->getCTFont() || _fontSize <= 0) {
        _log("Warning: Cannot draw glyph. Missing context, font, or valid size.\n");
        return;
    }

    CTFontRef baseFont = _font->getCTFont();
    // Create a new CTFont instance with the correct size
    CTFontRef sizedFont = CTFontCreateCopyWithAttributes(baseFont, _fontSize, NULL, NULL);
    if (!sizedFont) {
        _log("Warning: Could not create sized font for glyph drawing.\n");
        return;
    }

    CGGlyph cgGlyph = static_cast<CGGlyph>(glyph); // Assume u16 is directly the CGGlyph ID
    CGPoint position = CGPointMake(x, y);

    // Save state, set fill color, draw, restore state
    CGContextSaveGState(_context);
    applyFillColor(); // Ensure correct fill color is set

    // Use CTFontDrawGlyphs for easier handling of font metrics & positioning
    CTFontDrawGlyphs(sizedFont, &cgGlyph, &position, 1, _context);

    CGContextRestoreGState(_context);

    CFRelease(sizedFont); // Release the sized font instance
}

// Path operations
bool Graphics2D_cg::beginPath(i32 id) {
    // CG paths don't use IDs like the interface suggests. Reset internal path.
    if (_path) {
        CGPathRelease(_path);
    }
    _path = CGPathCreateMutable();
    return _path != nullptr; // Return true indicating we have a path object
}

void Graphics2D_cg::moveTo(float x, float y) {
    if (_path) {
        CGPathMoveToPoint(_path, NULL, x, y);
    }
}

void Graphics2D_cg::lineTo(float x, float y) {
    if (_path) {
        CGPathAddLineToPoint(_path, NULL, x, y);
    }
}

void Graphics2D_cg::cubicTo(float x1, float y1, float x2, float y2, float x3, float y3) {
     if (_path) {
        CGPathAddCurveToPoint(_path, NULL, x1, y1, x2, y2, x3, y3);
    }
}

void Graphics2D_cg::quadTo(float x1, float y1, float x2, float y2) {
    if (_path) {
        CGPathAddQuadCurveToPoint(_path, NULL, x1, y1, x2, y2);
    }
}

void Graphics2D_cg::closePath() {
    if (_path) {
        CGPathCloseSubpath(_path);
    }
}

void Graphics2D_cg::fillPath(i32 id) {
    if (_context && _path) {
        CGContextAddPath(_context, _path);
        applyFillColor(); // Ensure color is set
        CGContextFillPath(_context);
        // Reset the path after filling? Yes, matches Skia behavior implicitly.
        beginPath(0);
    }
}

// Primitive shapes
void Graphics2D_cg::drawLine(float x1, float y1, float x2, float y2) {
    if (!_context) return;
    applyStrokeStyle(); // Ensure stroke style is set
    CGContextBeginPath(_context);
    CGContextMoveToPoint(_context, x1, y1);
    CGContextAddLineToPoint(_context, x2, y2);
    CGContextStrokePath(_context);
}

void Graphics2D_cg::drawRect(float x, float y, float w, float h) {
     if (!_context) return;
     applyStrokeStyle(); // Ensure stroke style is set
     CGRect rect = CGRectMake(x, y, w, h);
     CGContextAddRect(_context, rect); // Add rect to current path
     CGContextStrokePath(_context); // Stroke the path
}

void Graphics2D_cg::fillRect(float x, float y, float w, float h) {
     if (!_context) return;
     applyFillColor(); // Ensure fill color is set
     CGRect rect = CGRectMake(x, y, w, h);
     CGContextFillRect(_context, rect); // Directly fill the rect
}

// Helper for rounded rect path
void addRoundedRectToPath(CGContextRef context, CGRect rect, CGFloat rx, CGFloat ry) {
    if (!context) return;
    // Clamp radii
    rx = fmax(0, fmin(rx, rect.size.width / 2.0));
    ry = fmax(0, fmin(ry, rect.size.height / 2.0));

    CGContextBeginPath(context);
    CGContextMoveToPoint(context, rect.origin.x + rx, rect.origin.y);
    CGContextAddArcToPoint(context, rect.origin.x + rect.size.width, rect.origin.y, rect.origin.x + rect.size.width, rect.origin.y + ry, rx);
    CGContextAddArcToPoint(context, rect.origin.x + rect.size.width, rect.origin.y + rect.size.height, rect.origin.x + rect.size.width - rx, rect.origin.y + rect.size.height, ry);
    CGContextAddArcToPoint(context, rect.origin.x, rect.origin.y + rect.size.height, rect.origin.x, rect.origin.y + rect.size.height - ry, rx);
    CGContextAddArcToPoint(context, rect.origin.x, rect.origin.y, rect.origin.x + rx, rect.origin.y, ry);
    CGContextClosePath(context);
}

void Graphics2D_cg::drawRoundRect(float x, float y, float w, float h, float rx, float ry) {
    if (!_context) return;
    applyStrokeStyle();
    CGRect rect = CGRectMake(x, y, w, h);
    addRoundedRectToPath(_context, rect, rx, ry); // Adds to context's path
    CGContextStrokePath(_context);
}

void Graphics2D_cg::fillRoundRect(float x, float y, float w, float h, float rx, float ry) {
    if (!_context) return;
    applyFillColor();
    CGRect rect = CGRectMake(x, y, w, h);
    addRoundedRectToPath(_context, rect, rx, ry); // Adds to context's path
    CGContextFillPath(_context);
}

} // namespace microtex