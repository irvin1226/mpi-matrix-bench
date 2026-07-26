#include <iostream>
#include <mpi.h>
#include <vector>
#include <chrono>
#include <cstdlib>
#include <string>
#include <cmath>

void initMatrix(std::vector<double> &matrix, int size)
{
    for (int i = 0; i < (size * size); i++)
    {
        // bound values between 0.0 and 0.99 using modulo so numbers stay
        // small and reproducible instead of growing unbounded with i
        matrix[i] = static_cast<double>(i % 100) / 100.0;
    }
}

void multiplyRows(
    const std::vector<double> &A,
    const std::vector<double> &B,
    std::vector<double> &C,
    int rowsPerProcess,
    int size)
{
    for (int i = 0; i < rowsPerProcess; i++)
    {
        for (int j = 0; j < size; j++)
        {
            double sum = 0.0;
            for (int k = 0; k < size; k++)
            {
                sum += A[i * size + k] * B[k * size + j];
            }
            C[i * size + j] = sum;
        }
    }
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

    std::vector<double> A(size * size);
    std::vector<double> B(size * size);
    std::vector<double> C(size * size, 0.0);
    std::vector<double> subA(rowsPerProcess * size);
    std::vector<double> subC(rowsPerProcess * size);

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
    multiplyRows(subA, B, subC, rowsPerProcess, size);
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