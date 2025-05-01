#ifndef MICROTEX_GRAPHIC_CG_H
#define MICROTEX_GRAPHIC_CG_H

#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>
#include <map>
#include <string>
#include <vector>

#include "graphic/graphic.h"
#include "microtexexport.h"  // Keep if you plan to build a dynamic framework

// Forward declare Objective-C Type
#ifdef __OBJC__
@class NSAttributedString;
#else
typedef struct objc_object NSAttributedString;
#endif

namespace microtex {

// Helper function signature (implementation in .mm)
CGColorRef Gfx_CreateCGColor(color c);

/**************************************************************************************************/

class MICROTEX_EXPORT Font_cg : public Font {
private:
  // Use CTFontRef for Core Text integration
  CTFontRef _ctFont = nullptr;
  // Cache loaded fonts by file path
  static std::map<std::string, CTFontRef> _fontCache;
  // Static mutex for thread safety is recommended for production code
  // static std::mutex _cacheMutex;

  void loadFont(const std::string& file);

public:
  explicit Font_cg(const std::string& file);
  ~Font_cg();  // Need destructor to release CTFontRef

  // Disable copy and assignment
  Font_cg(const Font_cg&) = delete;
  Font_cg& operator=(const Font_cg&) = delete;

  // Allow move
  Font_cg(Font_cg&& other) noexcept;
  Font_cg& operator=(Font_cg&& other) noexcept;

  bool operator==(const Font& f) const override;

  CTFontRef getCTFont() const;
};

/**************************************************************************************************/

class MICROTEX_EXPORT TextLayout_cg : public TextLayout {
private:
  // Use NSAttributedString for styled text (easier memory management with ARC in .mm)
  NSAttributedString* _attrString = nullptr;
  // Use CTLineRef for single-line layout
  CTLineRef _ctLine = nullptr;
  Rect _bounds;
  std::size_t _textLen;

  void calculateBounds();

public:
  TextLayout_cg(const std::string& src, FontStyle style, float size);
  ~TextLayout_cg();  // Need destructor to release Core Foundation/Objective-C objects

  // Disable copy and assignment
  TextLayout_cg(const TextLayout_cg&) = delete;
  TextLayout_cg& operator=(const TextLayout_cg&) = delete;

  // Allow move
  TextLayout_cg(TextLayout_cg&& other) noexcept;
  TextLayout_cg& operator=(TextLayout_cg&& other) noexcept;

  void getBounds(Rect& bounds) override;
  void draw(Graphics2D& g2, float x, float y) override;
};

/**************************************************************************************************/

class MICROTEX_EXPORT PlatformFactory_cg : public PlatformFactory {
public:
  sptr<Font> createFont(const std::string& file) override;
  sptr<TextLayout> createTextLayout(const std::string& src, FontStyle style, float size) override;
};

/**************************************************************************************************/

class MICROTEX_EXPORT Graphics2D_cg : public Graphics2D {
private:
  CGContextRef _context;  // The Core Graphics context (non-owning)
  microtex::color _color;
  CGColorRef _cgFillColor = nullptr;
  CGColorRef _cgStrokeColor = nullptr;
  Stroke _stroke;
  sptr<Font_cg> _font;  // Hold our CG font wrapper
  float _fontSize;
  float _sx, _sy;  // Track scaling separately if needed (CGContextGetCTM can be complex)
  CGMutablePathRef _path = nullptr;
  std::vector<float> _dash;

  // Helper to apply current state to context
  void applyFillColor();
  void applyStrokeColor();
  void applyStrokeStyle();
  void releaseColorRefs();

public:
  // Constructor takes the CGContextRef
  explicit Graphics2D_cg(CGContextRef context);
  ~Graphics2D_cg();  // Release owned resources

  // Disable copy and assignment
  Graphics2D_cg(const Graphics2D_cg&) = delete;
  Graphics2D_cg& operator=(const Graphics2D_cg&) = delete;

  CGContextRef getCGContext() const;

  // Overridden methods from Graphics2D
  void setColor(color c) override;
  color getColor() const override;
  void setStroke(const Stroke& s) override;
  const Stroke& getStroke() const override;
  void setStrokeWidth(float w) override;
  void setDash(const std::vector<float>& dash) override;
  std::vector<float> getDash() override;
  sptr<Font> getFont() const override;
  void setFont(const sptr<Font>& font) override;
  float getFontSize() const override;
  void setFontSize(float size) override;
  void translate(float dx, float dy) override;
  void scale(float sx, float sy) override;
  void rotate(float angle) override;
  void rotate(float angle, float px, float py) override;
  void reset() override;  // Resetting CTM might be tricky, depends on usage
  float sx() const override;
  float sy() const override;
  void drawGlyph(u16 glyph, float x, float y) override;  // u16 might need mapping to CGGlyph
  bool beginPath(i32 id) override;
  void moveTo(float x, float y) override;
  void lineTo(float x, float y) override;
  void cubicTo(float x1, float y1, float x2, float y2, float x3, float y3) override;
  void quadTo(float x1, float y1, float x2, float y2) override;
  void closePath() override;
  void fillPath(i32 id) override;
  void drawLine(float x1, float y1, float x2, float y2) override;
  void drawRect(float x, float y, float w, float h) override;
  void fillRect(float x, float y, float w, float h) override;
  void drawRoundRect(float x, float y, float w, float h, float rx, float ry) override;
  void fillRoundRect(float x, float y, float w, float h, float rx, float ry) override;
};

}  // namespace microtex

#endif  // MICROTEX_GRAPHIC_CG_H