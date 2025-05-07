//
//  LaTeXView.h
//  MicroTexdemo
//
//  Created by reikjiang on 2025/5/1.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A UIView subclass for rendering LaTeX strings using the MicroTeX library.
 */
@interface LaTeXView : UIView

/// The TeX string you want to render. Setting this will trigger a re-parse & redraw.
@property (nonatomic, copy, nullable) NSString *latexString;

/// Font size, in points. Defaults to 17.0.
@property (nonatomic, assign) CGFloat latexFontSize;

/// Extra line spacing multiplier (1.0 = default). Defaults to 1.0.
@property (nonatomic, assign) CGFloat lineSpacing;

/// Text color. Defaults to UIColor.blackColor.
@property (nonatomic, strong) UIColor *textColor;

/// If YES, the LaTeX content will wrap to the view’s width.
/// If NO, the content will use its "natural" TeX width, potentially exceeding the view's bounds if not wide enough.
/// Defaults to YES.
@property (nonatomic, assign) BOOL fillWidth;

/**
 * @brief Designated initializer.
 * @param frame The frame rectangle for the view, measured in points.
 * @return An initialized LaTeXView object or nil if the object couldn't be created.
 */
- (instancetype)initWithFrame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END
