#include <stddef.h>

#define CL_PLATFORM_NOT_FOUND_KHR (-1001)
#define CL_INVALID_OPERATION (-59)

int clGetPlatformIDs() {
    return CL_PLATFORM_NOT_FOUND_KHR;
}

int clGetPlatformInfo() {
    return CL_PLATFORM_NOT_FOUND_KHR;
}

int clGetDeviceIDs() {
    return CL_PLATFORM_NOT_FOUND_KHR;
}

int clGetDeviceInfo() {
    return CL_PLATFORM_NOT_FOUND_KHR;
}

void *clCreateContext() {
    return NULL;
}

void *clCreateCommandQueue() {
    return NULL;
}

void *clCreateBuffer() {
    return NULL;
}

void *clCreateBufferWithProperties() {
    return NULL;
}

void *clCreateImage() {
    return NULL;
}

void *clCreateSubBuffer() {
    return NULL;
}

void *clCreateProgramWithSource() {
    return NULL;
}

int clBuildProgram() {
    return CL_INVALID_OPERATION;
}

int clGetProgramBuildInfo() {
    return CL_INVALID_OPERATION;
}

void *clCreateKernel() {
    return NULL;
}

int clGetKernelWorkGroupInfo() {
    return CL_INVALID_OPERATION;
}

int clSetKernelArg() {
    return CL_INVALID_OPERATION;
}

int clEnqueueNDRangeKernel() {
    return CL_INVALID_OPERATION;
}

int clEnqueueReadBuffer() {
    return CL_INVALID_OPERATION;
}

int clEnqueueWriteBuffer() {
    return CL_INVALID_OPERATION;
}

int clEnqueueCopyBuffer() {
    return CL_INVALID_OPERATION;
}

int clEnqueueFillBuffer() {
    return CL_INVALID_OPERATION;
}

int clEnqueueBarrierWithWaitList() {
    return CL_INVALID_OPERATION;
}

int clEnqueueMarkerWithWaitList() {
    return CL_INVALID_OPERATION;
}

int clWaitForEvents() {
    return CL_INVALID_OPERATION;
}

int clReleaseEvent() {
    return 0;
}

int clReleaseMemObject() {
    return 0;
}

int clReleaseProgram() {
    return 0;
}

int clReleaseContext() {
    return 0;
}

int clFlush() {
    return 0;
}

int clFinish() {
    return 0;
}
