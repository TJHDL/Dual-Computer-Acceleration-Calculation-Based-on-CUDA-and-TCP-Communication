#include <iostream>
#include "Methods.cuh"
#include "sys/time.h"   //Linux
#include "stdlib.h"
#include "stdio.h"
using namespace std;

pthread_t threadId[2];

int main()
{
    /************************初始化************************/
    double Sum = 0.0, Sum_t = 0.0;
    float Max = 0.0f, Max_t = 0.0f;
    timeval start, end;
    SpeedUp Fast;
    /****************************************************/

    /***********************建立通信***********************/
    // Initialize tcp
    tcp_receive server;
    server.server_ready();
    fd = server.fd;
    /*****************************************************/

    /***********************计算过程***********************/
    write(server.fd, "T", 15); //  启动另一台计算机开始计算
    gettimeofday(&start, NULL);//start
    Sum = Fast.sumSpeedUp(rawFloatData, DATANUM);
    server.receive(Sum_t);
    Sum += Sum_t;
    gettimeofday(&end, NULL); //end
    cout << "GPU Sum Time Consumed:" << 1e3 * (double)(end.tv_sec - start.tv_sec) + (double)(end.tv_usec - start.tv_usec) / 1e3 << "ms" << endl;

    write(server.fd, "L", 15); //  启动另一台计算机开始计算
    gettimeofday(&start, NULL);//start
    Max = Fast.maxSpeedUp(rawFloatData, DATANUM);
    server.receive(Max_t);
    Max = (Max > Max_t)? Max:Max_t;
    gettimeofday(&end, NULL); //end
    cout << "GPU Max Time Consumed:" << 1e3 * (double)(end.tv_sec - start.tv_sec) + (double)(end.tv_usec - start.tv_usec) / 1e3 << "ms" << endl;


    write(server.fd, "H", 15); //  启动另一台计算机开始计算
    gettimeofday(&start, NULL);//start
    /***************=== Two threads: Thread1->communication / Thread2->compute ===***************/
    struct tcp_arg_list H_pstru1;
    H_pstru1.data = result;
    H_pstru1.datanum = DATANUM;
    pthread_create(&threadId[0], NULL, receive_sort, &H_pstru1);
    struct sort_arg_list H_pstru2;
    H_pstru2.data = result + DATANUM;
    H_pstru2.len = DATANUM;
    pthread_create(&threadId[1], NULL, sortSpeedUp, &H_pstru2);

    void *H_recycle;
    pthread_join(threadId[0], &H_recycle);
    pthread_join(threadId[1], &H_recycle);
    /********************************************************************************************/
    gettimeofday(&end, NULL); //end
    cout << "GPU Sort Time Consumed:" << 1e3 * (double)(end.tv_sec - start.tv_sec) + (double)(end.tv_usec - start.tv_usec) / 1e3 << "ms" << endl;

    printf("GPU Sum: %lf\n", Sum);
    printf("GPU Max: %f\n", Max);
    cout << "Sort correctly? --> " << Fast.checkSort(result, DATANUM) << endl;
    /*****************************************************/

    /***********************断开通信***********************/
    //  断开连接
    write(server.fd, "Z", 15);
    /*****************************************************/

    return 0;
}