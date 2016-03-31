//
//  OpenGL3ViewController.m
//  MyOpenGL
//
//  Created by zhengzeqin on 16/3/2.
//  Copyright © 2016年 com.injoinow. All rights reserved.
//  使用苹果封装好的框架 使用OpenGL
/**
 *  shader.vsh  文件  === SimpleVertex.glsl 文件
 *  shader.fsh  文件  === SimpleFragment.glsl 文件
 */
#import "OpenGL3ViewController.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

@interface OpenGL3ViewController ()<GLKViewDelegate>

@end

@implementation OpenGL3ViewController
{
    //gl 上下文
    EAGLContext *context;
    //gl view
    GLKView *view;
    //shader 项目
    GLuint program;
    //vao对象，顶点数组对象 包含一个或者多个 顶点缓冲区对象
    GLuint vertexID;
}
//在OpenGL 中使用的坐标点是数学上的x,y,z （0 -  1 表示方式）空间坐标，投影点 是不确定的可以任何一个点
// 三角形的顶点坐标
GLKVector3 vec[3]={
    {0.5,0.5,0.5},
    {-0.5,-0.5,0.5},
    {0.5,-0.5,-0.5}
};

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self initView];
}


- (void)initView{
    //创建上下文
    context = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES3];
    //强转
    view = (GLKView *)self.view;
    //设置GLKView文本内容
    view.context = context;
    //设置GLKView 是24色深度格式
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    //设置上下文
    [EAGLContext setCurrentContext:context];
    
    //开启深度测试，就是让离你近的物体可以遮挡离你远的物体。
    glEnable(GL_DEPTH_TEST);
    //设置颜色
    glClearColor(0, 104.0/255.0, 55.0/255.0, 1.0);
    
    /*loadShaders  主程序里加载shader了
     步骤
     1.通过读取文件vsh ,fsh 文件 创建 编译 顶点（位置） 片断（颜色）着色器
     2.创建shader项目 附加顶点，片断着色器
     3.连接项目
     4.释放顶点和片段着色器
     */
    [self loadShaders];
    /*setupVAO
     设置VAO步骤
     1.创建VAO顶点数组对象 绑定VAO
     2.创建两个VBO 对象 一个是顶点位置信息 ，另一个是顶点的索引信息
     3.连接项目
     4.释放顶点和片段着色器
     */
    [self setupVAO];
    

}

#pragma mark - function
//加载Shaders
- (BOOL)loadShaders
{
    //定义顶点（位置）着色器  和 片断（颜色）着色器
    GLuint vertShader, fragShader;
    //文件目录
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.创建shader项目
    program = glCreateProgram();
    
    
    //获取vsh（顶点位置）文件的路径
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    // 创建和编译 vertex shader.顶点着色器 位置
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }

    //获取fsh（顶点颜色）文件的路径
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    // 创建和编译 fragment shader.顶点着色器 颜色
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // 附加 顶点着色器的vertex shade，vsh文件
    glAttachShader(program, vertShader);
    
    // 附加 顶点着色器的fragment shade，fsh文件
    glAttachShader(program, fragShader);
    
    // Link program.连接项目
    if (![self linkProgram:program]) {
        NSLog(@"Failed to link program: %d", program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (program) {
            glDeleteProgram(program);
            program = 0;
        }
        
        return NO;
    }
    // 释放顶点和片段着色器
    if (vertShader) {
        glDetachShader(program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

/**
 *  获取文件路径返回处理后的数据
 *
 *  @param shader shader 内容结果 注意 传指针地址 返回结果 C语言只有指针地址能修改结果
 *  @param type   文件类型  GL_VERTEX_SHADER   GL_FRAGMENT_SHADER
 *  @param file   文件路径
 *
 */
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    //创建一个代表shader的OpenGL对象  指定类型，注意C语言指针 *shader 取值操作
    *shader = glCreateShader(type);
    //读取shader 文件的数据源（就是vsh ,fsh 文件 其实 上一章即使glsl文件）
    glShaderSource(*shader, 1, &source, NULL);
    //运行编译shaner文件
    glCompileShader(*shader);
    
    
#if defined(DEBUG)
    //DEBUG 模式下  打印错误信息
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    //判断是否正常
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

//连接项目
- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    //DEBUG 模式下  打印错误信息
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    //判断是否正常
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

//检查项目是否正常
- (BOOL)validateProgram:(GLuint)prog
{
    
    //logLength:打印日志长度，status:项目是否连接成功
    GLint logLength, status;
    //项目是否正确
    glValidateProgram(prog);
    //获取项目的信息
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        //错误信息输出
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    //获取项目的是否正确
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

/**
 *  创建Vertex Buffer 对象 生成VAO数组  装载  VBO数据的
 */
- (void)setupVAO {
    
    //生成一个VAO 顶点数组对象 是一个包含一个或数个顶点缓冲区对象（Vertex Buffer Object， 即 VBO)的对象，一般存储一个可渲染物体的所有信息。
    glGenVertexArrays(1, &vertexID);
    //绑定VAO
    glBindVertexArray(vertexID);
    
    //VBO对象 顶点缓冲区对象 （Vertex Buffer Object VBO）是你显卡内存中的一块高速内存缓冲区，用来存储顶点的所有信息。
    GLuint bufferID;
    //生成VBO
    glGenBuffers(1, &bufferID);
    //绑定 告诉OpenGL我们的vertexBuffer 是指GL_ARRAY_BUFFER
    glBindBuffer(GL_ARRAY_BUFFER, bufferID);
    //填充缓冲对象  把数据传到OpenGL-land
    glBufferData(GL_ARRAY_BUFFER, sizeof(vec), vec, GL_STATIC_DRAW);
    //获得shader里position变量的索引
    GLuint loc=glGetAttribLocation(program, "position");
    //启用这个索引
    glEnableVertexAttribArray(loc);// glDisableVertexAttribArray 与他对应
    //设置这个索引需要填充的内容
    glVertexAttribPointer(loc, 3, GL_FLOAT, GL_FALSE, sizeof(GLKVector3),0);
    //释放VAO
    glBindVertexArray(0);
    //释放VBO
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    
    // glGenVertexArrays 、glDeleteVertexArrays 和 glBindVertexArray 。
}



#pragma mark - GLKViewDelegate
//每帧调用一次
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect{
    //清除surface内容，恢复至初始状态，清除颜色 和 深度
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    //绑定VAO
    glBindVertexArray(vertexID);
    //使用shader
    glUseProgram(program);
    //绘制三角形
    glDrawArrays(GL_TRIANGLES, 0, 3);
    //释放VAO
    glBindVertexArray(0);
    //释放VBO
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    //释放VBO
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
