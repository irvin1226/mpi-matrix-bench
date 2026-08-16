# Optimization Notes: Why the Naive Loop Order Is Slow

## The Problem

The naive matrix multiplication loop looks correct, and it is correct: it produces the right answer. But "correct" and "fast" are different things, and the loop order in the naive version accidentally fights against how computer memory actually works.

## How Matrices Are Stored

A matrix in this project isn't a 2D grid in memory. It's one long flat line of numbers. A 4x4 matrix is stored as 16 numbers in a row, where row 0 comes first, then row 1, then row 2, then row 3. To find row `r`, column `c`, the formula is `r * size + c`.

## Two Different Access Patterns in the Same Loop

The innermost loop of the naive multiplication does this, for a fixed `i` and `j`, as `k` increases:

- Access `A[i * size + k]`
- Access `B[k * size + j]`

These look symmetrical, but they behave completely differently in memory.

For `A`, as `k` goes up by 1, the memory position also goes up by exactly 1. That means `A` is read in a straight, unbroken line: position 0, then 1, then 2, then 3, and so on.

For `B`, as `k` goes up by 1, the memory position jumps by the full matrix size, 1024 positions at a time in this project. So `B` is read at position 0, then 1024, then 2048, then 3072, and so on. Every single step is a long jump to a completely different part of memory.

## Why the Jump Matters

CPUs don't read memory one number at a time. When a value is requested, the CPU pulls in a whole nearby chunk at once (called a cache line) and keeps it in a small, extremely fast memory cache, betting that the next thing needed will be close by.

That bet works out great for `A`. The next value really is right next door, already sitting in the cache from the last fetch.

That bet fails constantly for `B`. The next value is far away, so the CPU has to go all the way back to slow main memory almost every single time, throwing away most of what it just cached.

This happens on every single `(i, j)` pair in the entire matrix, over a million times for a 1024x1024 matrix, so the wasted cache fetches add up to real, measurable slowdown, even though the total number of multiplications never changes.

## The Core Insight

The naive algorithm isn't wrong. It computes the correct answer, and it's a completely valid way to structure MPI communication (broadcast, scatter, gather don't care about loop order). But the order the three loops run in determines whether memory gets read in cache-friendly straight lines or cache-hostile long jumps, and that difference is exactly what a cache-aware optimized version is designed to fix.