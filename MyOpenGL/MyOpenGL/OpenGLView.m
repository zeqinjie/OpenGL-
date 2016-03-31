//
//  OpenGLView.m
//  MyOpenGL
//
//  Created by zhengzeqin on 16/2/29.
//  Copyright © 2016年 com.injoinow. All rights reserved.
//  OpenGL2的使用
//  http://www.cnblogs.com/andyque/archive/2011/08/08/2131019.html

#import "OpenGLView.h"
//动画
//#import <QuartzCore/QuartzCore.h>
//绘图
#import <CoreGraphics/CoreGraphics.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import "CC3GLMatrix.h"
@interface OpenGLView()
//1.加入头文件 #include <OpenGLES/ES2/gl.h>  #include <OpenGLES/ES2/glext.h>
@end
@implementation OpenGLView
{
    //2.声明
    //用来显示OpenGL的类CALayer子类
    CAEAGLLayer* _eaglLayer;
    //OpenGL 需要的上下文，使Opengl ES的内容方便的同核心动画进行集成工作
    EAGLContext* _context;
    //uint32_t 颜色流
    GLuint _colorRenderBuffer;
    //深度测试流
    GLuint _depthRenderBuffer;
    //顶点位置  glsl SimpleVertex 文件的 Position 属性 用来标志顶点的位置
    GLuint _positionSlot;
    //顶点颜色  glsl SimpleVertex 文件的 SourceColor 属性 用来填充顶点的颜色
    GLuint _colorSlot;
    
    //当前旋转度
    float _currentRotation;
    //对应SimpleVertex.glsl 的 Projection
    GLuint _projectionUniform;
    //对应SimpleVertex.glsl 的Modelview 常量
    GLuint _modelViewUniform;

    
}

/**
 *  创建正方形坐标点集
 */
typedef struct {
    //点坐标
    float Position[3];
    //颜色值
    float Color[4];
} Vertex;
//顶点的坐标点和颜色值 正方体 8个顶点的坐标和颜色RGBA 0 --> 7
const Vertex Vertices[] = {
    {{1, -1, 0}, {1, 0, 0, 1}},  // 0
    {{1, 1, 0}, {1, 0, 0, 1}},   // 1
    {{-1, 1, 0}, {0, 1, 0, 1}},  // 2
    {{-1, -1, 0}, {0, 1, 0, 1}}, // 3
    {{1, -1, -1}, {1, 0, 0, 1}}, // 4
    {{1, 1, -1}, {1, 0, 0, 1}},  // 5
    {{-1, 1, -1}, {0, 1, 0, 1}}, // 6
    {{-1, -1, -1}, {0, 1, 0, 1}} // 7
};
//http://www.cocoachina.com/game/20141127/10335.html
//每个三角形的索引信息  正方体六个面 十二个三角形 构成 36 个顶点组成一个正方形
//索引就是 描述组顶点构成的 数组
const GLubyte Indices[] = {
    // Front 正方体前面
    0, 1, 2, //  ===>  {{1, -1, 0},{1, 1, 0},{-1, 1, 0}} + {对应的颜色属性} === {[{1, -1, 0},{1, 0, 0, 1}],[{1, 1, 0}, {1, 0, 0, 1}],[{-1, 1, 0}, {0, 1, 0, 1}]}
    2, 3, 0, //{[{-1, 1, 0}, {0, 1, 0, 1}],[{-1, -1, 0}, {0, 1, 0, 1}],[{1, -1, 0}, {1, 0, 0, 1}]}
    // Back  正方体后面
    4, 6, 5,
    4, 7, 6,
    // Left
    2, 7, 3,
    7, 6, 2,
    // Right
    0, 4, 1,
    4, 1, 5,
    // Top
    6, 2, 1,
    1, 6, 5,
    // Bottom
    0, 3, 7,
    0, 7, 4    
};
/*
 注意：
 在OpenGL的世界中含x,y,z 坐标标示 是0 - 1 数学里的坐标系 ，还有投影点 可以自由设定区域  实现3D 2D
 什么是VBO：用来存放顶点信息（位置 颜色)，或者存放顶点的索引信息的（需要画多少个顶点）
 什么是VAO：用来存放多个VBO对象的对象，一般存储一个可渲染物体的所有信息。
 索引的作用：使用索引（indices）来指定顺序，这样可以重复使用同一个顶点。
 
 绘制3D 可以OpenGL 结合GLKit框架  或者 iOS8之后使用Metal框架  C API
*/
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        //设置layer层
        [self setupLayer];
        //设置上下文
        [self setupContext];
        //启动深度测试
        [self setupDepthBuffer];
        //创建渲染缓冲区
        [self setupRenderBuffer];
        //创建帧缓冲区
        [self setupFrameBuffer];
        //主程序里加载shader了
        [self compileShaders];
        //
        [self setupVBOs];
//        [self render];
        [self setupDisplayLink];
    }
    return self;
}

- (void)setupDisplayLink {
    CADisplayLink* displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render:)];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

//3.想要显示OpenGL的内容，你需要把它缺省的layer设置为一个特殊的layer。（CAEAGLLayer）。这里通过直接复写layerClass的方法。
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

//4.因为缺省的话，CALayer是透明的。而透明的层对性能负荷很大，特别是OpenGL的层。（如果可能，尽量都把层设置为不透明。另一个比较明显的例子是自定义tableview cell）
- (void)setupLayer {
    _eaglLayer = (CAEAGLLayer*) self.layer;
    _eaglLayer.opaque = YES;
}
//5.无论你要OpenGL帮你实现什么，总需要这个 EAGLContext。　EAGLContext管理所有通过OpenGL进行draw的信息。这个与Core Graphics context类似。　当你创建一个context，你要声明你要用哪个version的API。这里，我们选择OpenGL ES 2.0.
- (void)setupContext {
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES2;
    _context = [[EAGLContext alloc] initWithAPI:api];
    if (!_context) {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    
    if (![EAGLContext setCurrentContext:_context]) {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
}

//这里还有一个叫做 depth testing（深度测试）的功能，启动它，OpenGL就可以跟踪在z轴上的像素。这样它只会在那个像素前方没有东西时，才会绘画这个像素。
//·setupDepthBuffer方法创建了一个depth buffer。这个与前面的render/color buffer类似，不再重复了。值得注意的是，这里使用了glRenderbufferStorage, 然不是context的renderBufferStorage（这个是在OpenGL的view中特别为color render buffer而设的）。
- (void)setupDepthBuffer {
    glGenRenderbuffers(1, &_depthRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _depthRenderBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, self.frame.size.width, self.frame.size.height);
}

//6.创建render buffer （渲染缓冲区）
- (void)setupRenderBuffer {
    /*
     Render buffer 是OpenGL的一个对象，用于存放渲染过的图像。　有时候你会发现render buffer会作为一个color buffer被引用，因为本质上它就是存放用于显示的颜色。
    　创建render buffer的三步：
 　  1.调用glGenRenderbuffers来创建一个新的render buffer object。这里返回一个唯一的integer来标记render buffer（这里把这个唯一值赋值到_colorRenderBuffer）。有时候你会发现这个唯一值被用来作为程序内的一个OpenGL 的名称。（反正它唯一嘛）
 　  2.调用glBindRenderbuffer ，告诉这个OpenGL：我在后面引用GL_RENDERBUFFER的地方，其实是想用_colorRenderBuffer。其实就是告诉OpenGL，我们定义的buffer对象是属于哪一种OpenGL对象
 　  3.最后，为render buffer分配空间。renderbufferStorage
     */
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
}


//7.创建一个 frame buffer （帧缓冲区）
- (void)setupFrameBuffer {
    /*
    Frame buffer也是OpenGL的对象，它包含了前面提到的render buffer，以及其它后面会讲到的诸如：depth buffer、stencil buffer 和 accumulation buffer。前两步创建frame buffer的动作跟创建render buffer的动作很类似。（反正也是用一个glBind什么的而最后一步  glFramebufferRenderbuffer 这个才有点新意。它让你把前面创建的buffer render依附在frame buffer的GL_COLOR_ATTACHMENT0位置上。
     */
    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,GL_RENDERBUFFER, _colorRenderBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthRenderBuffer);
}

//8.清理屏幕
/*
 - (void)render {
 
 1.调用glClearColor ，设置一个RGB颜色和透明度，接下来会用这个颜色涂满全屏。
 2.调用glClear来进行这个“填色”的动作（大概就是photoshop那个油桶嘛）。还记得前面说过有很多buffer的话，这里我们要用到GL_COLOR_BUFFER_BIT来声明要清理哪一个缓冲区。
 3.调用OpenGL context的presentRenderbuffer方法，把缓冲区（render buffer和color buffer）的颜色呈现到UIView上。
 
 glClearColor(0, 104.0/255.0, 55.0/255.0, 1.0);
 glClear(GL_COLOR_BUFFER_BIT);
 [_context presentRenderbuffer:GL_RENDERBUFFER];
 }
 */

- (void)render:(CADisplayLink*)displayLink {
    glClearColor(0, 104.0/255.0, 55.0/255.0, 1.0);
    //清除surface内容，恢复至初始状态，清除颜色 和 深度
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    //并启用depth  testing
    glEnable(GL_DEPTH_TEST);
    
    //·你用来把数据传入到vertex shader的方式，叫做 glUniformMatrix4fv. 这个CC3GLMatrix类有一个很方便的方法 glMatrix,来把矩阵转换成OpenGL的array格式。
    CC3GLMatrix *projection = [CC3GLMatrix matrix];
    float h =4.0f* self.frame.size.height / self.frame.size.width;
    [projection populateFromFrustumLeft:-2 andRight:2 andBottom:-h/2 andTop:h/2 andNear:4 andFar:10];
    glUniformMatrix4fv(_projectionUniform, 1, 0, projection.glMatrix);
    
    //模式
    CC3GLMatrix *modelView = [CC3GLMatrix matrix];
    [modelView populateFromTranslation:CC3VectorMake(sin(CACurrentMediaTime()), 0, -7)];
    //旋转
    _currentRotation += displayLink.duration *90;
    [modelView rotateBy:CC3VectorMake(_currentRotation, _currentRotation, 0)];
    glUniformMatrix4fv(_modelViewUniform, 1, 0, modelView.glMatrix);
    // 1.调用glViewport 设置UIView中用于渲染的部分。这个例子中指定了整个屏幕。但如果你希望用更小的部分，你可以更变这些参数。
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);
    
    /* 2.调用glVertexAttribPointer来为vertex shader的两个输入参数配置两个合适的值。
    
    　　 第二段这里，是一个很重要的方法，让我们来认真地看看它是如何工作的：
    
    　　·第一个参数，声明这个属性的名称，之前我们称之为glGetAttribLocation
    
    　　·第二个参数，定义这个属性由多少个值组成。譬如说position是由3个float（x,y,z）组成，而颜色是4个float（r,g,b,a）
    
    　　·第三个，声明每一个值是什么类型。（这例子中无论是位置还是颜色，我们都用了GL_FLOAT）
    
    　　·第四个，嗯……它总是false就好了。
    
    　　·第五个，指 stride 的大小。这是一个种描述每个 vertex数据大小的方式。所以我们可以简单地传入 sizeof（Vertex），让编译器计算出来就好。

    　　·最好一个，是这个数据结构的偏移量。表示在这个结构中，从哪里开始获取我们的值。Position的值在前面，所以传0进去就可以了。而颜色是紧接着位置的数据，而position的大小是3个float的大小，所以是从 3 * sizeof(float) 开始的。
    */
    //设置这个索引的位置需要填充的内容
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), 0);
    //设置这个索引的颜色需要填充的内容
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), (GLvoid*) (sizeof(float) *3));
    
    /* 3.调用glDrawElements ，它最后会在每个vertex上调用我们的vertex shader，以及每个像素调用fragment shader，最终画出我们的矩形。它也是一个重要的方法，我们来仔细研究一下：
     
     　 ·第一个参数，声明用哪种特性来渲染图形。有GL_LINE_STRIP 和 GL_TRIANGLE_FAN。然而GL_TRIANGLE是最常用的，特别是与VBO 关联的时候。
     
     　 ·第二个，告诉渲染器有多少个图形要渲染。我们用到C的代码来计算出有多少个。这里是通过个 array的byte大小除以一个Indice类型的大小得到的。
     
     　 ·第三个，指每个indices中的index类型
     
     　 ·最后一个，在官方文档中说，它是一个指向index的指针。但在这里，我们用的是VBO，所以通过index的array就可以访问到了（在GL_ELEMENT_ARRAY_BUFFER传过了），所以这里不需要.
     */
    glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]),
                   GL_UNSIGNED_BYTE, 0);
    
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    

}
//使用glsl语言 OpenGL 着色器语言 附加glsl文件 连接项目/ OC 语言
- (void)compileShaders {
     /* glsl 是 OpenGL着色语言
      *************SimpleVertex（顶点着色器vsh）*****位置***********
      注意：主要是顶点的位置 gl_Position
      1.“attribute”声明了这个shader会接受一个传入变量，这个变量名为“Position”。在后面的代码中，你会用它来传入顶点的位置数据。这个变量的类型是“vec4”,表示这是一个由4部分组成的矢量。
      attribute vec4 Position;
      2.与上面同理，这里是传入顶点的颜色变量。
      attribute vec4 SourceColor;
      3.这个变量没有“attribute”的关键字。表明它是一个传出变量，它就是会传入片段着色器的参数。“varying”关键字表示，依据顶点的颜色，平滑计算出顶点之间每个像素的颜色。
      varying vec4 DestinationColor;
      4.每个shader都从main开始– 跟C一样嘛。
      void main(void) {
      5.设置目标颜色 = 传入变量：SourceColor
      DestinationColor = SourceColor;
        6.gl_Position 是一个内建的传出变量。这是一个在 vertex shader中必须设置的变量。这里我们直接把gl_Position = Position; 没有做任何逻辑运算。
        gl_Position = Position;
      }
    
      *********SimpleFragment片断着色器fsh）*******颜色******
      注意：主要是顶点的颜色 gl_FragColor
      1. 这是从vertex shader中传入的变量，这里和vertex shader定义的一致。而额外加了一个关键字：lowp。在fragment shader中，必须给出一个计算的精度。出于性能考虑，总使用最低精度是一个好习惯。这里就是设置成最低的精度。如果你需要，也可以设置成medp或者highp.
      varying lowp vec4 DestinationColor;
      void main(void) {
      2. 正如你在vertex shader中必须设置gl_Position, 在fragment shader中必须设置gl_FragColor.这里也是直接从 vertex shader中取值，先不做任何改变。
        gl_FragColor = DestinationColor;
      }
      
      补充:GLSL 三种变量类型（uniform，attribute和varying）
      uniform:niform变量是外部application程序传递给（vertex和fragment）shader的变量。因此它是application通过函数glUniform**（）函数赋值的（shader只能用，不能改 类似const）,表示:变换矩阵，材质，光照参数和颜色等信息。
      attribute:只能在vertex shader中使用的变量,attribute变量来表示一些顶点的数据，如：顶点坐标，法线，纹理坐标，顶点颜色等。
      varying:是vertex和fragment shader之间做数据传递用的，一般vertex shader修改varying变量的值，然后fragment shader使用该varying变量的值。(因此varying变量在vertex和fragment shader二者之间的声明必须是一致的)。
     */
    
    // 1.用来调用你刚刚写的动态编译方法，分别编译了vertex shader 顶点着色 和 fragment shader 片断着色
    GLuint vertexShader = [self compileShader:@"SimpleVertex" withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:@"SimpleFragment" withType:GL_FRAGMENT_SHADER];
    
    // 2.调用了glCreateProgram glAttachShader  glLinkProgram 连接 vertex 和 fragment shader成一个完整的program。  opengl 和 glsl 的附加
    GLuint programHandle = glCreateProgram();
//附加glsl
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);
//连接项目 将glsl 文件与 项目连接
    glLinkProgram(programHandle);
    
    // 3.调用 glGetProgramiv  lglGetProgramInfoLog 来检查是否有error，并输出信息。
    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }

    // 4.调用 glUseProgram  让OpenGL真正执行你的program
    glUseProgram(programHandle);
    
    // 5.最后，调用 glGetAttribLocation 来获取指向 vertex shader传入变量的指针。以后就可以通过这写指针来使用了。还有调用 glEnableVertexAttribArray来启用这些数据。（因为默认是 disabled的。）
    //位置索引
    _positionSlot = glGetAttribLocation(programHandle, "Position");
    //颜色索引
    _colorSlot = glGetAttribLocation(programHandle, "SourceColor");
    //启用位置索引
    glEnableVertexAttribArray(_positionSlot);
    //启用颜色索引
    glEnableVertexAttribArray(_colorSlot);
    
    
    //通过调用  glGetUniformLocation 来获取在vertex shader中的Projection输入变量
    _projectionUniform = glGetUniformLocation(programHandle, "Projection");
    _modelViewUniform = glGetUniformLocation(programHandle, "Modelview");
}

//获取文件路径返回处理后的数据
- (GLuint)compileShader:(NSString*)shaderName withType:(GLenum)shaderType {
    
    // 1 获取文件地址读取文件内容
    NSString* shaderPath = [[NSBundle mainBundle] pathForResource:shaderName ofType:@"glsl"];
//    NSLog(@"path = %@",shaderPath);
    NSError* error;
    
    NSString* shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSLog(@"Error loading shader: %@", error.localizedDescription);
        exit(1);
    }
    
    // 2.调用 glCreateShader来创建一个代表shader的OpenGL对象。这时你必须告诉OpenGL，你想创建 fragment shader还是vertex shader。所以便有了这个参数：shaderType
    GLuint shaderHandle = glCreateShader(shaderType);
    
    // 3 调用glShaderSource ，让OpenGL获取到这个shader（就是glsl文件）的源代码。（就是我们写的那个）这里我们还把NSString转换成C-string
    const char* shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = [shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    // 4.最后，调用glCompileShader 在运行时编译shader
    glCompileShader(shaderHandle);
    
    // 5.大家都是程序员，有程序的地方就会有fail。有程序员的地方必然会有debug。如果编译失败了，我们必须一些信息来找出问题原因。 glGetShaderiv 和 glGetShaderInfoLog  会把error信息输出到屏幕。（然后退出）
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    return shaderHandle;
    
}


/**
 *  创建Vertex Buffer 对象
 传数据到OpenGL的话，最好的方式就是用Vertex Buffer对象。基本上，它们就是用于缓存顶点数据的OpenGL对象。通过调用一些function来把数据发送到OpenGL-land。（是指OpenGL的画面？）这里有两种顶点缓存类型– 一种是用于跟踪每个顶点信息的（正如我们的Vertices array），另一种是用于跟踪组成每个三角形的索引信息（我们的Indices array）。
 */
- (void)setupVBOs {
    //VBO  顶点缓冲区对象 （Vertex Buffer Object VBO）是你显卡内存中的一块高速内存缓冲区，用来存储顶点的所有信息。注意这里的VBO 保存的是订单的位置因为下面把数据传到Vertices
    GLuint vertexBuffer;
    //创建一个VBO 对象  ( Vertex Buffer 顶点信息)
    glGenBuffers(1, &vertexBuffer);
    //glBindBuffer – 告诉OpenGL我们的vertexBuffer 是指GL_ARRAY_BUFFER
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    //glBufferData – 把数据传到OpenGL-land
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);
    //VBO  顶点缓冲区对象 这里的是索引信息  就是使用哪个顶点
    GLuint indexBuffer;
    //创建第二个VBO 对象 (Indices Buffer 索引信息)
    glGenBuffers(1, &indexBuffer);
    //绑定VBO
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    //填充缓冲对象  把数据传到OpenGL-land
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
    
}


//- (void)render:(CADisplayLink*)displayLink {
//
//}












@end
