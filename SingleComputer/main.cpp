#include <iostream>
#include "Methods.h"
// #include <windows.h>  //Windows
#include "sys/time.h"   //Linux
using namespace std;

float rawFloatData[DATANUM];
float result[DATANUM];

/************                 Windows                 *************/
/*int main()
{
    
    float Sum, Max;
    LARGE_INTEGER start, end;
    LARGE_INTEGER freq;

    QueryPerformanceFrequency(&freq);

    dataInit(rawFloatData, DATANUM);
    dataInit(result, DATANUM);

    QueryPerformanceCounter(&start);//start 
    Sum = sumCommon(rawFloatData, DATANUM);
    QueryPerformanceCounter(&end);//end
    cout << "Sum Time Consumed:" << (double)(end.QuadPart - start.QuadPart) * 1e3 / (double)freq.QuadPart << "ms" << endl;

    QueryPerformanceCounter(&start);//start 
    Max = maxCommon(rawFloatData, DATANUM);
    QueryPerformanceCounter(&end);//end
    cout << "Max Time Consumed:" << (double)(end.QuadPart - start.QuadPart) * 1e3 / (double)freq.QuadPart << "ms" << endl;

    QueryPerformanceCounter(&start);//start 
    sortCommon(result, 0, DATANUM - 1);
    QueryPerformanceCounter(&end);//end
    cout << "Sort Time Consumed:" << (double)(end.QuadPart - start.QuadPart) * 1e3 / (double)freq.QuadPart << "ms" << endl;

    cout << "Sum: " << Sum << '\n' << "Max: " << Max << endl;
    cout << "Sort correctly? --> " << checkSort(result, DATANUM) << endl;

    return 0;
}*/

/************                 Linux                 *************/
int main()
{
    double Sum;
    float Max;
    timeval start, end;

    dataInit(rawFloatData, DATANUM);
    dataInit(result, DATANUM);

    gettimeofday(&start, NULL);//start
    Sum = sumCommon(rawFloatData, DATANUM);
    gettimeofday(&end, NULL); //end
    cout << "Sum Time Consumed:" << 1e3 * (double)(end.tv_sec - start.tv_sec) + (double)(end.tv_usec - start.tv_usec) / 1e3 << "ms" << endl;

    gettimeofday(&start, NULL);//start
    Max = maxCommon(rawFloatData, DATANUM);
    gettimeofday(&end, NULL); //end
    cout << "Max Time Consumed:" << 1e3 * (double)(end.tv_sec - start.tv_sec) + (double)(end.tv_usec - start.tv_usec) / 1e3 << "ms" << endl;

    gettimeofday(&start, NULL);//start
    sortCommon(result, DATANUM);
    gettimeofday(&end, NULL); //end
    cout << "Sort Time Consumed:" << 1e3 * (double)(end.tv_sec - start.tv_sec) + (double)(end.tv_usec - start.tv_usec) / 1e3 << "ms" << endl;

    // cout << "Sum: " << Sum << '\n' << "Max: " << Max << endl;
    printf("CPU Sum: %f\n", Sum);
    printf("CPU Max: %f\n", Max);
    cout << "Sort correctly? --> " << checkSort(result, DATANUM) << endl;

    return 0;
}