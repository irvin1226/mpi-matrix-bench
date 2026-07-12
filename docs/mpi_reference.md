# MPI Core Functions

A reference for the seven MPI functions this benchmark is built on. MPI (Message Passing Interface) is the standard for distributed computing: it lets multiple processes, each with its own private memory, cooperate on a single computation by passing messages to each other. When a program is launched with `mpirun -np 4`, four identical copies of it start running at once, and these functions are how those copies coordinate.

### MPI_Init

Starts up the MPI system and connects all the processes so they can communicate. Before this call runs, the processes launched by `mpirun` are just separate programs that happen to be running at the same time, with no awareness of each other. `MPI_Init` establishes the communication layer between them, which is why it must be the first MPI call in the program and why no other MPI function works before it.

*Technical: Initializes the MPI execution environment. Must be called exactly once per process before any other MPI routine.*

### MPI_Comm_rank

Gives the calling process its ID number, called a rank. With 4 processes, the ranks are 0, 1, 2, and 3. Since every process runs the exact same code, the rank is the only thing that distinguishes one process from another, and it is how each process determines which portion of the work belongs to it. A process with rank 0 might load the data and coordinate the others, while a process with rank 3 works on the fourth chunk. By convention, rank 0 is called the root.

*Technical: Returns the rank of the calling process within the given communicator, typically MPI_COMM_WORLD, the communicator containing all processes.*

### MPI_Comm_size

Tells the calling process how many processes are running in total. This is what makes it possible to divide work evenly at runtime instead of hardcoding assumptions into the program. With 1024 matrix rows and 4 processes, each process takes 256 rows. Run the same program with 8 processes and each takes 128, with no code changes required.

*Technical: Returns the total number of processes in the given communicator.*

### MPI_Bcast

One process, the root, sends a complete copy of some data to every other process. This is used when all processes need the same input in full. It accomplishes the same thing as the root sending a separate message to each process one at a time, but MPI implementations handle the distribution far more efficiently behind the scenes, typically in logarithmic rather than linear time.

*Technical: Collective operation broadcasting a buffer from the root to all ranks in the communicator. Every rank must call it with a matching root and datatype.*

### MPI_Scatter

The root takes one large array, divides it into equal chunks, and delivers a different chunk to each process, keeping one chunk for itself. This is the function that actually splits a workload. Where broadcast gives every process an identical copy, scatter gives every process its own distinct piece, which also means each process only holds the memory for its share rather than the entire dataset. One constraint to be aware of: the chunks must be equal, so the data has to divide evenly by the process count. 1024 rows across 4 processes works cleanly, but the same 1024 rows across 3 does not, and that case requires the variant `MPI_Scatterv`, which allows a different chunk size per process.

*Technical: Collective operation partitioning a contiguous buffer on the root into equal segments, delivered to ranks in rank order. MPI_Scatterv generalizes it with per-rank counts and displacements.*

### MPI_Gather

The reverse of scatter. Every process sends its piece of data back to the root, which assembles the pieces into one array. The pieces are placed in rank order, so the final result comes out correctly arranged without any extra bookkeeping: rank 0's contribution lands first, then rank 1's, and so on.

*Technical: Collective operation collecting equal-sized buffers from all ranks onto the root, concatenated in rank order.*

### MPI_Finalize

Shuts the MPI system down cleanly and releases the resources it was using. It must be the last MPI call in the program. Skipping it leaves the runtime in an undefined state, which in practice shows up as error messages at exit or processes that hang instead of terminating.

*Technical: Terminates the MPI execution environment. No MPI routine may be called after it.*

## How They Fit Together

In a distributed matrix multiplication C = A x B, the seven functions form a complete pipeline. Matrix B is broadcast because every process needs all of it, while matrix A is scattered because each process only needs the rows it will multiply.

| Step | Function | What happens |
|------|----------|--------------|
| 1 | `MPI_Init` | All processes come online |
| 2 | `MPI_Comm_rank` | Each process learns its ID |
| 3 | `MPI_Comm_size` | Each process learns the total count |
| 4 | `MPI_Bcast` | Every process receives a full copy of B |
| 5 | `MPI_Scatter` | Each process receives its own rows of A |
| 6 | (local compute) | Each process multiplies its rows by B |
| 7 | `MPI_Gather` | Result rows are reassembled into C on rank 0 |
| 8 | `MPI_Finalize` | Everything shuts down cleanly |
