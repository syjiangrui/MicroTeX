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
@property (nonatomic, strong) UIScrollView *scrollView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
    
    NSString *clm = [[NSBundle mainBundle] pathForResource:@"latinmodern-math" ofType:@"clm2"];
    NSString *font = [[NSBundle mainBundle] pathForResource:@"latinmodern-math" ofType:@"otf"];
    const microtex::FontSrcFile math{clm.UTF8String, font.UTF8String};
    microtex::MicroTeX::init(math);
    
    microtex::PlatformFactory::registerFactory("cg", std::make_unique<microtex::PlatformFactory_cg>());
    // Activate the registered factory
    microtex::PlatformFactory::activate("cg");

    NSLog(@"MicroTeX initialization successful.");
    
    LaTeXView *latexView = [[LaTeXView alloc] initWithFrame:CGRectZero];
    latexView.latexString = [self latexSource];
    latexView.latexFontSize = 18.0f;
    latexView.textColor = [UIColor blackColor];
    latexView.backgroundColor = UIColor.whiteColor;
    
    [self.scrollView addSubview:latexView];
    self.latexView = latexView;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self.latexView sizeToFit];
    self.scrollView.contentSize = self.latexView.bounds.size;
}

- (NSString *)latexSource {
    NSString *sourcePath = [[NSBundle mainBundle] pathForResource:@"latex_2" ofType:@"txt"];
    NSString *latex = [NSString stringWithContentsOfFile:sourcePath encoding:NSUTF8StringEncoding error:nil];
    return latex;
}


@end
