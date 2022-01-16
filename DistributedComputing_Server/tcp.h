#include<stdio.h>
#include<sys/types.h>
#include<stdlib.h>
#include<string>
#include<sys/socket.h>
#include<netinet/in.h>
#include<arpa/inet.h>
#include<unistd.h>
#include<iostream>
#include<sys/time.h>
#include<iostream>

using namespace std;

#define THREADS 4
#define MAX_THREADS 64
#define SUBDATANUM 1000000
#define DATANUM (SUBDATANUM * MAX_THREADS)
#define BLOCKSIZE 4096

float *rawFloatData = NULL;
float *result = NULL;

int fd;

struct tcp_arg_list{
    float *data;
    int datanum;
};


class tcp_send
{
private:
    struct sockaddr_in addr;
    char buffer[255];
    double hot;
public:
    int fd;
    int socket_fd;
    tcp_send()
    {
        send_initial();
    }
    ~tcp_send()
    {
        close(fd);
    }
    void send_initial();
    void client_ready();
    void send(float *data,const int &datanum);
    void send(const float &data);
    void send(const double &data);
};

class tcp_receive
{
private:
    struct sockaddr_in addr;
public:
    int fd;
    int socket_fd;
    char buffer[255];
    double hot;
    tcp_receive()
    {
        receive_initial();
    }
    ~tcp_receive()
    {
        close(socket_fd);
    }
    void receive_initial();
    void server_ready();
    void receive(float *data,const int &datanum);
    void receive(float &data);
    void receive(double &data);
};

void tcp_send::send_initial()
{
    socket_fd = socket(AF_INET, SOCK_STREAM,0);
    if(socket_fd == -1)
    {
        cout<<"socket 创建失败："<<endl;
        exit(-1);
    }

    //struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(8889);                        //端口号
    addr.sin_addr.s_addr = inet_addr("192.168.1.106");   // 服务端的IP地址

    int res = connect(socket_fd,(struct sockaddr*)&addr,sizeof(addr));  
    int retry_num=0;
    while(res == -1)                                    //连接失败就重试5次
    {
        cout<<"bind 链接失败："<<endl;
        sleep(1);
        retry_num++;
        res = connect(socket_fd,(struct sockaddr*)&addr,sizeof(addr));
        if(retry_num>5)
        {
            exit(-1);
        }
        
    }
    cout<<"bind 链接成功："<<endl;
}

void tcp_receive::receive_initial()
{
    //1.创建一个socket
    socket_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (socket_fd == -1)
    {
        cout << "socket 创建失败： "<< endl;
        exit(1);
    }
    //2.准备通讯地址（必须是服务器的）
    //struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(8889);//将一个无符号短整型的主机数值转换为网络字节顺序，即大尾顺序(big-endian)       设定端口号
    addr.sin_addr.s_addr = inet_addr("192.168.1.106");//net_addr方法可以转化字符串，主要用来将一个十进制的数转化为二进制的数，用途多于ipv4的IP转化。
    //3.bind()绑定
    //参数一：0的返回值（socket_fd）
    //参数二：(struct sockaddr*)&addr 前面结构体，即地址
    //参数三: addr结构体的长度
    int res = bind(socket_fd,(struct sockaddr*)&addr,sizeof(addr));
    if (res == -1)
    {
        cout << "bind创建失败： " << endl;
        exit(-1);
    }
    cout << "bind ok 等待客户端的连接" << endl;
    //4.监听客户端listen()函数
    //参数二：进程上限，一般小于30
    listen(socket_fd,30);
    //5.等待客户端的连接accept()，返回用于交互的socket描述符
    struct sockaddr_in client;
    socklen_t len = sizeof(client);
    fd = accept(socket_fd,(struct sockaddr*)&client,&len);
    if (fd == -1)
    {
        cout << "accept错误\n" << endl;
        exit(-1);
    }
    //6.使用第5步返回socket描述符，进行读写通信。
    char *ip = inet_ntoa(client.sin_addr);
    cout << "客户： 【" << ip << "】连接成功" << endl;
}


void tcp_send::send(float *data,const int &datanum)
{
    int send_num=5000;            //单次发送数据量大小
    //int num=0;
    for(int i=0;i<datanum/send_num;i++)
    {
        int size=write(socket_fd,&data[i*send_num],sizeof(float)*send_num);
    }
    cout<<"发完了"<<" "<<fixed<<data[datanum-1]<<endl;

}

void tcp_send::send(const float &data)
{
    write(socket_fd,&data,sizeof(data));
}

void tcp_send::send(const double &data)
{
    write(socket_fd,&data,sizeof(data));
}

void tcp_receive::receive(float *data,const int &datanum)
{
    int buffer_num=1000;            //每次分段收数据的数据大小
    int read_num=0;                 //目前读取数据的个数(或者说首地址也行)
    while (1)
    {
        int size=read(fd, &data[read_num], sizeof(float)*buffer_num);
        read_num=read_num+size/sizeof(data[0]);
        if(size==0)                 //cout的时候才需要用到的
        {
            continue;          
        }
        
        if(read_num==datanum)
        {
            break;
        }
    }
}

void tcp_receive::receive(float &data)
{
    read(fd,&data,sizeof(data));
}

void tcp_receive::receive(double &data)
{
    read(fd,&data,sizeof(data));
}

void tcp_send::client_ready()
{
    for(int i = 0; i < 1; i++)
    {
        buffer[0]=0;
        read(socket_fd,buffer,sizeof(buffer));
        cout<<buffer[0]<<endl;
        hot=66.6;
        send(hot);
    }
}

void tcp_receive::server_ready()
{
    for(int i = 0; i < 1; i++)
    {
        write(fd,"S",15);
        hot=0.0;
        receive(hot);
    }
}

void *receive_sort(void* arg)
{
    tcp_arg_list* param;
    param = (tcp_arg_list*) arg;

    int buffer_num=1000;            //每次分段收数据的数据大小
    int read_num=0;                 //目前读取数据的个数(或者说首地址也行)
    while (1)
    {
        int size=read(fd, &(result[read_num]), sizeof(float)*buffer_num);
        read_num=read_num+size/sizeof(result[0]);
        if(size==0)                 //cout的时候才需要用到的
        {
            continue;          
        }
        if(read_num==param->datanum)
        {
            break;
        }
    }
}
