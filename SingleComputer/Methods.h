#pragma once
#include "iostream"
#include "cmath"
using namespace std;

#define MAX_THREADS 64
#define SUBDATANUM 1000000  //  2000000
#define DATANUM (SUBDATANUM * MAX_THREADS)

void dataInit(float* data, const int len)
{
    for (size_t i = 0; i < DATANUM; i++)
    {
        data[i] = float(i + 1);
    }
}

double sumCommon(const float data[], const int len)
{
    double ret = 0.0f;

    for (size_t i = 0; i < len; i++)
    {
        ret += log(sqrt(data[i]));
        // ret += data[i];
    }

    return ret;
}

float maxCommon(const float data[], const int len)
{
    float ret = 0.0f;

    for (size_t i = 0; i < len; i++)
    {
        if (log(sqrt(data[i])) > ret)
            ret = log(sqrt(data[i]));
    }

    return ret;
}

//将vec[begin1, ... ,end1]和 vec[end1+1, ... ,end_2]合并后存放到temp中
void mergeTwo(float* result, int begin1, int end1, int end2)
{
    int i = begin1, j = end1+1, k = 0;
    float* temp = (float*)malloc((end2-begin1+1) * sizeof(float));    // 临时数组，用于存放两段有序数组合并后的结果
    while (i <= end1 && j <= end2)
    {
        if (result[i] >= result[j])
        {
            temp[k++] = result[i++];          
        }
        else {
            temp[k++] = result[j++];          
        }
    }
    while (i <= end1)
    {
        temp[k++] = result[i++];
    }
    while (j <= end2)
    {
        temp[k++] = result[j++];
    }

    // 用合并后的结果temp把vec[begin1,... ,end_2]覆盖掉
    for (int i = 0; i < end2-begin1+1; ++i)
    {
        result[begin1 + i] = temp[i];
    }
}

float sortCommon(float* result, int len)
{
    const int size = len;
    int end1, end2;
    for (int width = 1; width < size; width *= 2)
    {
        for (int i = 0; i < size; i += 2 * width)
        {
            end1 = ((i+width-1) < (size-1))? (i+width-1):(size-1);
            end2 = ((i+2*width-1) < (size-1))? (i+2*width-1):(size-1);
            mergeTwo(result, i, end1, end2);
        }
    }

    return 0.0f;
}

bool checkSort(const float data[], const int len)
{
    bool ret = true;
    
    for (int i = 0; i < len - 1; i++)
    {
        if (data[i + 1] > data[i])
        {
            ret = false;
            break;
        }
    }

    return ret;
}
