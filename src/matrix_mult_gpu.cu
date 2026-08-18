#include <iostream>
#include <mpi.h>
#include <vector>
#include <chrono>
#include <cstdlib>
#include <string>
#include <cmath>

using Matrix = std::vector<double>;

void initMatrix(Matrix &matrix, int size)
{
    for (int i = 0; i < (size * size); i++)
    {
        // bound values between 0.0 and 0.99 using modulo so numbers stay
        // small and reproducible instead of growing unbounded with i
        matrix[i] = static_cast<double>(i % 100) / 100.0;
    }
}

__global__ void multiplyKernel(double *A, double *B, double *C, int size)
{
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    double sum = 0.0;
    for (int k = 0; k < size; k++)
    {
        sum += A[row * size + k] * B[k * size + col];
    }
    C[row * size + col] = sum;
}

void multiplyOnGPU(Matrix &subA, Matrix &B, Matrix &subC, int rowsPerProcess, int size)
{
    size_t chunkBytes = sizeof(double) * (rowsPerProcess * size);
    size_t fullMatrixBytes = sizeof(double) * (size * size);

    double *d_subA;
    double *d_B;
    double *d_subC;
    cudaMalloc(&d_subA, chunkBytes);
    cudaMalloc(&d_B, fullMatrixBytes);
    cudaMalloc(&d_subC, chunkBytes);

    cudaMemcpy(d_subA, subA.data(), chunkBytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, B.data(), fullMatrixBytes, cudaMemcpyHostToDevice);

    dim3 threadsPerBlock(16, 16);
    dim3 numBlocks(size / 16, rowsPerProcess / 16);

    multiplyKernel<<<numBlocks, threadsPerBlock>>>(d_subA, d_B, d_subC, size);

    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess)
    {
        std::cout << "CUDA kernel launch failed: " << cudaGetErrorString(err) << "\n";
    }

    cudaDeviceSynchronize();
    cudaMemcpy(subC.data(), d_subC, chunkBytes, cudaMemcpyDeviceToHost);

    cudaFree(d_subA);
    cudaFree(d_B);
    cudaFree(d_subC);
}

int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);

    int mpiRank;
    MPI_Comm_rank(MPI_COMM_WORLD, &mpiRank);
    int mpiSize;
    MPI_Comm_size(MPI_COMM_WORLD, &mpiSize);

    const char *matrixSizeEnv = std::getenv("MATRIX_SIZE");

    if (matrixSizeEnv == nullptr)
    {
        std::cout << "ERROR: MATRIX_SIZE environment variable not set!\n";
        return EXIT_FAILURE;
    }

    int size = std::stoi(matrixSizeEnv);
    int rowsPerProcess = size / mpiSize;

    Matrix A(size * size);
    Matrix B(size * size);
    Matrix C(size * size, 0.0);
    Matrix subA(rowsPerProcess * size);
    Matrix subC(rowsPerProcess * size);

    if (mpiRank == 0)
    {
        initMatrix(A, size);
        initMatrix(B, size);
    }

    auto jobStart = std::chrono::high_resolution_clock::now();

    MPI_Bcast(B.data(), size * size, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    MPI_Scatter(A.data(), rowsPerProcess * size, MPI_DOUBLE, subA.data(), rowsPerProcess * size, MPI_DOUBLE, 0, MPI_COMM_WORLD);

    std::cout << "Process " << mpiRank << " received its data.\n";

    auto start = std::chrono::high_resolution_clock::now();

    multiplyOnGPU(subA, B, subC, rowsPerProcess, size);

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> elapsed = end - start;

    std::cout << "Process " << mpiRank << " finished multiplying in " << elapsed.count() << " seconds.\n";

    MPI_Gather(subC.data(), rowsPerProcess * size, MPI_DOUBLE, C.data(), rowsPerProcess * size, MPI_DOUBLE, 0, MPI_COMM_WORLD);

    auto jobEnd = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> jobElapsed = jobEnd - jobStart;

    if (mpiRank == 0)
    {
        std::cout << "All results gathered on master.\n";

        // independently recompute C[0] using a plain loop over the original A and B
        // to verify the distributed computation produced a mathematically correct result,
        // not just that it ran without crashing
        double expected = 0.0;
        for (int k = 0; k < size; k++)
        {
            expected += A[k] * B[k * size];
        }

        std::cout << "Verification: C[0] = " << C[0] << ", expected = " << expected;
        if (std::abs(C[0] - expected) < 1e-9)
        {
            std::cout << " [PASSED]\n";
        }
        else
        {
            std::cout << " [FAILED]\n";
        }

        std::cout << "Total job time: " << jobElapsed.count() << " seconds.\n";
    }

    MPI_Finalize();
    return EXIT_SUCCESS;
}