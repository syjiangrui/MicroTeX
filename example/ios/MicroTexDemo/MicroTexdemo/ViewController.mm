//
//  ViewController.m
//  MicroTexdemo
//
//  Created by reikjiang on 2025/5/1.
//

#import "ViewController.h"
#include "graphic_cg.h"
#import "LaTeXView.h"
#include "microtex.h"

@interface ViewController ()

@property (nonatomic, strong) LaTeXView *latexView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *clm = [[NSBundle mainBundle] pathForResource:@"latinmodern-math" ofType:@"clm2"];
    NSString *font = [[NSBundle mainBundle] pathForResource:@"latinmodern-math" ofType:@"otf"];
    const microtex::FontSrcFile math{clm.UTF8String, font.UTF8String};
    microtex::MicroTeX::init(math);
    
    microtex::PlatformFactory::registerFactory("cg", std::make_unique<microtex::PlatformFactory_cg>());
    // Activate the registered factory
    microtex::PlatformFactory::activate("cg");

    NSLog(@"MicroTeX initialization successful.");
    
    LaTeXView *latexView = [[LaTeXView alloc] initWithFrame:CGRectMake(0, 100, self.view.bounds.size.width * 2, 700)];
//    latexView.latexString = @"E = mc^2 + \\frac{\\alpha}{\\beta}"; // Example LaTeX
    latexView.latexString = [self latexSource];
    latexView.latexFontSize = 18.0f;
    latexView.textColor = [UIColor blackColor];
//    latexView.layer.borderColor = [UIColor lightGrayColor].CGColor; // For visualization
//    latexView.layer.borderWidth = 1.0;
    latexView.backgroundColor = UIColor.whiteColor;
    
    [self.view addSubview:latexView];
    self.latexView = latexView;
}

- (NSString *)latexSource {
    NSString *sourcePath = [[NSBundle mainBundle] pathForResource:@"latex_2" ofType:@"txt"];
    NSString *latex = [NSString stringWithContentsOfFile:sourcePath encoding:NSUTF8StringEncoding error:nil];
    return latex;
}


@end
