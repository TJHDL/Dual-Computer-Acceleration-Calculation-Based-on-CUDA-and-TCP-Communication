#pragma once
#include "iostream"
#include "cmath"
#include "cuda_runtime.h"
#include "cublas_v2.h"
#include "device_launch_parameters.h"
#include "stdio.h"
#include "sys/time.h"
#include "tcp.h"
using namespace std;

#define HANDLE_ERROR(err) (HandleError(err, __FILE__, __LINE__))

static void HandleError(cudaError_t err, const char *file, int line) {
	if (err != cudaSuccess) {
		fprintf(stderr, "Error %d: \"%s\" in %s at line %d\n", int(err), cudaGetErrorString(err), file, line);
		exit(int(err));
	}
}

pthread_t sort_reduction_threadId[THREADS];

struct arg_data{
    float* data;
    size_t len;
};

struct sort_arg_list{
    float* data;
    size_t len;
};

class SpeedUp
{
    private:
        cublasHandle_t cuHandle;
        cublasStatus_t status;
    public:
        SpeedUp();
        ~SpeedUp();

        void dataInit(float* data, const int len);
        bool initCUDA();
        void printCUDA();
        void printArray(float A[], int size);
        double sumSpeedUp(const float data[], const int len);
        float maxSpeedUp(const float data[], const int len);
        float sortSpeedUp(float* data, const int len);
        bool checkSort(float data[], const int len);
};

void mergeFinal(float* result, int begin1, int end1, int end2)
{
    int i = begin1, j = end1+1, k = 0;
    float* temp = (float*)malloc((end2-begin1+1) * sizeof(float)); // 临时数组，用于存放两段有序数组合并后的结果
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

    free(temp);
}

void sort_final(float* data, size_t len, int wid)
{
	const int size = len;
    int end1, end2;
    for (int width = wid; width < size; width *= 2)
    {
        for (int i = 0; i < size; i += 2 * width)
        {
            end1 = ((i+width-1) < (size-1))? (i+width-1):(size-1);
            end2 = ((i+2*width-1) < (size-1))? (i+2*width-1):(size-1);
            mergeFinal(data, i, end1, end2);
        }
    }
}

void *sort_final(void* arg)
{
    arg_data* param;
    param = (arg_data*) arg;

    const int size = param->len;
    int end1, end2;
    for (int width = (DATANUM / BLOCKSIZE); width < size; width *= 2)
    {
        for (int i = 0; i < size; i += 2 * width)
        {
            end1 = ((i+width-1) < (size-1))? (i+width-1):(size-1);
            end2 = ((i+2*width-1) < (size-1))? (i+2*width-1):(size-1);
            mergeFinal(param->data, i, end1, end2);
        }
    }

    return (void*)0;
}

__global__ void sum_kernel(float* d_data, float* d_ret, const int len)
{
    /******************Plan A******************/    //  ~34.5ms
    // //set thread ID
    // unsigned int tid = threadIdx.x;
    // //boundary check
    // if (tid >= len) return;
    // //convert global data pointer to the 
    // float *idata = d_data + blockIdx.x*blockDim.x;
    // idata[tid] = log(sqrt(idata[tid]));
    // __syncthreads();
    // //in-place reduction in global memory
    // for (int stride = 1; stride < blockDim.x; stride *= 2)
    // {
    //     if ((tid % (2 * stride)) == 0)
    //     {
    //         idata[tid] += idata[tid + stride];
    //     }
    //     //synchronize within block
    //     __syncthreads();
    // }

    // //write result for this block to global mem
    // if (tid == 0)
    //     d_ret[blockIdx.x] = idata[0];
    /******************************************/

    /******************Plan B******************/    //  ~26.0ms
    __shared__ float smem[1024];    //
    //set thread ID
    unsigned int tid = threadIdx.x;
    unsigned int idx = blockIdx.x * blockDim.x + threadIdx.x;
    //boundary check
    if(idx >= len) return;
    //convert global data pointer to the 
    float *idata = d_data + blockIdx.x*blockDim.x;
    smem[tid] = idata[tid]; //
    smem[tid] = log(sqrt(smem[tid]));   //
    __syncthreads();
    //in-place reduction in global memory
    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1)
    {
        if (tid < stride)
        {
            smem[tid] += smem[tid + stride];    //
        }
        //synchronize within block
        __syncthreads();
    }
    //write result for this block to global mem
    if (tid == 0)
        d_ret[blockIdx.x] = smem[0];    //
    /******************************************/
}

__global__ void max_kernel(float* d_data, float* d_ret, const int len)
{
    /******************Plan A******************/    //~44ms
    // //set thread ID
    // unsigned int tid = threadIdx.x;
    // //boundary check
    // if (tid >= len) return;
    // //convert global data pointer to the 
    // float *idata = d_data + blockIdx.x*blockDim.x;
    // idata[tid] = log(sqrt(idata[tid]));
    // __syncthreads();
    // //in-place reduction in global memory
    // for (int stride = 1; stride < blockDim.x; stride *= 2)
    // {
    //     if ((tid % (2 * stride)) == 0)
    //     {
    //         if(idata[tid] < idata[tid + stride])
    //             idata[tid] = idata[tid + stride];
    //     }
    //     //synchronize within block
    //     __syncthreads();
    // }
    // //write result for this block to global mem
    // if (tid == 0)
    //     d_ret[blockIdx.x] = idata[0];
    /******************************************/

    /******************Plan B******************/    //  ~35.5ms
    __shared__ float smem[1024];    //
    //set thread ID
    unsigned int tid = threadIdx.x;
    unsigned int idx = blockIdx.x * blockDim.x + threadIdx.x;
    //boundary check
    if (idx >= len) return;
    //convert global data pointer to the 
    float *idata = d_data + blockIdx.x*blockDim.x;
    smem[tid] = idata[tid]; //
    smem[tid] = log(sqrt(smem[tid]));
    __syncthreads();
    //in-place reduction in global memory
    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1)
    {
        if (tid < stride)
        {
            if(smem[tid] < smem[tid + stride])
                smem[tid] = smem[tid + stride];
        }
        //synchronize within block
        __syncthreads();
    }
    //write result for this block to global mem
    if (tid == 0)
        d_ret[blockIdx.x] = smem[0];
    /******************************************/
}

__device__ void mergeTwo(float* result, int begin1, int end1, int end2, float* temp)
{
    int i = begin1, j = end1+1, k = 0;
    
    while (i <= end1 && j <= end2)
    {
        if (result[i] >= result[j])
        {
            temp[k++] = result[i++];
        }
        else
        {
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

__global__ void sort_kernel(float* d_data, size_t len, float* temp)
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    // int tid = threadIdx.x;

	const int size = DATANUM / BLOCKSIZE;
    float* sub_data = d_data + tid * size;
    float* sub_temp = temp + tid * size;
    int end1, end2;
    for (int width = 1; width < size; width *= 2)
    {
        for (int i = 0; i < size; i += 2 * width)
        {
            end1 = ((i+width-1) < (size-1))? (i+width-1):(size-1);
            end2 = ((i+2*width-1) < (size-1))? (i+2*width-1):(size-1);
            mergeTwo(sub_data, i, end1, end2, sub_temp);   //  unspecified launch failure 栈溢出或指针越界
        }
    }
	__syncthreads();
}

void *sortSpeedUp(void* arg)
{
    sort_arg_list* param;
    param = (sort_arg_list*) arg;

    //  1.定义kernel的执行配置
    int blockSize = BLOCKSIZE;
    int gridSize = 1;

    //  2.分配CPU资源

    //  3.分配GPU资源
    float* d_data = NULL;
    float* temp = NULL;
    cudaMalloc((void**)&d_data, param->len * sizeof(float));
    cudaMalloc((void**)&temp, param->len * sizeof(float));

    //  将CPU数据拷贝到GPU上
    cudaMemcpy(d_data, param->data, param->len * sizeof(float), cudaMemcpyHostToDevice);

    //  4.执行核函数
    sort_kernel<<<blockSize, gridSize>>>(d_data, param->len, temp);
    cudaError_t ct = cudaDeviceSynchronize();
    // printf("%s\n", cudaGetErrorString(ct));

    //  5.将GPU数据拷贝到CPU上
    cudaMemcpy(param->data, d_data, param->len * sizeof(float), cudaMemcpyDeviceToHost);

    // 6.赋值给结果变量
    /***************Plan A*******************/  //  ~3520ms
    // sort_final(data, len, DATANUM / BLOCKSIZE);   
    /****************************************/

    /***************Plan B*******************/  //  ~1755ms
    struct arg_data pstru[THREADS];

    for(int i = 0; i < THREADS; i++)
    {
        pstru[i].data = param->data + i*(DATANUM / THREADS);
        pstru[i].len = (DATANUM / THREADS);
        pthread_create(&sort_reduction_threadId[i], NULL, sort_final, &(pstru[i]));
    }

    void *recycle;
    for(int i = 0; i < THREADS; i++)
    {
        pthread_join(sort_reduction_threadId[i], &recycle);
    }
    sort_final(param->data, DATANUM, DATANUM / THREADS);    
    /****************************************/

    //  7.清理掉使用过的内存
    cudaFree(d_data);
    cudaFree(temp);

}

SpeedUp::SpeedUp()
{
    /*==============Initialize CUDA==============*/
    if(!initCUDA()) {
        cout << "CUDA failed initialize!" << endl;
        return;
    }
    cout << "CUDA initialized." << endl;
    printCUDA();
    /*===========================================*/

    status = cublasCreate(&cuHandle);

    cudaMallocHost((void**)&rawFloatData, DATANUM * sizeof(float));
    cudaMallocHost((void**)&result, 2 * DATANUM * sizeof(float));

    dataInit(rawFloatData, DATANUM);
    dataInit(result + DATANUM, DATANUM);
}

SpeedUp::~SpeedUp()
{
    //  释放固定内存
    cudaFreeHost(rawFloatData);
    cudaFreeHost(result);

    //  销毁cuda消息处理器
    cublasDestroy(cuHandle);

    //reset device
    cudaDeviceReset();
}

void SpeedUp::dataInit(float* data, const int len)
{
    for (size_t i = 0; i < DATANUM; i++)
    {
        data[i] = float(i + 1);
    }
}

bool SpeedUp::initCUDA()
{
    int count;

    cudaGetDeviceCount(&count);
    if(count ==  0) {
        fprintf(stderr, "There is no device.\n ");
        return  false;
    }

    int i;
    for(i =  0; i < count; i++) {
        cudaDeviceProp prop;
         if(cudaGetDeviceProperties(&prop, i) == cudaSuccess) {
             if(prop.major >=  1) {
               break;
            }
        }
    }

     if(i == count) {
        fprintf(stderr, "There is no device supporting CUDA 1.x.\n ");
        return  false;
    }

    cudaSetDevice(i);

    return true;
}

void SpeedUp::printCUDA()
{
    int deviceCount;
    cudaGetDeviceCount(&deviceCount);
    for(int i=0;i<deviceCount;i++)
    {
        cudaDeviceProp devProp;
        cudaGetDeviceProperties(&devProp, i);
        std::cout << "使用GPU device " << i << ": " << devProp.name << std::endl;
        std::cout << "设备全局内存总量： " << devProp.totalGlobalMem / 1024 / 1024 << "MB" << std::endl;
        std::cout << "SM的数量：" << devProp.multiProcessorCount << std::endl;
        std::cout << "每个线程块的共享内存大小：" << devProp.sharedMemPerBlock / 1024.0 << " KB" << std::endl;
        std::cout << "每个线程块的最大线程数：" << devProp.maxThreadsPerBlock << std::endl;
        std::cout << "设备上一个线程块（Block）中可用的32位寄存器数量： " << devProp.regsPerBlock << std::endl;
        std::cout << "每个EM的最大线程数：" << devProp.maxThreadsPerMultiProcessor << std::endl;
        std::cout << "每个EM的最大线程束数：" << devProp.maxThreadsPerMultiProcessor / 32 << std::endl;
        std::cout << "设备上多处理器的数量： " << devProp.multiProcessorCount << std::endl;
        std::cout << "======================================================" << std::endl;     
        
    }
}

void SpeedUp::printArray(float A[], int size)
{
	int i;
	for (i = 0; i < size; i++)
		printf("%d ", int(A[i]));
	printf("\n");
}

double SpeedUp::sumSpeedUp(const float data[], const int len)
{
    double ret = 0.0;

    //  1.定义kernel的执行配置
    int blockSize;
    int minGridSize;
    int gridSize; 
	// 获取GPU的信息，并配置最优参数
    cudaOccupancyMaxPotentialBlockSize(&minGridSize, &blockSize, sum_kernel, 0, len);
    gridSize = (len + blockSize - 1) / blockSize; 
    // cout << "The param 'gridSize' is: " << gridSize << endl;
    // cout << "The param 'blockSize' is: " << blockSize << endl;

    //  2.分配CPU资源
    float* h_ret = (float*)malloc(gridSize * sizeof(float));

    //  3.分配GPU资源
    float* d_data = NULL, *d_ret = NULL;
    cudaMalloc((void**)&d_data, len * sizeof(float));
    cudaMalloc((void**)&d_ret, gridSize * sizeof(float));

    //  将CPU数据拷贝到GPU上
    cudaMemcpy(d_data, data, len * sizeof(float), cudaMemcpyHostToDevice);

    //  4.执行核函数
    sum_kernel <<< gridSize, blockSize >>> (d_data, d_ret, len); //Plan A/Plan B
    cudaDeviceSynchronize();

    //  5.将GPU数据拷贝到CPU上
    cudaMemcpy(h_ret, d_ret, gridSize * sizeof(float), cudaMemcpyDeviceToHost);

    //  6.赋值给结果变量
    for (int i = 0; i < gridSize; i++)
        ret += h_ret[i];

    //  7.清理掉使用过的内存
    free(h_ret);
    cudaFree(d_data);
    cudaFree(d_ret);

    return ret;
}

float SpeedUp::maxSpeedUp(const float data[], const int len)
{
    float ret = 0.0f;

    //  1.定义kernel的执行配置
    int blockSize;
    int minGridSize;
    int gridSize; 
	// 获取GPU的信息，并配置最优参数
    cudaOccupancyMaxPotentialBlockSize(&minGridSize, &blockSize, max_kernel, 0, len);
    gridSize = (len + blockSize - 1) / blockSize; 
    // cout << "The param 'gridSize' is: " << gridSize << endl;
    // cout << "The param 'blockSize' is: " << blockSize << endl;

    //  2.分配CPU资源
    float* h_ret = (float*)malloc(gridSize * sizeof(float));

    //  3.分配GPU资源
    float* d_data = NULL, *d_ret = NULL;
    cudaMalloc((void**)&d_data, len * sizeof(float));
    cudaMalloc((void**)&d_ret, gridSize * sizeof(float));

    //  将CPU数据拷贝到GPU上
    cudaMemcpy(d_data, data, len * sizeof(float), cudaMemcpyHostToDevice);

    //  4.执行核函数
    max_kernel <<< gridSize, blockSize >>> (d_data, d_ret, len);
    cudaDeviceSynchronize();

    //  5.将GPU数据拷贝到CPU上
    cudaMemcpy(h_ret, d_ret, gridSize * sizeof(float), cudaMemcpyDeviceToHost);

    //  6.赋值给结果变量
    for (int i = 0; i < gridSize; i++)
    {
        if(ret < h_ret[i])
            ret = h_ret[i];
    }

    //  7.清理掉使用过的内存
    free(h_ret);
    cudaFree(d_data);
    cudaFree(d_ret);

    return ret;
}

float SpeedUp::sortSpeedUp(float* data, const int len)
{
    //  1.定义kernel的执行配置
    int blockSize = BLOCKSIZE;
    int gridSize = 1;

    //  2.分配CPU资源

    //  3.分配GPU资源
    float* d_data = NULL;
    float* temp = NULL;
    cudaMalloc((void**)&d_data, len * sizeof(float));
    cudaMalloc((void**)&temp, len * sizeof(float));

    //  将CPU数据拷贝到GPU上
    cudaMemcpy(d_data, data, len * sizeof(float), cudaMemcpyHostToDevice);

    //  4.执行核函数
    sort_kernel<<<blockSize, gridSize>>>(d_data, len, temp);
    cudaError_t ct = cudaDeviceSynchronize();
    // printf("%s\n", cudaGetErrorString(ct));

    //  5.将GPU数据拷贝到CPU上
    cudaMemcpy(data, d_data, len * sizeof(float), cudaMemcpyDeviceToHost);

    // 6.赋值给结果变量
    /***************Plan A*******************/  //  ~3520ms
    // sort_final(data, len, DATANUM / BLOCKSIZE);   
    /****************************************/

    /***************Plan B*******************/  //  ~1755ms
    struct arg_data pstru[THREADS];

    for(int i = 0; i < THREADS; i++)
    {
        pstru[i].data = data + i*(DATANUM / THREADS);
        pstru[i].len = (DATANUM / THREADS);
        pthread_create(&sort_reduction_threadId[i], NULL, sort_final, &(pstru[i]));
    }

    void *recycle;
    for(int i = 0; i < THREADS; i++)
    {
        pthread_join(sort_reduction_threadId[i], &recycle);
    }
    sort_final(data, DATANUM, DATANUM / THREADS);    
    /****************************************/

    //  7.清理掉使用过的内存
    cudaFree(d_data);
    cudaFree(temp);

    return 0.0f;
}

bool SpeedUp::checkSort(float data[], const int len)
{
    bool ret = true;
    
    for (int i = 0; i < 2 * len; i++)
    {
        if (0.01f < fabs(data[i] - (2 * len - i)))
        {
            ret = false;
            break;
        }
    }

    return ret;
}