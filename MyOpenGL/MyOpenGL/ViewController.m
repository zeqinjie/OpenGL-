//
//  ViewController.m
//  MyOpenGL
//
//  Created by zhengzeqin on 16/2/29.
//  Copyright © 2016年 com.injoinow. All rights reserved.
//  

#import "ViewController.h"
#import "OpenGLView.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self initView];
}


- (void)initView{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];    
    OpenGLView *view = [[OpenGLView alloc]initWithFrame:screenBounds];
    [self.view addSubview:view];
    
}

@end
