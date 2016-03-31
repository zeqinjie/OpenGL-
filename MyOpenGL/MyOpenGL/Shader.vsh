attribute vec3 position;   //入参，主程序会将数值传入
void main()
{
    gl_Position = vec4(position,1);  //顶点经过投影变换变换后的位置
}