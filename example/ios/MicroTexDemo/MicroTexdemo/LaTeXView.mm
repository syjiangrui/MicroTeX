//
//  LaTeXView.m
//  MicroTexdemo
//
//  Created by reikjiang on 2025/5/1.
//

#import "LaTeXView.h"
// --- MicroTeX C++ Includes ---
#include "microtex.h"
#include "render/render.h"      // For TeXRender class
#include "graphic/graphic_basic.h" // For microtex::color constants/conversion (if needed)
#include "graphic_cg.h" // For the Graphics2D_cg wrapper

@implementation LaTeXView

// The core drawing method
- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    if (!self.latexString || self.latexString.length == 0) {
        return;
    }

    CGContextRef cgContext = UIGraphicsGetCurrentContext();
    if (!cgContext) {
        NSLog(@"Error: Could not get graphics context in LaTeXView");
        return;
    }

    // --- NO Coordinate System Flip ---
    // CGContextSaveGState(cgContext); // Still save/restore if you do other CG drawing
    // CGContextTranslateCTM(cgContext, 0, self.bounds.size.height);
    // CGContextScaleCTM(cgContext, 1.0, -1.0);
    // --- Assume MicroTeX works directly with UIKit's Y-down system ---

    microtex::Render* render = nullptr;

    try {
        // Pass the UNFLIPPED context to Graphics2D_cg
        microtex::Graphics2D_cg g2(cgContext);

        // Prepare parameters... (color, string, size, etc.)
        CGFloat r, g, b, a;
        [self.textColor getRed:&r green:&g blue:&b alpha:&a];
        microtex::color texColor = microtex::argb(
            static_cast<int>(a * 255), static_cast<int>(r * 255),
            static_cast<int>(g * 255), static_cast<int>(b * 255)
        );
        std::string latexStdString = [self.latexString UTF8String];

        // --- Adjust Render Width if Not Filling ---
        // If fillWidth = false, use 0 or a large value for parse,
        // then get the actual width from the render object.
        bool fillWidth = true; // Set true to wrap to bounds, false for natural width
        float parseWidth = fillWidth ? self.bounds.size.width : 0; // Use 0 for natural width measurement

        float textSize = self.latexFontSize;
        float lineSpace = 1.0f;

        // --- Call the static parse method ---
        render = microtex::MicroTeX::parse(
            latexStdString,
                                           parseWidth,
            textSize,
            lineSpace,
            texColor,
            fillWidth
        );

        if (!render) {
            NSLog(@"MicroTeX parsing failed for string: %@", self.latexString);
            // CGContextRestoreGState(cgContext); // Only if you saved state earlier
            return;
        }

        // --- Calculate Drawing Position (Y-Down) ---
        float drawX = 0; // Align left edge horizontally
        // float renderHeight = render->getHeight(); // Still useful info
        // float renderWidth = render->getWidth(); // Get width if fillWidth was false

        // --- FIX: Try drawing at Y=0 in the standard Y-down system ---
        // This should place the first line's baseline (or top?) at the top edge.
        float drawY = 0;

        // Optional: Add top padding
        // drawY += 5; // Move down 5 points

        // --- Draw the render object ---
        g2.setColor(texColor);
        render->draw(g2, drawX, drawY); // Draw with coords in Y-down system

        // --- Delete the render object ---
        delete render;
        render = nullptr;

    } catch (const std::exception& e) {
        NSLog(@"MicroTeX Rendering C++ exception: %s", e.what());
        delete render;
        render = nullptr;
    } catch (...) {
        NSLog(@"MicroTeX Rendering unknown C++ exception.");
        delete render;
        render = nullptr;
    }

    // --- Restore the graphics state (only needed if you saved it) ---
    // CGContextRestoreGState(cgContext);
}

@end
