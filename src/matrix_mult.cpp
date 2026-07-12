#include <iostream>
#include <mpi.h>

int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);

    int mpiRank;
    MPI_Comm_rank(MPI_COMM_WORLD, &mpiRank);

    int mpiSize;
    MPI_Comm_size(MPI_COMM_WORLD, &mpiSize);

    std::cout << "Process " << mpiRank << " of " << mpiSize << " is online.\n";

    MPI_Finalize();
    return EXIT_SUCCESS;
}