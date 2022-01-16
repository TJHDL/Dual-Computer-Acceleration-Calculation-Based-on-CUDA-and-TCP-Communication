#include <iostream>
#include "Methods.cuh"
#include "sys/time.h"   //Linux
#include "stdlib.h"
#include "stdio.h"
using namespace std;

int main()
{
    double Sum;
    float Max;
    timeval start, end;

    SpeedUp Fast;

    tcp_send client;
    client.client_ready();

//***************************************************
    //等待服务端发送开始工作的指令
    char start_flag[15];
    while (1)
    {
        read(client.socket_fd,start_flag,15);
        if (start_flag[0]=='T')
        {
            break;
        }
    }
//***************************************************

    gettimeofday(&start, NULL);//start
    Sum = Fast.sumSpeedUp(rawFloatData, DATANUM);
    client.send(Sum);
    gettimeofday(&end, NULL); //end
    cout << "GPU Sum Time Consumed:" << 1e3 * (double)(end.tv_sec - start.tv_sec) + (double)(end.tv_usec - start.tv_usec) / 1e3 << "ms" << endl;

//***************************************************
    //等待服务端发送开始工作的指令
    while (1)
    {
        read(client.socket_fd,start_flag,15);
        if (start_flag[0]=='L')
        {
            break;
        }
    }
//***************************************************

    gettimeofday(&start, NULL);//start
    Max = Fast.maxSpeedUp(rawFloatData, DATANUM);
    client.send(Max);
    gettimeofday(&end, NULL); //end
    cout << "GPU Max Time Consumed:" << 1e3 * (double)(end.tv_sec - start.tv_sec) + (double)(end.tv_usec - start.tv_usec) / 1e3 << "ms" << endl;

//***************************************************
    //等待服务端发送开始工作的指令
    while (1)
    {
        read(client.socket_fd,start_flag,15);
        if (start_flag[0]=='H')
        {
            break;
        }
    }
//***************************************************

    gettimeofday(&start, NULL);//start
    Fast.sortSpeedUp(result, DATANUM);
    gettimeofday(&end, NULL); //end
    cout << "GPU Sort Time Consumed:" << 1e3 * (double)(end.tv_sec - start.tv_sec) + (double)(end.tv_usec - start.tv_usec) / 1e3 << "ms" << endl;
    client.send(result,DATANUM);
    
    printf("GPU Sum: %lf\n", Sum);
    printf("GPU Max: %f\n", Max);
    cout << "Sort correctly? --> " << Fast.checkSort(result, DATANUM) << endl;

//***************************************************
    //等待服务端发送开始工作的指令
    while (1)
    {
        read(client.socket_fd,start_flag,15);
        if (start_flag[0]=='Z')
        {
            break;
        }
    }
//***************************************************
    return 0;
}