//
//  LaTeXView.h
//  MicroTexdemo
//
//  Created by reikjiang on 2025/5/1.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LaTeXView : UIView


// Property to hold the LaTeX string to render
@property (nonatomic, strong) NSString *latexString;
// Property to control text color (optional)
@property (nonatomic, strong) UIColor *textColor;
// Property to control font size (optional)
@property (nonatomic, assign) CGFloat latexFontSize;

// Convenience initializer
- (instancetype)initWithFrame:(CGRect)frame latex:(NSString *)latex;

@end

NS_ASSUME_NONNULL_END
